#!/bin/bash

type getarg > /dev/null 2>&1 || . /lib/dracut-lib.sh

if ! fipsmode=$(getarg fips) || [ "$fipsmode" = "0" ]; then
    rm -f -- /etc/modprobe.d/fips.conf > /dev/null 2>&1
elif [ -z "$fipsmode" ]; then
    die "FIPS mode have to be enabled by 'fips=1' not just 'fips'"
elif getarg boot= > /dev/null; then
    . /lib/fips-lib.sh
    fips_info "fips-boot: start"
    if mount_boot; then
        do_fips || die "FIPS integrity test failed"
    fi
    fips_info "fips-boot: done!"
fi
