#!/bin/bash

export DRACUT_SYSTEMD=1
if [ -f /dracut-state.sh ]; then
    . /dracut-state.sh 2> /dev/null
fi
type getarg > /dev/null 2>&1 || . /lib/dracut-lib.sh

source_conf /etc/conf.d

make_trace_mem "hook pre-pivot" '1:shortmem' '2+:mem' '3+:slab'
# pre-pivot scripts are sourced just before we doing cleanup
getargs 'rd.break=pre-pivot' && emergency_shell -n pre-pivot "Break before pre-pivot"
source_hook pre-pivot

# cleanup scripts are sourced just before we switch over to the new root
getargs 'rd.break=cleanup' && emergency_shell -n cleanup "Break before cleanup"
source_hook cleanup

_bv=$(getarg rd.break) && [ -z "$_bv" ] \
    && emergency_shell -n switch_root "Break before switch_root"
unset _bv

# remove helper symlink
[ -h /dev/root ] && rm -f -- /dev/root
[ -h /dev/nfs ] && rm -f -- /dev/nfs

exit 0
