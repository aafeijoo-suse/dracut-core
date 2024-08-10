#!/bin/bash

# called by dracut
check() {
    swap_on_netdevice() {
        local _dev
        for _dev in "${swap_devs[@]}"; do
            block_is_netdevice "$(get_maj_min "$_dev")" && return 0
        done
        return 1
    }

    # Only support resume if there is any suitable swap and
    # it is not mounted on a net device
    [[ $hostonly ]] || [[ $mount_needs ]] && {
        # sanity check: do not add the resume module if there is a
        # resume argument pointing to a non existent disk or to a
        # volatile swap
        local _resume
        _resume=$(getarg resume=)
        if [ -n "$_resume" ]; then
            _resume="$(label_uuid_to_dev "$_resume")"
            if [ ! -e "$_resume" ]; then
                derror "Current resume kernel argument points to an invalid disk"
                return 255
            fi
            if [[ "$_resume" == /dev/mapper/* ]]; then
                if [[ -f /etc/crypttab ]]; then
                    local _mapper _opts
                    read -r _mapper _ _ _opts < <(grep -m1 -w "^${_resume#/dev/mapper/}" /etc/crypttab)
                    if [[ -n "$_mapper" ]] && [[ "$_opts" == *swap* ]]; then
                        derror "Current resume kernel argument points to a volatile swap"
                        return 255
                    fi
                fi
            fi
        fi
        ((${#swap_devs[@]})) || return 255
        swap_on_netdevice && return 255
    }

    return 0
}

# called by dracut
install() {

    inst_multiple -o \
        "$systemdutildir"/system-generators/systemd-hibernate-resume-generator \
        "$systemdsystemunitdir"/systemd-hibernate-resume.service \
        "$systemdutildir"/systemd-hibernate-resume
}
