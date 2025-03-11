#!/bin/bash

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

# systemd lets stdout go to journal only, but the system
# has to halt when the integrity check fails to satisfy FIPS.
fips_info() {
    echo "$*" >&2
}

nonfatal_modprobe() {
    modprobe "$1" 2>&1 > /dev/stdout \
        | while read -r line || [ -n "$line" ]; do
            echo "${line#modprobe: FATAL: }" >&2
        done
}

fips_load_crypto() {
    local _fipsmodules
    local _k
    local _v
    local _module
    local _found

    read -d '' -r _fipsmodules </etc/fipsmodules

    fips_info "Loading and integrity checking all crypto modules"
    mv /etc/modprobe.d/fips.conf /etc/modprobe.d/fips.conf.bak
    for _module in $_fipsmodules; do
        if [[ $_module != "tcrypt" ]]; then
            if ! nonfatal_modprobe "${_module}" 2>/tmp/fips.modprobe_err; then
                # check if kernel provides generic algo
                _found=0
                while read -r _k _ _v || [[ -n $_k ]]; do
                    [[ $_k != "name" ]] && [[ $_k != "driver" ]] && continue
                    [[ $_v != "$_module" ]] && continue
                    _found=1
                    break
                done </proc/crypto
                # If we find some hardware specific modules and cannot load them
                # it is not a problem, proceed.
                if [[ $_found == "0" ]]; then
                    # shellcheck disable=SC2055
                    if [[ $_module != "${_module%intel}" \
                       || $_module != "${_module%ssse3}" \
                       || $_module != "${_module%x86_64}" \
                       || $_module != "${_module%z90}" \
                       || $_module != "${_module%s390}" \
                       || $_module == "twofish_x86_64_3way" \
                       || $_module == "ablk_helper" \
                       || $_module == "glue_helper" \
                       || $_module == "sha1-mb" \
                       || $_module == "sha256-mb" \
                       || $_module == "sha512-mb" ]]; then
                        _found=1
                    fi
                fi
                [[ $_found == "0" ]] && cat /tmp/fips.modprobe_err >&2 && return 1
            fi
        fi
    done
    mv /etc/modprobe.d/fips.conf.bak /etc/modprobe.d/fips.conf

    fips_info "Self testing crypto algorithms"
    modprobe tcrypt || return 1
    rmmod tcrypt
}

mount_boot() {
    local _boot
    local _boot_dev

    _boot=$(getarg boot=)
    if [[ -n $_boot ]]; then
        if [[ -d /boot ]] && ismounted /boot; then
            _boot_dev=
            if command -v findmnt >/dev/null; then
                _boot_dev=$(findmnt -n -o SOURCE /boot)
            fi
            fips_info "Ignoring 'boot=$_boot' as /boot is already mounted ${_boot_dev:+"from '$_boot_dev'"}"
            return 0
        fi

        case "$_boot" in
            LABEL=* | UUID=* | PARTUUID=* | PARTLABEL=*)
                _boot="$(label_uuid_to_dev "$_boot")"
                ;;
            /dev/*) ;;
            *)
                die "You have to specify boot=<boot device> as a boot option for fips=1"
                ;;
        esac

        if ! [[ -e $_boot ]]; then
            udevadm trigger --action=add >/dev/null 2>&1

            _i=0
            while ! [[ -e $_boot ]]; do
                udevadm settle --exit-if-exists="$_boot"
                [[ -e $_boot ]] && break
                sleep 0.5
                _i=$((_i + 1))
                [[ $_i -gt 40 ]] && break
            done
        fi

        [[ -e $_boot ]] || return 1

        mkdir -p /boot
        fips_info "Mounting $_boot as /boot"
        mount -oro "$_boot" /boot || return 1
        export FIPS_MOUNTED_BOOT=1
    elif ! ismounted /boot && [[ -d "$NEWROOT/boot" ]]; then
        # shellcheck disable=SC2114
        rm -fr -- /boot
        ln -sf "$NEWROOT/boot" /boot || return 1
    else
        die "You have to specify boot=<boot device> as a boot option for fips=1"
    fi

    return 0
}

get_vmname() {
    local _vmname

    case "$(uname -m)" in
        s390 | s390x)
            _vmname=image
            ;;
        ppc*)
            _vmname=vmlinux
            ;;
        aarch64)
            _vmname=Image
            ;;
        armv*)
            _vmname=zImage
            ;;
        *)
            _vmname=vmlinuz
            ;;
    esac

    echo "$_vmname"
}

# find fipscheck, prefer kernel-based version
fipscheck() {
    local _f

    for _f in /usr/{libexec,lib}/libkcapi/fipscheck /usr/bin/fipscheck; do
        if [[ -x $_f ]]; then
            echo "$_f"
            return 0
        fi
    done

    return 1
}

do_fips() {
    local _boot_image
    local _boot_image_name
    local _boot_image_path
    local _boot_image_hmac
    local _boot_image_kernel
    local _vmname
    local _kver
    local _fipscheck

    if ! getargbool 0 rd.fips.skipkernel; then

        fips_info "Checking integrity of kernel"

        _boot_image="$(getarg BOOT_IMAGE)"

        # Trim off any leading GRUB boot device (e.g. ($root) )
        # shellcheck disable=SC2001
        _boot_image="$(echo "${_boot_image}" | sed 's/^(.*)//')"

        _boot_image_name="${_boot_image##*/}"
        _boot_image_path="${_boot_image%"${_boot_image_name}"}"

        _vmname="$(get_vmname)"
        _kver="$(uname -r)"

        if [[ -z $_boot_image_name ]]; then
            _boot_image_name="${_vmname}-${_kver}"
        elif ! [[ -e "/boot/${_boot_image_path}/${_boot_image}" ]]; then
            # if /boot is not a separate partition BOOT_IMAGE might start with /boot
            _boot_image_path=${_boot_image_path#"/boot"}
            # on some achitectures BOOT_IMAGE does not contain path to kernel
            # so if we can't find anything, let's treat it in the same way as if it was empty
            if ! [[ -e "/boot/${_boot_image_path}/${_boot_image_name}" ]]; then
                _boot_image_name="${_vmname}-${_kver}"
                _boot_image_path=""
            fi
        fi

        _boot_image_hmac="/boot/${_boot_image_path}/.${_boot_image_name}.hmac"
        if ! [[ -e ${_boot_image_hmac} ]]; then
            warn "${_boot_image_hmac} does not exist"
            return 1
        fi

        _boot_image_kernel="/boot/${_boot_image_path}${_boot_image_name}"
        if ! [[ -e ${_boot_image_kernel} ]]; then
            warn "${_boot_image_kernel} does not exist"
            return 1
        fi

        _fipscheck="$(fipscheck)"
        if [[ -x $_fipscheck ]]; then
            "$_fipscheck" "${_boot_image_kernel}" || return 1
        else
            warn "Could not find fipscheck to verify HMAC-SHA256 checksum files"
            return 1
        fi

    fi

    fips_info "All initrd crypto checks done"

    : >/tmp/fipsdone

    if [[ $FIPS_MOUNTED_BOOT == 1 ]]; then
        fips_info "Unmounting /boot"
        umount /boot >/dev/null 2>&1
    else
        fips_info "Not unmounting /boot"
    fi

    return 0
}
