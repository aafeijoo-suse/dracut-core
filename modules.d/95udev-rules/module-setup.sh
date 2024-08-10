#!/bin/bash

# called by dracut
check() {
    require_binaries cat uname blkid || return 1
    return 0
}

# called by dracut
depends() {
    echo systemd-udevd
    return 0
}

# called by dracut
install() {

    inst_multiple cat uname blkid

    inst_rules \
        55-scsi-sg3_id.rules \
        58-scsi-sg3_symlink.rules \
        59-scsi-sg3_utils.rules \
        60-pcmcia.rules \
        95-udev-late.rules \
        80-net-name-slot.rules \
        "$moddir/59-persistent-storage.rules" \
        "$moddir/61-persistent-storage.rules"

    prepare_udev_rules 59-persistent-storage.rules 61-persistent-storage.rules

    {
        grep '^floppy:' /etc/group 2> /dev/null
    } >> "$initdir/etc/group"

    inst_multiple -o \
        "${udevdir}"/create_floppy_devices \
        "${udevdir}"/fw_unit_symlinks.sh \
        "${udevdir}"/hid2hci \
        "${udevdir}"/path_id \
        "${udevdir}"/input_id \
        "${udevdir}"/usb_id \
        "${udevdir}"/pcmcia-socket-startup \
        "${udevdir}"/pcmcia-check-broken-cis

    if [[ $hostonly ]]; then
        inst_multiple -o /etc/pcmcia/config.opts

        # only include persistent network device name rules if network is set up in the initrd
        # avoid interference with systemd predictable network device naming
        if ! dracut_module_included "network-legacy" && ! dracut_module_included "network-manager"; then
            if [ -e "${initdir}"/"${udevrulesconfdir}"/70-persistent-net.rules ]; then
                rm -f "${initdir}"/"${udevrulesconfdir}"/70-persistent-net.rules
            fi
        fi
    fi

}
