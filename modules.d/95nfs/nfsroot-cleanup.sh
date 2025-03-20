#!/bin/bash

type incol2 > /dev/null 2>&1 || . /lib/dracut-lib.sh

pid=$(pidof rpc.idmapd)
[ -n "$pid" ] && kill "$pid"

pid=$(pidof rpcbind)
[ -n "$pid" ] && kill "$pid"

if incol2 /proc/mounts /var/lib/nfs/rpc_pipefs; then
    [ -d "$NEWROOT"/var/lib/nfs/rpc_pipefs ] \
        || mkdir -m 0755 -p "$NEWROOT"/var/lib/nfs/rpc_pipefs 2> /dev/null
    if [ -d "$NEWROOT"/var/lib/nfs/rpc_pipefs ]; then
        # mount --move does not work (moving a mount residing under a shared
        # mount is unsupported), so --bind + umount.
        mount --bind /var/lib/nfs/rpc_pipefs "$NEWROOT"/var/lib/nfs/rpc_pipefs
    fi
    umount /var/lib/nfs/rpc_pipefs 2> /dev/null
fi
