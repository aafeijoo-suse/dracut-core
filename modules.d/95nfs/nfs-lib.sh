#!/bin/bash

type getarg > /dev/null 2>&1 || . /lib/dracut-lib.sh

# nfs_to_var NFSROOT
# use NFSROOT to set $nfs, $server, $path, and $options.
# NFSROOT is something like: nfs[4]:<server>:/<path>[:<options>|,<options>]
nfs_to_var() {
    # Unfortunately, there's multiple styles of nfs "URL" in use, so we need
    # extra functions to parse them into $nfs, $server, $path, and $options.
    case "$1" in
        nfs://*) rfc2224_nfs_to_var "$1" ;;
        *) nfsroot_to_var "$1" ;;
    esac
}

# root=nfs:[<server-ip>:]<root-dir>[:<nfs-options>]
# root=nfs4:[<server-ip>:]<root-dir>[:<nfs-options>]
nfsroot_to_var() {
    # strip nfs[4]:
    local arg="$*:"
    nfs="${arg%%:*}"
    arg="${arg##"$nfs":}"

    # check if we have a server
    if strstr "$arg" ':/'; then
        server="${arg%%:/*}"
        arg="/${arg##*:/}"
    fi

    path="${arg%%:*}"

    # rest are options
    options="${arg##"$path"}"
    # strip leading ":"
    options="${options##:}"
    # strip  ":"
    options="${options%%:}"

    # Does it really start with '/'?
    [ -n "${path%%/*}" ] && path="error"

    #Fix kernel legacy style separating path and options with ','
    if [ "$path" != "${path#*,}" ]; then
        options=${path#*,}
        path=${path%%,*}
    fi
}

# RFC2224: nfs://<server>[:<port>]/<path>
rfc2224_nfs_to_var() {
    nfs="nfs"
    server="${1#nfs://}"
    path="/${server#*/}"
    server="${server%%/*}"
    server="${server%%:}" # anaconda compat (nfs://<server>:/<path>)
    local port="${server##*:}"
    [ "$port" != "$server" ] && options="port=$port"
}

# Look through $options, fix "rw"/"ro", move "lock"/"nolock" to $nfslock
munge_nfs_options() {
    local f="" flags="" nfsrw="ro" OLDIFS="$IFS"
    IFS=,
    for f in $options; do
        case $f in
            ro | rw) nfsrw=$f ;;
            lock | nolock) nfslock=$f ;;
            *) flags=${flags:+$flags,}$f ;;
        esac
    done
    IFS="$OLDIFS"

    # Override rw/ro if set on cmdline
    getarg ro > /dev/null && nfsrw=ro
    getarg rw > /dev/null && nfsrw=rw

    options=$nfsrw${flags:+,$flags}
}

# mount_nfs NFSROOT MNTDIR
mount_nfs() {
    local nfsroot="$1" mntdir="$2"
    local nfs="" server="" path="" options=""
    nfs_to_var "$nfsroot"
    if [ -z "$server" ]; then
        warn "mount_nfs: missing required parameter 'server'"
        return 1
    fi
    munge_nfs_options
    if [ "$nfsrw" = "ro" ] && [ "$nfslock" = "lock" ]; then
        warn "mount_nfs: filesystem accessed in read-only mode, ignoring 'lock' option because no locking is needed"
        nfslock="nolock"
    fi
    if [ "$nfs" = "nfs4" ]; then
        options=$options${nfslock:+,$nfslock}
    else
        # NFSv{2,3} doesn't support using locks as it requires a helper to
        # transfer the rpcbind state to the new root
        [ "$nfslock" = "lock" ] \
            && warn "mount_nfs: locks unsupported on NFSv{2,3}, using nolock"
        options=$options,nolock
    fi
    mount -t "$nfs" -o"$options" "$server:$path" "$mntdir"
}
