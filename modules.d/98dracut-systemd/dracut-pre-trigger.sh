#!/bin/bash

export DRACUT_SYSTEMD=1
if [ -f /dracut-state.sh ]; then
    . /dracut-state.sh 2> /dev/null
fi
type getarg > /dev/null 2>&1 || . /lib/dracut-lib.sh

source_conf /etc/conf.d

make_trace_mem "hook pre-trigger" '1:shortmem' '2+:mem' '3+:slab'
# pre-trigger scripts are sourced before systemd-udev-trigger starts
getargs 'rd.break=pre-trigger' && emergency_shell -n pre-trigger "Break before pre-trigger"
source_hook pre-trigger

udevadm control --reload > /dev/null 2>&1 || :

export -p > /dracut-state.sh

exit 0
