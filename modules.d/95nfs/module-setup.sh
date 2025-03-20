#!/bin/bash

# return value:
#  'nfs4': Only nfs4 founded
#  'nfs': nfs with version < 4 founded
#  '': No nfs founded
get_nfs_type() {
    local _nfs _nfs4

    for fs in "${host_fs_types[@]}"; do
        [[ $fs == "nfs" ]] && _nfs=1
        [[ $fs == "nfs3" ]] && _nfs=1
        [[ $fs == "nfs4" ]] && _nfs4=1
    done

    [[ "$_nfs" ]] && echo "nfs" && return
    [[ "$_nfs4" ]] && echo "nfs4" && return
}

# called by dracut
check() {
    require_binaries mount.nfs mount.nfs4 umount sed chmod chown grep || return 1

    [[ $hostonly ]] || [[ $mount_needs ]] && {
        [[ "$(get_nfs_type)" ]] && return 0
        return 255
    }
    return 0
}

# called by dracut
depends() {
    # We depend on network modules being loaded
    echo network
}

# called by dracut
installkernel() {
    hostonly=$(optional_hostonly) instmods '=net/sunrpc' '=fs/nfs' ipv6 nfs_acl nfs_layout_nfsv41_files
}

cmdline() {
    local nfs_device
    local nfs_options
    local nfs_root
    local nfs_address
    local lookup

    ### nfsroot= ###
    nfs_device=$(findmnt -t nfs4 -n -o SOURCE /)
    if [ -n "$nfs_device" ]; then
        nfs_root="root=nfs4:$nfs_device"
    else
        nfs_device=$(findmnt -t nfs -n -o SOURCE /)
        [ -z "$nfs_device" ] && return
        nfs_root="root=nfs:$nfs_device"
    fi
    nfs_options=$(findmnt -t nfs4,nfs -n -o OPTIONS /)
    [ -n "$nfs_options" ] && nfs_root="$nfs_root:$nfs_options"
    echo "$nfs_root"

    ### ip= ###
    if [[ $nfs_device =~ [0-9]*\.[0-9]*\.[0-9]*.[0-9]* ]] || [[ $nfs_device =~ \[[^]]*\] ]]; then
        nfs_address="${nfs_device%%:*}"
    else
        lookup=$(host "${nfs_device%%:*}" | grep " address " | head -n1)
        nfs_address=${lookup##* }
    fi

    [[ $nfs_address ]] || return
    ip_params_for_remote_addr "$nfs_address"
}

# called by dracut
install() {
    local _nsslibs _rpcuser

    inst_multiple -o rpc.idmapd mount.nfs mount.nfs4 umount sed chmod chown grep
    inst_multiple -o \
        {,/usr}/etc/idmapd.conf \
        /etc/netconfig \
        {,/usr}/etc/nsswitch.conf \
        {,/usr}/etc/protocols \
        {,/usr}/etc/rpc \
        {,/usr}/etc/services \
        "$tmpfilesdir/rpcbind.conf"

    if [[ $hostonly_cmdline == "yes" ]]; then
        local _netconf
        _netconf="$(cmdline)"
        [[ $_netconf ]] && printf "%s\n" "$_netconf" >> "${initdir}/etc/cmdline.d/95nfs.conf"
    fi

    [[ -d $initdir/etc/modprobe.d ]] || mkdir -p "$initdir"/etc/modprobe.d
    echo "alias nfs4 nfs" > "$initdir"/etc/modprobe.d/nfs.conf

    inst_libdir_file 'libnfsidmap_nsswitch.so*' 'libnfsidmap/*.so' 'libnfsidmap*.so*'

    _nsslibs=$(
        cat /{,usr/}etc/nsswitch.conf 2> /dev/null \
            | sed -e '/^#/d' -e 's/^.*://' -e 's/\[NOTFOUND=return\]//' \
            | tr -s '[:space:]' '\n' | sort -u | tr -s '[:space:]' '|'
    )
    _nsslibs=${_nsslibs#|}
    _nsslibs=${_nsslibs%|}

    inst_libdir_file -n "$_nsslibs" 'libnss_*.so*'

    inst_hook cmdline 90 "$moddir/parse-nfsroot.sh"
    inst_hook pre-udev 99 "$moddir/nfs-start-rpc.sh"
    inst_hook cleanup 99 "$moddir/nfsroot-cleanup.sh"
    inst "$moddir/nfsroot.sh" "/sbin/nfsroot"
    inst "$moddir/nfs-lib.sh" "/lib/nfs-lib.sh"

    mkdir -m 0755 -p "$initdir/var/lib/nfs"
    mkdir -m 0755 -p "$initdir/var/lib/nfs/rpc_pipefs"

    # For hostonly, only install rpcbind for NFS < 4
    if ! [[ $hostonly ]] || [[ "$(get_nfs_type)" == "nfs" ]]; then
        inst_multiple rpcbind
        mkdir -m 0770 -p "$initdir/var/lib/rpcbind"
        _rpcuser=$(grep -m1 -E '^nfsnobody:|^rpc:|^rpcuser:' /etc/passwd)
        if [[ -n "$_rpcuser" ]]; then
            echo "$_rpcuser" >> "$initdir/etc/passwd"
            # rpc user needs to be able to write to this directory to save the warmstart file
            chown "${_rpcuser%%:*}": "$initdir/var/lib/rpcbind"
            grep -E '^nogroup:|^rpc:|^nobody:' /etc/group >> "$initdir/etc/group"
        fi
    fi

    dracut_need_initqueue
}
