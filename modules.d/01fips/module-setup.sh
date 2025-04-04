#!/bin/bash

# called by dracut
check() {
    return 255
}

# called by dracut
depends() {
    echo bash
    return 0
}

# called by dracut
installkernel() {
    local _fipsmodules _mod _bootfstype

    if [[ -f "${srcmods}/modules.fips" ]]; then
        read -d '' -r _fipsmodules < "${srcmods}/modules.fips"
    else
        _fipsmodules=""

        # Hashes:
        _fipsmodules+="sha1 sha224 sha256 sha384 sha512 "
        _fipsmodules+="sha3-224 sha3-256 sha3-384 sha3-512 "
        _fipsmodules+="crc32c crct10dif ghash "

        # Hashes, platform specific:
        _fipsmodules+="sha512-ssse3 sha1-ssse3 sha256-ssse3 "
        _fipsmodules+="ghash-clmulni-intel "

        # Ciphers:
        _fipsmodules+="cipher_null des3_ede aes cfb dh ecdh "

        # Modes/templates:
        _fipsmodules+="ecb cbc ctr xts gcm ccm authenc hmac cmac ofb cts "

        # Compression algs:
        _fipsmodules+="deflate lzo zlib "

        # PRNG algs:
        _fipsmodules+="ansi_cprng "

        # Misc:
        _fipsmodules+="aead cryptomgr tcrypt crypto_user "
    fi

    # shellcheck disable=SC2174
    mkdir -m 0755 -p "${initdir}/etc/modprobe.d"

    for _mod in $_fipsmodules; do
        if hostonly='' instmods -c -s "$_mod"; then
            echo "$_mod" >> "${initdir}/etc/fipsmodules"
            echo "blacklist $_mod" >> "${initdir}/etc/modprobe.d/fips.conf"
        fi
    done

    # with hostonly_default_device fs module for /boot is not installed by default
    if [[ $hostonly ]] && [[ $hostonly_default_device == "no" ]]; then
        _bootfstype=$(find_mp_fstype /boot)
        if [[ -n $_bootfstype ]]; then
            hostonly='' instmods "$_bootfstype"
        else
            dwarning "Can't determine fs type for /boot, FIPS check may fail."
        fi
    fi
}

# called by dracut
install() {
    inst_multiple modprobe rmmod mount uname umount sed
    inst_multiple -o fipscheck \
                     /usr/libexec/libkcapi/fipscheck \
                     /usr/lib64/libkcapi/fipscheck \
                     /usr/lib/libkcapi/fipscheck

    inst_hook pre-udev 01 "$moddir/fips-load-crypto.sh"
    inst_hook pre-pivot 00 "$moddir/fips-boot.sh"
    inst_hook pre-pivot 01 "$moddir/fips-noboot.sh"
    inst_script "$moddir/fips-lib.sh" /lib/fips-lib.sh

    inst_simple /etc/system-fips
    [ -c "${initdir}"/dev/random ] || mknod "${initdir}"/dev/random c 1 8 \
        || {
            dfatal "Cannot create /dev/random"
            exit 1
        }
    [ -c "${initdir}"/dev/urandom ] || mknod "${initdir}"/dev/urandom c 1 9 \
        || {
            dfatal "Cannot create /dev/urandom"
            exit 1
        }
}
