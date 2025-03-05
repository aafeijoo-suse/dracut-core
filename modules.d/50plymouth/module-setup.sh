#!/bin/bash

# called by dracut
check() {
    [[ "$mount_needs" ]] && return 1
    [[ -x /usr/libexec/plymouth/plymouth-populate-initrd ]] || return 1

    require_binaries plymouthd plymouth plymouth-set-default-theme
}

# called by dracut
depends() {
    echo drm
}

# called by dracut
install() {
    /usr/libexec/plymouth/plymouth-populate-initrd -t "$initdir"

    inst_hook emergency 50 "$moddir"/plymouth-emergency.sh

    inst_multiple plymouthd plymouth plymouth-set-default-theme
}
