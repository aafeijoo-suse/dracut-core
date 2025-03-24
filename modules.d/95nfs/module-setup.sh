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
    require_binaries mount.nfs mount.nfs4 umount sed chown grep || return 1

    [[ $hostonly ]] || [[ $mount_needs ]] && {
        [[ "$(get_nfs_type)" ]] && return 0
        return 255
    }
    return 0
}

# called by dracut
depends() {
    echo network
    return 0
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
    local _f _includes _i _nsslibs _rpcuser

    if [[ $hostonly_cmdline == "yes" ]]; then
        local _netconf
        _netconf="$(cmdline)"
        [[ $_netconf ]] && printf "%s\n" "$_netconf" >> "${initdir}/etc/cmdline.d/95nfs.conf"
    fi

    inst_multiple -o \
        {,/usr}/etc/idmapd.conf \
        /etc/netconfig \
        {,/usr}/etc/nsswitch.conf \
        {,/usr}/etc/protocols \
        {,/usr}/etc/rpc \
        {,/usr}/etc/services \
        "$systemdutildir"/system-generators/rpc-pipefs-generator \
        "$systemdsystemunitdir"/rpc_pipefs.target \
        "$systemdsystemunitdir"/var-lib-nfs-rpc_pipefs.mount \
        rpc.idmapd mount.nfs mount.nfs4 umount sed chown grep

    for _f in {,/usr}/etc/nfs.conf {,/usr}/etc/nfs.conf.d/*.conf; do
        [[ -f $_f ]] || continue
        inst_simple "$_f"
        _includes=($(grep "include" "$_f" | grep -v "^#" | cut -d '=' -f 2))
        for _i in "${_includes[@]}"; do
            _i=${_i#-}
            [[ -f $_i ]] || continue
            inst_simple "$_i"
        done
    done

    [[ -d $initdir/etc/modprobe.d ]] || mkdir -p "$initdir"/etc/modprobe.d
    echo "alias nfs4 nfs" > "$initdir"/etc/modprobe.d/nfs.conf

    _arch=${DRACUT_ARCH:-$(uname -m)}
    inst_libdir_file \
        {"tls/$_arch/",tls/,"$_arch/",}"libnfsidmap*.so*" \
        {"tls/$_arch/",tls/,"$_arch/",}"libnfsidmap*/*.so"
    _nsslibs=$(
        cat /{,usr/}etc/nsswitch.conf 2> /dev/null \
            | sed -e '/^#/d' -e 's/^.*://' -e 's/\[NOTFOUND=return\]//' \
            | tr -s '[:space:]' '\n' | sort -u | tr -s '[:space:]' '|'
    )
    _nsslibs=${_nsslibs#|}
    _nsslibs=${_nsslibs%|}
    inst_libdir_file -n "$_nsslibs" \
        {"tls/$_arch/",tls/,"$_arch/",}"libnss_*.so*"

    inst_hook cmdline 90 "$moddir/parse-nfsroot.sh"
    inst_hook pre-udev 99 "$moddir/nfs-start-rpc.sh"
    inst_hook cleanup 99 "$moddir/nfsroot-cleanup.sh"
    inst "$moddir/nfsroot.sh" "/sbin/nfsroot"
    inst "$moddir/nfs-lib.sh" "/lib/nfs-lib.sh"

    inst_dir "/var/lib/nfs"

    # For hostonly, only install rpcbind for NFS < 4
    if ! [[ $hostonly ]] || [[ "$(get_nfs_type)" == "nfs" ]]; then
        inst_multiple -o \
            "$tmpfilesdir"/rpcbind.conf \
            rpcbind rpc.statd

        # Add non-standard user/groups (some distros provide their sysusers conf
        # files, but it's unmanageable to add all the specific cases).
        grep -E '^_rpc:|^nfsnobody:|^rpc:|^rpcuser:|^statd:' "$dracutsysrootdir"/etc/passwd >> "$initdir/etc/passwd"
        grep -E '^nobody:|^nogroup:|^rpc:|^statd:' "$dracutsysrootdir"/etc/group >> "$initdir/etc/group"

        # Create fixed rpc.statd state directories in /var/lib/nfs. It can be
        # configured at build time (--with-statdpath) and and there is
        # divergence between distros, so we will call rpc.statd with '-P'.
        if $DRACUT_CP -L --preserve=ownership -t "$initdir"/var/lib/nfs /var/lib/nfs/sm; then
            rm -rf "$initdir"/var/lib/nfs/sm/*
        else
            ddebug "nfs: rpc.statd default monitor directory '/var/lib/nfs/sm' not found."
            mkdir -m 0700 -p "$initdir"/var/lib/nfs/sm
        fi
        if $DRACUT_CP -L --preserve=ownership -t "$initdir"/var/lib/nfs /var/lib/nfs/sm.bak; then
            rm -rf "$initdir"/var/lib/nfs/sm.bak/*
        else
            ddebug "nfs: rpc.statd default notify directory '/var/lib/nfs/sm.bak' not found."
            mkdir -m 0700 -p "$initdir"/var/lib/nfs/sm.bak
        fi
    fi

    dracut_need_initqueue
}
