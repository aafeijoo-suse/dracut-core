#!/bin/bash

type pidof > /dev/null 2>&1 || . /lib/dracut-lib.sh

pid=$(pidof rpc.idmapd)
[ -n "$pid" ] && kill "$pid"

pid=$(pidof rpcbind)
[ -n "$pid" ] && kill "$pid"

rpcpipefspath=$(findmnt -n -t rpc_pipefs -o TARGET)
if [[ -n $rpcpipefspath ]]; then
    [ -d "${NEWROOT}${rpcpipefspath}" ] \
        || mkdir -m 0755 -p "${NEWROOT}${rpcpipefspath}" 2> /dev/null
    if [ -d "${NEWROOT}${rpcpipefspath}" ]; then
        # mount --move does not work (moving a mount residing under a shared
        # mount is unsupported), so --bind + umount.
        mount --bind "$rpcpipefspath" "${NEWROOT}${rpcpipefspath}"
    fi
    umount "$rpcpipefspath" 2> /dev/null
fi
