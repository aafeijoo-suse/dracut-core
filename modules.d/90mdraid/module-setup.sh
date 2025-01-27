#!/bin/bash

# called by dracut
check() {
    local dev holder

    # No mdadm?  No mdraid support.
    require_binaries mdadm || return 1

    [[ $hostonly ]] || [[ $mount_needs ]] && {
        for dev in "${!host_fs_types[@]}"; do
            [[ ${host_fs_types[$dev]} != *_raid_member ]] && continue

            DEVPATH=$(get_devpath_block "$dev")

            for holder in "$DEVPATH"/holders/*; do
                [[ -e $holder ]] || continue
                [[ -e "$holder/md" ]] && return 0
                break
            done

        done
        return 255
    }

    return 0
}

# called by dracut
depends() {
    echo rootfs-block
    return 0
}

# called by dracut
installkernel() {
    instmods '=drivers/md'
}

# called by dracut
cmdline() {
    local _activated dev line UUID
    declare -A _activated

    for dev in "${!host_fs_types[@]}"; do
        [[ ${host_fs_types[$dev]} != *_raid_member ]] && continue

        UUID=$(
            /sbin/mdadm --examine --export "$dev" \
                | while read -r line || [[ "$line" ]]; do
                    [[ ${line#MD_UUID=} == "$line" ]] && continue
                    printf "%s" "${line#MD_UUID=} "
                done
        )

        [[ -z $UUID ]] && continue

        if ! [[ ${_activated[${UUID}]} ]]; then
            printf "%s" " rd.md.uuid=${UUID}"
            _activated["${UUID}"]=1
        fi

    done
}

# called by dracut
install() {
    inst_multiple -o \
        "$systemdsystemunitdir"/mdadm-grow-continue@.service \
        "$systemdsystemunitdir"/mdadm-last-resort@.service \
        "$systemdsystemunitdir"/mdadm-last-resort@.timer \
        "$systemdsystemunitdir"/mdmon@.service \
        mdadm mdmon partx

    if [[ $hostonly_cmdline == "yes" ]]; then
        local _raidconf
        _raidconf=$(cmdline)
        [[ $_raidconf ]] && printf "%s\n" "$_raidconf" >> "${initdir}/etc/cmdline.d/90mdraid.conf"
    fi

    inst_rules 63-md-raid-arrays.rules 64-md-raid-assembly.rules
    # remove incremental assembly from stock rules, so they don't shadow
    # 65-md-inc*.rules and its fine-grained controls, or cause other problems
    # when we explicitly don't want certain components to be incrementally
    # assembled
    # shellcheck disable=SC2016
    if [ -f "${initdir}${udevdir}/rules.d/64-md-raid-assembly.rules" ]; then
        sed -i -r -e '/(RUN|IMPORT\{program\})\+?="[[:alpha:]/]*mdadm[[:blank:]]+(--incremental|-I)[[:blank:]]+(--export )?(\$env\{DEVNAME\}|\$devnode)/d' \
            "${initdir}${udevdir}/rules.d/64-md-raid-assembly.rules"
    fi

    inst_rules "$moddir/65-md-incremental-imsm.rules"

    if [[ $hostonly ]] || [[ $mdadmconf == "yes" ]]; then
        if [[ -f /etc/mdadm.conf ]]; then
            inst -H /etc/mdadm.conf
        else
            [[ -f /etc/mdadm/mdadm.conf ]] && inst -H /etc/mdadm/mdadm.conf /etc/mdadm.conf
        fi
        if [[ -d /etc/mdadm.conf.d ]]; then
            local f
            inst_dir /etc/mdadm.conf.d
            for f in /etc/mdadm.conf.d/*.conf; do
                [[ -f "$f" ]] || continue
                inst -H "$f"
            done
        fi
    fi

    inst_hook pre-udev 30 "$moddir/mdmon-pre-udev.sh"
    inst_hook pre-trigger 30 "$moddir/parse-md.sh"
    inst_hook pre-mount 10 "$moddir/mdraid-waitclean.sh"
    inst_script "$moddir/mdraid-cleanup.sh" /sbin/mdraid-cleanup
    inst_script "$moddir/mdraid_start.sh" /sbin/mdraid_start

    dracut_need_initqueue
}
