#!/bin/bash
#
# We don't need to check for ip= errors here, that is handled by the
# cmdline parser script
#
# without $2 means this is for real netroot case
# or it is for manually bring up network ie. for kdump scp vmcore
PATH=/usr/sbin:/usr/bin:/sbin:/bin

type getarg > /dev/null 2>&1 || . /lib/dracut-lib.sh
type ip_to_var > /dev/null 2>&1 || . /lib/net-lib.sh

# Huh? No $1?
[ -z "$1" ] && exit 1

# $netif reads easier than $1
netif=$1

# loopback is always handled the same way
if [ "$netif" = "lo" ]; then
    # systemd probably has already set up lo
    ip link show dev lo >/dev/null && exit 0

    ip link set lo up
    ip addr add 127.0.0.1/8 dev lo
    exit 0
fi

dhcp_backend() {
    type wicked >/dev/null 2>&1 && \
    echo "wicked" || \
    echo "dhclient"
}

dhcp_wicked_apply() {
    unset IPADDR INTERFACE BROADCAST NETWORK PREFIXLEN ROUTES GATEWAYS MTU HOSTNAME DNSDOMAIN DNSSEARCH DNSSERVERS
    if [ -f "/tmp/leaseinfo.${netif}.dhcp.ipv${1:1:1}" ]; then
        . "/tmp/leaseinfo.${netif}.dhcp.ipv${1:1:1}"
    else
        warn "DHCP failed";
        return 1
    fi

    if [ -z "${IPADDR}" ] || [ -z "${INTERFACE}" ]; then
           warn "Missing crucial DHCP variables"
           return 1
    fi

    # Assign IP address
    ip $1 addr add "$IPADDR" ${BROADCAST:+broadcast $BROADCAST} dev "$INTERFACE"

    # Assign provided routes
    local r route=()
    if [ -n "${ROUTES}" ]; then
        for r in ${ROUTES}; do
            route=(${r//,/ })
            if [ ! ${route[2]} == "0.0.0.0" ]; then
                gateway=" via ${route[2]}"
            fi
            ip $1 route add "${route[0]}"/"${route[1]}""$gateway" dev "$INTERFACE"
        done
    fi

    # Assign provided routers
    local g
    if [ -n "${GATEWAYS}" ]; then
        for g in ${GATEWAYS}; do
            ip $1 route add default via "$g" dev "$INTERFACE" && break
        done
    fi

    # Set MTU
    [ -n "${MTU}" ] && ip $1 link set mtu "$MTU" dev "$INTERFACE"

    # Setup hostname
    [ -n "${HOSTNAME}" ] && echo $HOSTNAME > /proc/sys/kernel/hostname

    # If nameserver= has not been specified, use what dhcp provides
    if [ ! -s /tmp/net.$netif.resolv.conf.ipv${1:1:1} ]; then
        if [ -n "${DNSDOMAIN}" ]; then
            echo domain "${DNSDOMAIN}"
        fi >> /tmp/net.$netif.resolv.conf.ipv${1:1:1}

        if [ -n "${DNSSEARCH}" ]; then
            echo search "${DNSSEARCH}"
        fi >> /tmp/net.$netif.resolv.conf.ipv${1:1:1}

        if  [ -n "${DNSSERVERS}" ] ; then
            for s in ${DNSSERVERS}; do
                echo nameserver "$s"
            done
        fi >> /tmp/net.$netif.resolv.conf.ipv${1:1:1}
    fi
    # copy resolv.conf if it doesn't exist yet, modify otherwise
    if [ -e /tmp/net.$netif.resolv.conf.ipv${1:1:1} ] && [ ! -e /etc/resolv.conf ]; then
        cp -f /tmp/net.$netif.resolv.conf.ipv${1:1:1} /etc/resolv.conf
    else
        if [ -n "$(sed -n '/^search .*$/p' /etc/resolv.conf)" ]; then
            sed -i "s/\(^search .*\)$/\1 ${DNSSEARCH}/" /etc/resolv.conf
        else
            echo search ${DNSSEARCH} >> /etc/resolv.conf
        fi
        if  [ -n "${DNSSERVERS}" ] ; then
            for s in ${DNSSERVERS}; do
                echo nameserver "$s"
            done
        fi >> /etc/resolv.conf
    fi

    info "DHCP is finished successfully"
    return 0

}

# USECASE?
dhcp_wicked_read_ifcfg() {
    unset PREFIXLEN LLADDR MTU REMOTE_IPADDR GATEWAY BOOTPROTO

    if [ -e /etc/sysconfig/network/ifcfg-${netif} ] ; then
        # Pull in existing configuration
        . /etc/sysconfig/network/ifcfg-${netif}

        # The first configuration can be anything
        [ -n "$PREFIXLEN" ] && prefix=${PREFIXLEN}
        [ -n "$LLADDR" ] && macaddr=${LLADDR}
        [ -n "$MTU" ] && mtu=${MTU}
        [ -n "$REMOTE_IPADDR" ] && server=${REMOTE_IPADDR}
        [ -n "$GATEWAY" ] && gw=${GATEWAY}
        [ -n "$BOOTPROTO" ] && autoconf=${BOOTPROTO}
        return 0
    fi
    return 1
}


dhcp_dhclient_run() {
    if [ -n "$_timeout" ]; then
        if ! (dhclient --help 2>&1 | grep -q -F -- '--timeout' 2> /dev/null); then
            warn "rd.net.timeout.dhcp has no effect because dhclient does not implement the --timeout option"
            unset _timeout
        fi
    fi

    dhclient "$@" \
                 ${_timeout:+--timeout $_timeout} \
                 -q \
                 -1 \
                 -cf /etc/dhclient.conf \
                 -pf "/tmp/dhclient.$netif.pid" \
                 -lf "/tmp/dhclient.$netif.lease" \
                 "$netif" \
            && return 0
    return 1
}

dhcp_wicked_run() {
    local _ipv=${1:-"-4"}

    [ -d /var/lib/wicked ] || mkdir -p /var/lib/wicked

    dhclient=
    if [ "$_ipv" = "-6" ] ; then
        ipv6_mode=
        if [ -f "/tmp/net.$netif.auto6" ] ; then
            ipv6_mode="auto"
        else
            ipv6_mode="managed"
        fi
        dhclient="wicked test dhcp6 -m $ipv6_mode"
    else
        dhclient="wicked test dhcp4"
    fi

    if ! linkup "$netif"; then
        warn "Could not bring interface $netif up!"
        return 1
    fi

    if dhcp_wicked_read_ifcfg ; then
        [ -n "$macaddr" ] && ip "$_ipv" link set address $macaddr dev $netif
        [ -n "$mtu" ] && ip "$_ipv" link set mtu $mtu dev $netif
    fi

    local needtimeout=0
    local CMDLINE=$(getcmdline)
    local cmdlineopt
    for cmdlineopt in $CMDLINE; do
        case "$cmdlineopt" in
            rd.iscsi.*) ;&
            rd.fcoe*) ;&
            root=nfs:*) ;&
            root=iscsi:*)
                needtimeout=1
                ;;
        esac
    done
    if [ $needtimeout -eq 1 -a -z "$_timeout" ]; then
        _timeout=60
    fi

    $dhclient ${_timeout:+--timeout $_timeout} --format leaseinfo --output "/tmp/leaseinfo.${netif}.dhcp.ipv${_ipv:1:1}" --request - $netif << EOF
<request type="lease"/>
EOF
    dhcp_wicked_apply "$_ipv" || return $?

    if [ "$_ipv" = "-6" ] ; then
        wait_for_ipv6_dad $netif
    fi

    return 0
}

do_dhcp_parallel() {
    # dhclient-script will mark the netif up and generate the online
    # event for nfsroot
    # XXX add -V vendor class and option parsing per kernel

    [ -e "/tmp/dhclient.$netif.pid" ] && return 0

    if ! iface_has_carrier "$netif"; then
        warn "No carrier detected on interface $netif"
        return 1
    fi

    bootintf=$(readlink "$IFNETFILE")
    if [ -n "$bootintf" ] && [ -e "/tmp/dhclient.${bootintf}.lease" ]; then
        info "DHCP already succeeded for $bootintf, exiting for $netif"
        return 1
    fi

    if [ ! -e /run/NetworkManager/conf.d/10-dracut-dhclient.conf ]; then
        mkdir -p /run/NetworkManager/conf.d
        echo '[main]' > /run/NetworkManager/conf.d/10-dracut-dhclient.conf
        echo 'dhcp=dhclient' >> /run/NetworkManager/conf.d/10-dracut-dhclient.conf
    fi

    chmod +x /sbin/dhcp-multi.sh
    /sbin/dhcp-multi.sh "$netif" "$DO_VLAN" "$@" &
    return 0
}

# Run dhclient
do_dhcp() {
    # dhclient-script will mark the netif up and generate the online
    # event for nfsroot
    # XXX add -V vendor class and option parsing per kernel

    local _COUNT
    local _timeout
    local _DHCPRETRY


    _COUNT=0
    _timeout=$(getarg rd.net.timeout.dhcp=)
    _DHCPRETRY=$(getargnum 1 1 1000000000 rd.net.dhcp.retry=)

    [ -e "/tmp/dhclient.${netif}.pid" ] && return 0

    if ! iface_has_carrier "$netif"; then
        warn "No carrier detected on interface $netif"
        return 1
    fi

    if [ -n "$_timeout" ]; then
        if ! (dhclient --help 2>&1 | grep -q -F -- '--timeout' 2> /dev/null); then
            warn "rd.net.timeout.dhcp has no effect because dhclient does not implement the --timeout option"
            unset _timeout
        fi
    fi

    if [ ! -e /run/NetworkManager/conf.d/10-dracut-dhclient.conf ]; then
        mkdir -p /run/NetworkManager/conf.d
        echo '[main]' > /run/NetworkManager/conf.d/10-dracut-dhclient.conf
        echo 'dhcp=dhclient' >> /run/NetworkManager/conf.d/10-dracut-dhclient.conf
    fi

    while [ "$_COUNT" -lt "$_DHCPRETRY" ]; do
        info "Starting dhcp for interface $netif"
        backend="$(dhcp_backend)"
        dhcp_${backend}_run "$@" && return 0



        _COUNT=$((_COUNT + 1))
        [ "$_COUNT" -lt "$_DHCPRETRY" ] && sleep 1
    done
    warn "dhcp for interface $netif failed"
    # nuke those files since we failed; we might retry dhcp again if it's e.g.
    # `ip=dhcp,dhcp6` and we check for the PID file at the top
    rm -f /tmp/dhclient."$netif".pid /tmp/dhclient."$netif".lease
    return 1
}

load_ipv6() {
    [ -d /proc/sys/net/ipv6 ] && return
    modprobe ipv6
    i=0
    while [ ! -d /proc/sys/net/ipv6 ]; do
        i=$((i + 1))
        [ $i -gt 10 ] && break
        sleep 0.1
    done
}

do_ipv6auto() {
    local ret
    load_ipv6
    echo 0 > /proc/sys/net/ipv6/conf/"${netif}"/forwarding
    echo 1 > /proc/sys/net/ipv6/conf/"${netif}"/accept_ra
    echo 1 > /proc/sys/net/ipv6/conf/"${netif}"/accept_redirects
    linkup "$netif"
    wait_for_ipv6_auto "$netif"
    ret=$?

    [ -n "$hostname" ] && echo "echo $hostname > /proc/sys/kernel/hostname" > "/tmp/net.${netif}.hostname"

    return "$ret"
}

do_ipv6link() {
    local ret
    load_ipv6
    echo 0 > /proc/sys/net/ipv6/conf/"${netif}"/forwarding
    echo 0 > /proc/sys/net/ipv6/conf/"${netif}"/accept_ra
    echo 0 > /proc/sys/net/ipv6/conf/"${netif}"/accept_redirects
    linkup "$netif"

    [ -n "$hostname" ] && echo "echo $hostname > /proc/sys/kernel/hostname" > "/tmp/net.${netif}.hostname"

    return "$ret"
}

# Handle static ip configuration
do_static() {
    strglobin "$ip" '*:*:*' && load_ipv6

    if ! iface_has_carrier "$netif"; then
        warn "No carrier detected on interface $netif"
        return 1
    elif ! linkup "$netif"; then
        warn "Could not bring interface $netif up!"
        return 1
    fi

    ip route get "$ip" 2> /dev/null | {
        read -r a rest
        if [ "$a" = "local" ]; then
            warn "Not assigning $ip to interface $netif, cause it is already assigned!"
            return 1
        fi
        return 0
    } || return 1

    [ -n "$macaddr" ] && ip link set address "$macaddr" dev "$netif"
    [ -n "$mtu" ] && ip link set mtu "$mtu" dev "$netif"
    if strglobin "$ip" '*:*:*'; then
        # note no ip addr flush for ipv6
        ip addr add "$ip/$mask" ${srv:+peer "$srv"} dev "$netif"
        echo 0 > /proc/sys/net/ipv6/conf/"${netif}"/forwarding
        echo 1 > /proc/sys/net/ipv6/conf/"${netif}"/accept_ra
        echo 1 > /proc/sys/net/ipv6/conf/"${netif}"/accept_redirects
        wait_for_ipv6_dad "$netif"
    else
        if [ -z "$srv" ]; then
            if command -v arping2 > /dev/null; then
                if arping2 -q -C 1 -c 2 -I "$netif" -0 "$ip"; then
                    warn "Duplicate address detected for $ip for interface $netif."
                    return 1
                fi
            elif command -v arping > /dev/null; then
                if ! arping -f -q -D -c 2 -I "$netif" "$ip"; then
                    warn "Duplicate address detected for $ip for interface $netif."
                    return 1
                fi
            else
                wicked arp verify --quiet --count 2 --interval 1000 "$netif" "$ip"
                if [ $? -eq 4 ]; then
                    warn "Duplicate address detected for $ip for interface $netif."
                    return 1
                fi
            fi
        fi
        ip addr flush dev "$netif"
        ip addr add "$ip/$mask" ${srv:+peer "$srv"} brd + dev "$netif"
    fi

    [ -n "$gw" ] && echo "ip route replace default via '$gw' dev '$netif'" > "/tmp/net.$netif.gw"
    [ -n "$hostname" ] && echo "echo '$hostname' > /proc/sys/kernel/hostname" > "/tmp/net.$netif.hostname"

    for ifroute in /etc/sysconfig/network/ifroute-${netif} /etc/sysconfig/network/routes ; do
        [ -e ${ifroute} ] || continue
        # Pull in existing routing configuration
        read ifr_dest ifr_gw ifr_mask ifr_if < ${ifroute}
        [ -z "$ifr_dest" -o -z "$ifr_gw" ] && continue
        if [ "$ifr_if" = "-" ] ; then
            echo ip route add $ifr_dest via $ifr_gw >> /tmp/net.$netif.gw
        else
            echo ip route add $ifr_dest via $ifr_gw dev $ifr_if >> /tmp/net.$netif.gw
        fi
    done

    return 0
}

get_vid() {
    case "$1" in
        vlan*)
            echo "${1#vlan}"
            ;;
        *.*)
            echo "${1##*.}"
            ;;
    esac
}

# check, if we need VLAN's for this interface
if [ -z "$DO_VLAN_PHY" ] && [ -e "/tmp/vlan.${netif}.phy" ]; then
    unset DO_VLAN
    NO_AUTO_DHCP=yes DO_VLAN_PHY=yes ifup "$netif"
    modprobe -b -q 8021q

    for i in /tmp/vlan.*."${netif}"; do
        [ -e "$i" ] || continue
        unset vlanname
        unset phydevice
        # shellcheck disable=SC1090
        . "$i"
        if [ -n "$vlanname" ]; then
            linkup "$phydevice"
            ip link add dev "$vlanname" link "$phydevice" type vlan id "$(get_vid "$vlanname")"
            ifup "$vlanname"
        fi
    done
    exit 0
fi

# Check, if interface is VLAN interface
if ! [ -e "/tmp/vlan.${netif}.phy" ]; then
    for i in "/tmp/vlan.${netif}".*; do
        [ -e "$i" ] || continue
        export DO_VLAN=yes
        break
    done
fi


# bridge this interface?
if [ -z "$NO_BRIDGE_MASTER" ]; then
    for i in /tmp/bridge.*.info; do
        [ -e "$i" ] || continue
        unset bridgeslaves
        unset bridgename
        # shellcheck disable=SC1090
        . "$i"
        for ethname in $bridgeslaves; do
            [ "$netif" != "$ethname" ] && continue

            NO_BRIDGE_MASTER=yes NO_AUTO_DHCP=yes ifup "$ethname"
            linkup "$ethname"
            if [ ! -e "/tmp/bridge.$bridgename.up" ]; then
                ip link add name "$bridgename" type bridge
                echo 0 > "/sys/devices/virtual/net/$bridgename/bridge/forward_delay"
                : > "/tmp/bridge.$bridgename.up"
            fi
            ip link set dev "$ethname" master "$bridgename"
            ifup "$bridgename"
            exit 0
        done
    done
fi

# enslave this interface to bond?
if [ -z "$NO_BOND_MASTER" ]; then
    for i in /tmp/bond.*.info; do
        [ -e "$i" ] || continue
        unset bondslaves
        unset bondname
        # shellcheck disable=SC1090
        . "$i"
        for testslave in $bondslaves; do
            [ "$netif" != "$testslave" ] && continue

            # already setup
            [ -e "/tmp/bond.$bondname.up" ] && exit 0

            # wait for all slaves to show up
            for slave in $bondslaves; do
                # try to create the slave (maybe vlan or bridge)
                NO_BOND_MASTER=yes NO_AUTO_DHCP=yes ifup "$slave"

                if ! ip link show dev "$slave" > /dev/null 2>&1; then
                    # wait for the last slave to show up
                    exit 0
                fi
            done

            modprobe -q -b bonding
            echo "+$bondname" > /sys/class/net/bonding_masters 2> /dev/null
            ip link set "$bondname" down

            # Stolen from ifup-eth
            # add the bits to setup driver parameters here
            for arg in $bondoptions; do
                key=${arg%%=*}
                value=${arg##*=}
                # %{value:0:1} is replaced with non-bash specific construct
                if [ "${key}" = "arp_ip_target" -a "${#value}" != "0" -a "+${value%%+*}" != "+" ]; then
                    OLDIFS=$IFS
                    IFS=','
                    for arp_ip in $value; do
                        echo "+$arp_ip" > "/sys/class/net/${bondname}/bonding/$key"
                    done
                    IFS=$OLDIFS
                else
                    echo "$value" > "/sys/class/net/${bondname}/bonding/$key"
                fi
            done

            linkup "$bondname"

            for slave in $bondslaves; do
                echo "$(< "/sys/class/net/$slave/address")" > "/tmp/net.${bondname}.${slave}.hwaddr"
                ip link set "$slave" down
                echo "+$slave" > "/sys/class/net/$bondname/bonding/slaves"
                linkup "$slave"
            done

            # Set mtu on bond master
            [ -n "$bondmtu" ] && ip link set mtu "$bondmtu" dev "$bondname"

            # add the bits to setup the needed post enslavement parameters
            for arg in $bondoptions; do
                key=${arg%%=*}
                value=${arg##*=}
                if [ "${key}" = "primary" ]; then
                    echo "$value" > "/sys/class/net/${bondname}/bonding/$key"
                fi
            done

            : > "/tmp/bond.$bondname.up"

            NO_BOND_MASTER=yes ifup "$bondname"
            exit $?
        done
    done
fi

if [ -z "$NO_TEAM_MASTER" ]; then
    for i in /tmp/team.*.info; do
        [ -e "$i" ] || continue
        unset teammaster
        unset teamslaves
        # shellcheck disable=SC1090
        . "$i"
        for testslave in $teamslaves; do
            [ "$netif" != "$testslave" ] && continue

            [ -e "/tmp/team.$teammaster.up" ] && exit 0

            # wait for all slaves to show up
            for slave in $teamslaves; do
                # try to create the slave (maybe vlan or bridge)
                NO_TEAM_MASTER=yes NO_AUTO_DHCP=yes ifup "$slave"

                if ! ip link show dev "$slave" > /dev/null 2>&1; then
                    # wait for the last slave to show up
                    exit 0
                fi
            done

            if [ ! -e "/tmp/team.$teammaster.up" ]; then
                # We shall only bring up those _can_ come up
                # in case of some slave is gone in active-backup mode
                working_slaves=""
                for slave in $teamslaves; do
                    teamdctl "${teammaster}" port present "${slave}" 2> /dev/null \
                        && continue
                    ip link set dev "$slave" up 2> /dev/null
                    if wait_for_if_up "$slave"; then
                        working_slaves="$working_slaves$slave "
                    fi
                done
                # Do not add slaves now
                teamd -d -U -n -N -t "$teammaster" -f "/etc/teamd/${teammaster}.conf"
                for slave in $working_slaves; do
                    # team requires the slaves to be down before joining team
                    ip link set dev "$slave" down
                    (
                        unset TEAM_PORT_CONFIG
                        read -r _hwaddr < "/sys/class/net/$slave/address"
                        _subchannels=$(iface_get_subchannels "$slave")
                        if [ -n "$_hwaddr" ] && [ -e "/etc/sysconfig/network-scripts/mac-${_hwaddr}.conf" ]; then
                            # shellcheck disable=SC1090
                            . "/etc/sysconfig/network-scripts/mac-${_hwaddr}.conf"
                        elif [ -n "$_subchannels" ] && [ -e "/etc/sysconfig/network-scripts/ccw-${_subchannels}.conf" ]; then
                            # shellcheck disable=SC1090
                            . "/etc/sysconfig/network-scripts/ccw-${_subchannels}.conf"
                        elif [ -e "/etc/sysconfig/network-scripts/ifcfg-${slave}" ]; then
                            # shellcheck disable=SC1090
                            . "/etc/sysconfig/network-scripts/ifcfg-${slave}"
                        fi

                        if [ -n "${TEAM_PORT_CONFIG}" ]; then
                            /usr/bin/teamdctl "${teammaster}" port config update "${slave}" "${TEAM_PORT_CONFIG}"
                        fi
                    )
                    teamdctl "$teammaster" port add "$slave"
                done

                ip link set dev "$teammaster" up

                : > "/tmp/team.$teammaster.up"
                NO_TEAM_MASTER=yes ifup "$teammaster"
                exit $?
            fi
        done
    done
fi

# all synthetic interfaces done.. now check if the interface is available
if ! ip link show dev "$netif" > /dev/null 2>&1; then
    exit 1
fi

# disable manual ifup while netroot is set for simplifying our logic
# in netroot case we prefer netroot to bringup $netif automatically
[ -n "$2" -a "$2" = "-m" ] && [ -z "$netroot" ] && manualup="$2"

if [ -n "$manualup" ]; then
    : > "/tmp/net.$netif.manualup"
    rm -f "/tmp/net.${netif}.did-setup"
else
    [ -e "/tmp/net.${netif}.did-setup" ] && exit 0
    [ -z "$DO_VLAN" ] \
        && [ -e "/sys/class/net/$netif/address" ] \
        && [ -e "/tmp/net.$(< "/sys/class/net/$netif/address").did-setup" ] && exit 0
fi


# Specific configuration, spin through the kernel command line
# looking for ip= lines
for p in $(getargs ip=); do
    ip_to_var "$p"
    # skip ibft
    [ "$autoconf" = "ibft" ] && continue

    case "$dev" in
        ??:??:??:??:??:??) # MAC address
            _dev=$(iface_for_mac "$dev")
            [ -n "$_dev" ] && dev="$_dev"
            ;;
        ??-??-??-??-??-??) # MAC address in BOOTIF form
            _dev=$(iface_for_mac "$(fix_bootif "$dev")")
            [ -n "$_dev" ] && dev="$_dev"
            ;;
    esac

    # If this option isn't directed at our interface, skip it
    if [ -n "$dev" ]; then
        if [ "$dev" != "$netif" ]; then
            [ ! -e "/sys/class/net/$dev" ] \
                && warn "Network interface '$dev' does not exist!"
            continue
        fi
    else
        iface_is_enslaved "$netif" && continue
    fi

    # Store config for later use
    for i in ip srv gw mask hostname macaddr mtu dns1 dns2; do
        eval '[ "$'$i'" ] && echo '$i'="$'$i'"'
    done > "/tmp/net.$netif.override"

    for autoopt in $(str_replace "$autoconf" "," " "); do
        case $autoopt in
            dhcp | on | any)
                do_dhcp -4
                ;;
            single-dhcp)
                if command -v wicked > /dev/null; then
                    warn "DHCP in parallel on all available interfaces not available with wicked."
                    exit 1
                fi
                do_dhcp_parallel -4
                exit 0
                ;;
            dhcp6)
                load_ipv6
                do_dhcp -6
                ;;
            auto6)
                do_ipv6auto
                ;;
            either6)
                do_ipv6auto || do_dhcp -6
                ;;
            link6)
                do_ipv6link
                ;;
            *)
                do_static
                ;;
        esac
    done
    ret=$?

    # setup nameserver
    for s in "$dns1" "$dns2" $(getargs nameserver); do
        [ -n "$s" ] || continue
        echo "nameserver $s" >> "/tmp/net.$netif.resolv.conf"
    done

    if [ $ret -eq 0 ]; then
        : > "/tmp/net.${netif}.up"

        if [ -z "$DO_VLAN" ] && [ -e "/sys/class/net/${netif}/address" ]; then
            : > "/tmp/net.$(< "/sys/class/net/${netif}/address").up"
        fi

        # and finally, finish interface set up if there isn't already a script
        # to do so (which is the case in the dhcp path)
        if [ ! -e "$hookdir/initqueue/setup_net_$netif.sh" ]; then
            setup_net "$netif"
            source_hook initqueue/online "$netif"
            if [ -z "$manualup" ]; then
                /sbin/netroot "$netif"
            fi
        fi

        if command -v wicked > /dev/null && [ -z "$manualup" ]; then
            /sbin/netroot "$netif"
        fi

        exit $ret
    fi
done

# no ip option directed at our interface?
if [ -z "$NO_AUTO_DHCP" ] && [ ! -e "/tmp/net.${netif}.up" ]; then
    ret=1
    if [ -e /tmp/net.bootdev ]; then
        read -r BOOTDEV < /tmp/net.bootdev
        if [ "$netif" = "$BOOTDEV" ] || [ "$BOOTDEV" = "$(< "/sys/class/net/${netif}/address")" ]; then
            do_dhcp
            ret=$?
        fi
    else
        # No ip lines, no bootdev -> default to dhcp
        ip=$(getarg ip)

        if getargs 'ip=dhcp6' > /dev/null || [ -z "$ip" -a "$netroot" = "dhcp6" ]; then
            load_ipv6
            do_dhcp -6
            ret=$?
        fi
        if getargs 'ip=dhcp' > /dev/null || [ -z "$ip" -a "$netroot" != "dhcp6" ]; then
            do_dhcp -4
            ret=$?
        fi
    fi

    for s in $(getargs nameserver); do
        [ -n "$s" ] || continue
        echo "nameserver $s" >> "/tmp/net.$netif.resolv.conf"
    done

    if [ "$ret" -eq 0 ] && [ -n "$(ls "/tmp/leaseinfo.${netif}"* 2> /dev/null)" ]; then
        : > "/tmp/net.${netif}.did-setup"
        if [ -e "/sys/class/net/${netif}/address" ]; then
            : > "/tmp/net.$(< "/sys/class/net/${netif}/address").did-setup"
        fi
    fi
fi

exit 0
