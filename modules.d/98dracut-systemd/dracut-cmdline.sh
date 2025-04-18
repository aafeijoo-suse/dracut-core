#!/bin/bash

if [ -f /dracut-state.sh ]; then
    . /dracut-state.sh 2> /dev/null
fi
type getarg > /dev/null 2>&1 || . /lib/dracut-lib.sh

[ -f /usr/lib/initrd-release ] && . /usr/lib/initrd-release
[ -n "$DRACUT_VERSION" ] && info "dracut-$DRACUT_VERSION"

if ! getargbool 1 'rd.hostonly'; then
    [ -f /etc/cmdline.d/99-cmdline-ask.conf ] && mv /etc/cmdline.d/99-cmdline-ask.conf /tmp/99-cmdline-ask.conf
    remove_hostonly_files
    systemctl --no-block daemon-reload
    [ -f /tmp/99-cmdline-ask.conf ] \
        && mv /tmp/99-cmdline-ask.conf /etc/cmdline.d/99-cmdline-ask.conf \
        && setcmdline
fi

info "Using kernel command line parameters:" "$(getcmdline)"

getargbool 0 rd.udev.log_level=info -d rd.udev.log-priority=info \
    && echo 'udev_log=info' >> /etc/udev/udev.conf
getargbool 0 rd.udev.log_level=debug -d rd.udev.log-priority=debug \
    && echo 'udev_log=debug' >> /etc/udev/udev.conf

source_conf /etc/conf.d

# Get the "root=" parameter from the kernel command line, but differentiate
# between the case where it was set to the empty string and the case where it
# wasn't specified at all.
if ! root="$(getarg root=)"; then
    root_unset='UNSET'
fi

rflags="$(getarg rootflags=)"
getargbool 0 ro && rflags="${rflags},ro"
getargbool 0 rw && rflags="${rflags},rw"
rflags="${rflags#,}"

fstype="$(getarg rootfstype=)"
if [ -z "$fstype" ]; then
    fstype="auto"
fi

export root
export rflags
export fstype

make_trace_mem "hook cmdline" '1+:mem' '1+:iomem' '3+:slab'
# run scriptlets to parse the command line before pre-udev
getargs 'rd.break=cmdline' && emergency_shell -n cmdline "Break before cmdline"
source_hook cmdline

[ -f /lib/dracut/parse-resume.sh ] && . /lib/dracut/parse-resume.sh

case "${root#block:}${root_unset}" in
    LABEL=* | UUID=* | PARTUUID=* | PARTLABEL=*)
        root="block:$(label_uuid_to_dev "${root#block:}")"
        rootok=1
        ;;
    /dev/*)
        root="block:${root#block:}"
        rootok=1
        ;;
    UNSET | gpt-auto | tmpfs)
        # systemd's gpt-auto-generator/fstab-generator handles this case.
        rootok=1
        ;;
esac

[ -z "${root}${root_unset}" ] && die "Empty root= argument"
[ -z "$rootok" ] && die "Don't know how to handle 'root=$root'"

export root rflags fstype netroot NEWROOT

export -p > /dracut-state.sh

exit 0
