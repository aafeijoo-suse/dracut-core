#!/bin/bash

type getarg > /dev/null 2>&1 || . /lib/dracut-lib.sh
type mount_nfs > /dev/null 2>&1 || . /lib/nfs-lib.sh

[ "$#" = 3 ] || exit 1

# root is in the form root=nfs[4]:[server:]path[:options]
root="$2"
NEWROOT="$3"

if mount_nfs "$root" "$NEWROOT"; then
    [ -e /dev/root ] || ln -s null /dev/root
    [ -e /dev/nfs ] || ln -s null /dev/nfs
else
    die "nfsroot: failed to mount NFS"
fi

[ -f "$NEWROOT"/etc/fstab ] && cat "$NEWROOT"/etc/fstab > /dev/null

# inject new exit_if_exists
# shellcheck disable=SC2016
echo 'settle_exit_if_exists="--exit-if-exists=/dev/root"; rm -- "$job"' > "$hookdir"/initqueue/nfs.sh
# force udevsettle to break
: > "$hookdir"/initqueue/work

need_shutdown
