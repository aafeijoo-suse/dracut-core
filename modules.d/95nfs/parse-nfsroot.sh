#!/bin/bash
#
# Preferred format:
#       root=nfs[4]:[server:]path[:options]
#
# This syntax can come from DHCP root-path as well.
#
# Legacy format:
#       root=/dev/nfs nfsroot=[server:]path[,options]
#
# In Legacy root=/dev/nfs mode, if the 'nfsroot' parameter is not given
# on the command line or is empty, the dhcp root-path is used as
# [server:]path[:options] or the default "/tftpboot/%s" will be used.
#
# If server is unspecified it will be pulled from one of the following
# sources, in order:
#       static ip= option on kernel command line
#       DHCP next-server option
#       DHCP server-id option
#       DHCP root-path option
#
# NFSv4 is only used if explicitly requested with nfs4: prefix, otherwise
# NFSv3 is used.
#

type getarg > /dev/null 2>&1 || . /lib/dracut-lib.sh
type nfsroot_to_var > /dev/null 2>&1 || . /lib/nfs-lib.sh

# This script is sourced, so root should be set. But let's be paranoid
[ -z "$root" ] && root=$(getarg root=)
[ -z "$nfsroot" ] && nfsroot=$(getarg nfsroot=)

[ -n "$netroot" ] && oldnetroot="$netroot"

# netroot= cmdline argument must be ignored, but must be used if
# we're inside netroot to parse dhcp root-path
if [ -n "$netroot" ]; then
    for n in $(getargs netroot=); do
        [ "$n" = "$netroot" ] && break
    done
    if [ "$n" = "$netroot" ]; then
        netroot=$root
    fi
else
    netroot=$root
fi

# LEGACY: nfsroot= is valid only if root=/dev/nfs
if [ -n "$nfsroot" ]; then
    # @deprecated
    warn "nfs: argument nfsroot is deprecated and might be removed in a future release. See 'man dracut.kernel' for more information."
    if [ "$(getarg root=)" != "/dev/nfs" ]; then
        die "nfs: argument nfsroot only accepted for legacy root=/dev/nfs"
    fi
    netroot=nfs:$nfsroot
fi

case "$netroot" in
    /dev/nfs) netroot=nfs ;;
    /dev/*)
        if [ -n "$oldnetroot" ]; then
            netroot="$oldnetroot"
        else
            unset netroot
        fi
        return
        ;;
esac

# Continue if nfs
case "${netroot%%:*}" in
    nfs | nfs4 | /dev/nfs) ;;
    *)
        if [ -n "$oldnetroot" ]; then
            netroot="$oldnetroot"
        else
            unset netroot
        fi
        return
        ;;
esac

# Check required arguments

if nfsdomain=$(getarg rd.nfs.domain); then
    if [ -f /etc/idmapd.conf ]; then
        sed -i -e \
            "s/^[[:space:]#]*Domain[[:space:]]*=.*/Domain = $nfsdomain/g" \
            /etc/idmapd.conf
    fi
    # and even again after the sed, in case it was not yet specified
    echo "Domain = $nfsdomain" >> /etc/idmapd.conf
fi

nfsroot_to_var "$netroot"
[ "$path" = "error" ] && die "nfs: argument nfsroot must contain a valid path"
[ -z "$server" ] && die "nfs: argument nfsroot must specify a server"

# Set fstype, might help somewhere
fstype=${nfs#/dev/}

# Rewrite root so we don't have to parse this uglyness later on again
netroot="$fstype:$server:$path:$options"

# Done, all good!
# shellcheck disable=SC2034
rootok=1

# Shut up init error check or make sure that block parser wont get
# confused by having /dev/nfs[4]
root="$fstype"

# shellcheck disable=SC2016
echo '[ -e $NEWROOT/proc ]' > "$hookdir"/initqueue/finished/nfsroot.sh
