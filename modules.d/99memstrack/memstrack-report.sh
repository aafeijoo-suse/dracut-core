#!/bin/sh
. /lib/dracut-lib.sh

if ! [ "$DEBUG_MEM_LEVEL" -ge 4 ]; then
    return 0
fi

systemctl stop memstrack.service

cat /.memstrack
