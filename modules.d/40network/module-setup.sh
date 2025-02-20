#!/bin/bash

# called by dracut
check() {
    require_binaries ip sed awk grep || return 1
    return 255
}

# called by dracut
depends() {
    is_qemu_virtualized && echo -n "qemu-net "

    for module in network-manager network-legacy; do
        if dracut_module_included "$module"; then
            network_handler="$module"
            break
        fi
    done

    if [ -z "$network_handler" ]; then
        if check_module "network-manager" 1; then
            network_handler="network-manager"
        else
            network_handler="network-legacy"
        fi
    fi
    echo "kernel-network-modules $network_handler"
    return 0
}

# called by dracut
installkernel() {
    return 0
}

# called by dracut
install() {
    inst_script "$moddir/netroot.sh" "/sbin/netroot"
    inst_simple "$moddir/net-lib.sh" "/lib/net-lib.sh"
    inst_hook pre-udev 50 "$moddir/ifname-genrules.sh"
    inst_hook cmdline 91 "$moddir/dhcp-root.sh"
    inst_multiple ip sed awk grep
    inst_multiple -o arping arping2
    dracut_need_initqueue
}
