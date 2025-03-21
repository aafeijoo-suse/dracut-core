#!/bin/bash

type load_fstype > /dev/null 2>&1 || . /lib/dracut-lib.sh

if load_fstype sunrpc rpc_pipefs; then
    # Start rpc_pipefs.target
    systemctl start rpc_pipefs.target

    # Start rpcbind
    if command -v rpcbind > /dev/null && [ -z "$(pidof rpcbind)" ]; then
        mkdir -p /run/rpcbind
        _rpcuser=$(grep -m1 -E '^nfsnobody:|^rpc:|^rpcuser:' /etc/passwd)
        [[ -n "$_rpcuser" ]] && chown "${_rpcuser%%:*}": /run/rpcbind
        rpcbind
    fi

    command -v rpc.idmapd > /dev/null && [ -z "$(pidof rpc.idmapd)" ] && rpc.idmapd
else
    warn "nfs-start-rpc: kernel module 'sunrpc' not in the initramfs, or support for filesystem 'rpc_pipefs' missing"
fi
