#!/bin/bash

type load_fstype > /dev/null 2>&1 || . /lib/dracut-lib.sh

if load_fstype sunrpc rpc_pipefs; then
    # Start rpc_pipefs.target
    systemctl start rpc_pipefs.target

    # Start rpcbind
    if command -v rpcbind > /dev/null && [ -z "$(pidof rpcbind)" ]; then
        # Create default state directory for distros that do not create it via
        # tmpfiles conf file
        if ! [[ -e /usr/lib/tmpfiles.d/rpcbind.conf ]]; then
            mkdir -m 0700 -p /run/rpcbind
            _rpcuser=$(grep -m1 -E '^_rpc:|^nfsnobody:|^rpc:|^rpcuser:' /etc/passwd)
            [[ -n "$_rpcuser" ]] && chown "${_rpcuser%%:*}": /run/rpcbind
        fi
        rpcbind
    fi

    # Start rpc.statd as mount won't let us use locks on a NFSv4 filesystem
    # without talking to it.
    command -v rpc.statd > /dev/null && [ -z "$(pidof rpc.statd)" ] && rpc.statd -P /var/lib/nfs

    # Start rpc.idmapd in case nfs4_disable_idmapping = 0
    command -v rpc.idmapd > /dev/null && [ -z "$(pidof rpc.idmapd)" ] && rpc.idmapd
else
    warn "nfs-start-rpc: kernel module 'sunrpc' not in the initramfs, or support for filesystem 'rpc_pipefs' missing"
fi
