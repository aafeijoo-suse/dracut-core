#!/bin/bash
#
# Preferred format:
#       root=iscsi:[<servername>]:[<protocol>]:[<port>]:[<LUN>]:<targetname>
#       [root=*] netroot=iscsi:[<servername>]:[<protocol>]:[<port>]:[<LUN>]:<targetname>
#
# root= takes precedence over netroot= if root=iscsi[...]
#

type getarg > /dev/null 2>&1 || . /lib/dracut-lib.sh
type write_fs_tab > /dev/null 2>&1 || . /lib/fs-lib.sh

# This script is sourced, so root should be set. But let's be paranoid
[ -z "$root" ] && root=$(getarg root=)
if [ -z "$netroot" ]; then
    for nroot in $(getargs netroot=); do
        if [ "${nroot%%:*}" = "iscsi" ]; then
            netroot="$nroot"
            break
        fi
    done
fi

# Root takes precedence over netroot
if [ "${root%%:*}" = "iscsi" ]; then
    if [ -n "$netroot" ]; then
        warn "iscsi: root takes precedence over netroot, ignoring netroot"
    fi
    netroot=$root
    # if root is not specified try to mount the whole iSCSI LUN
    printf 'ENV{DEVTYPE}!="partition", SYMLINK=="disk/by-path/*-iscsi-*-*", SYMLINK+="root"\n' >> /etc/udev/rules.d/99-iscsi-root.rules
    systemctl is-active systemd-udevd && udevadm control --reload-rules
    root=/dev/root

    write_fs_tab /dev/root
fi

# If netroot it's not iscsi we don't continue
[ "${netroot%%:*}" = "iscsi" ] || return 1

# The iscsi parameter from the BIOS firmware does not need argument checking
if getargbool 0 rd.iscsi.firmware; then
    iscsi_transport=$(getarg rd.iscsi.transport=)
    [ "$iscsi_transport" != bnx2i ] && netroot="iscsi:"
    modprobe -b -q iscsi_boot_sysfs 2> /dev/null
    modprobe -b -q iscsi_ibft
    # if no ip= is given, but firmware
    echo "systemctl is-active initrd-root-device.target || [ -f '/tmp/iscsistarted-firmware' ]" > "$hookdir"/initqueue/finished/iscsi_started.sh
    /sbin/initqueue --unique --online /sbin/iscsiroot online "iscsi:" "$NEWROOT"
    /sbin/initqueue --unique --onetime --timeout /sbin/iscsiroot timeout "iscsi:" "$NEWROOT"
    /sbin/initqueue --unique --onetime --settled /sbin/iscsiroot online "iscsi:" "'$NEWROOT'"
fi

# iSCSI actually supported?
if ! [ -e /sys/module/iscsi_tcp ]; then
    modprobe -b -q iscsi_tcp || die "iscsi: iscsiroot requested but kernel/initrd does not support iscsi"
fi

modprobe --all -b -q qla4xxx cxgb3i cxgb4i bnx2i be2iscsi

if [ "$root" != "/dev/root" ] && [ "$root" != "dhcp" ]; then
    if ! getargbool 1 rd.neednet > /dev/null || ! getarg "ip="; then
        /sbin/initqueue --unique --onetime --settled /sbin/iscsiroot dummy "'$netroot'" "'$NEWROOT'"
    fi
fi

if arg=$(getarg rd.iscsi.initiator) && [ -n "$arg" ] && ! [ -f /run/initiatorname.iscsi ]; then
    iscsi_initiator=$arg
    echo "InitiatorName=$iscsi_initiator" > /run/initiatorname.iscsi
    ln -fs /run/initiatorname.iscsi /dev/.initiatorname.iscsi
    rm -f /etc/iscsi/initiatorname.iscsi
    mkdir -p /etc/iscsi
    ln -fs /run/initiatorname.iscsi /etc/iscsi/initiatorname.iscsi
    systemctl try-restart iscsid
    # FIXME: iscsid is not yet ready, when the service is :-/
    sleep 1
fi

# If not given on the cmdline and initiator-name available via iBFT
if [ -z "$iscsi_initiator" ] && [ -f /sys/firmware/ibft/initiator/initiator-name ] && ! [ -f /tmp/iscsi_set_initiator ]; then
    iscsi_initiator=$(while read -r line || [ -n "$line" ]; do echo "$line"; done < /sys/firmware/ibft/initiator/initiator-name)
    if [ -n "$iscsi_initiator" ]; then
        echo "InitiatorName=$iscsi_initiator" > /run/initiatorname.iscsi
        rm -f /etc/iscsi/initiatorname.iscsi
        mkdir -p /etc/iscsi
        ln -fs /run/initiatorname.iscsi /etc/iscsi/initiatorname.iscsi
        : > /tmp/iscsi_set_initiator
        systemctl try-restart iscsid
        # FIXME: iscsid is not yet ready, when the service is :-/
        sleep 1
    fi
fi

/sbin/initqueue --unique --onetime --timeout /sbin/iscsiroot timeout "$netroot" "$NEWROOT"

for nroot in $(getargs netroot); do
    [ "${nroot%%:*}" = "iscsi" ] || continue
    type parse_iscsi_root > /dev/null 2>&1 || . /lib/net-lib.sh
    parse_iscsi_root "$nroot" || return 1
    netroot_enc=$(str_replace "$nroot" '/' '\2f')
    echo "systemctl is-active initrd-root-device.target || [ -f '/tmp/iscsistarted-$netroot_enc' ]" > "$hookdir"/initqueue/finished/iscsi_started.sh
done

# Done, all good!
# shellcheck disable=SC2034
rootok=1

# Shut up init error check
[ -z "$root" ] && root="iscsi"
