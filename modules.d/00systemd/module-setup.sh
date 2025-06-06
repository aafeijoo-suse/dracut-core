#!/bin/bash
# This file is part of dracut.
# SPDX-License-Identifier: GPL-2.0-or-later

# Prerequisite check(s) for module.
check() {
    [[ $mount_needs ]] && return 1
    # If the binary(s) requirements are not fulfilled the module can't be installed
    require_binaries -s "$systemdutildir"/systemd || return 1
    # Return 0 to always include the module.
    return 0
}

# Module dependency requirements.
depends() {
    # This module has external dependency on other module(s).
    echo systemd-ask-password systemd-journald systemd-sysctl systemd-tmpfiles systemd-udevd
    # Return 0 to include the dependent module(s) in the initramfs.
    return 0
}

# Install kernel module(s).
installkernel() {
    hostonly='' instmods autofs4 dmi-sysfs ipv6
    instmods -s efivarfs
}

# Install the required file(s) and directories for the module in the initramfs.
install() {
    if [[ $prefix == /run/* ]]; then
        dfatal 'systemd does not work with a prefix, which contains "/run"!!'
        exit 1
    fi

    inst_multiple -o \
        "$systemdutildir"/system.conf \
        "$systemdutildir"/system.conf.d/*.conf \
        "$systemdutildir"/system-generators/systemd-debug-generator \
        "$systemdutildir"/system-generators/systemd-fstab-generator \
        "$systemdutildir"/system-generators/systemd-gpt-auto-generator \
        "$systemdutildir"/systemd \
        "$systemdutildir"/systemd-cgroups-agent \
        "$systemdutildir"/systemd-coredump \
        "$systemdutildir"/systemd-executor \
        "$systemdutildir"/systemd-fsck \
        "$systemdutildir"/systemd-reply-password \
        "$systemdutildir"/systemd-shutdown \
        "$systemdutildir"/systemd-sysroot-fstab-check \
        "$systemdutildir"/systemd-validatefs \
        "$systemdutildir"/systemd-vconsole-setup \
        "$systemdutildir"/systemd-volatile-root \
        "$systemdsystemunitdir"/-.slice \
        "$systemdsystemunitdir"/basic.target \
        "$systemdsystemunitdir"/debug-shell.service \
        "$systemdsystemunitdir"/cryptsetup.target \
        "$systemdsystemunitdir"/cryptsetup-pre.target \
        "$systemdsystemunitdir"/ctrl-alt-del.target \
        "$systemdsystemunitdir"/emergency.target \
        "$systemdsystemunitdir"/final.target \
        "$systemdsystemunitdir"/halt.target \
        "$systemdsystemunitdir"/kexec.target \
        "$systemdsystemunitdir"/kmod-static-nodes.service \
        "$systemdsystemunitdir"/local-fs.target \
        "$systemdsystemunitdir"/local-fs-pre.target \
        "$systemdsystemunitdir"/initrd.target \
        "$systemdsystemunitdir"/initrd-cleanup.service \
        "$systemdsystemunitdir"/initrd-fs.target \
        "$systemdsystemunitdir"/initrd-parse-etc.service \
        "$systemdsystemunitdir"/initrd-root-device.target \
        "$systemdsystemunitdir"/initrd-root-fs.target \
        "$systemdsystemunitdir"/initrd-switch-root.service \
        "$systemdsystemunitdir"/initrd-switch-root.target \
        "$systemdsystemunitdir"/initrd-udevadm-cleanup-db.service \
        "$systemdsystemunitdir"/initrd-usr-fs.target \
        "$systemdsystemunitdir"/modprobe@.service \
        "$systemdsystemunitdir"/multi-user.target \
        "$systemdsystemunitdir"/network.target \
        "$systemdsystemunitdir"/network-pre.target \
        "$systemdsystemunitdir"/network-online.target \
        "$systemdsystemunitdir"/nss-lookup.target \
        "$systemdsystemunitdir"/nss-user-lookup.target \
        "$systemdsystemunitdir"/paths.target \
        "$systemdsystemunitdir"/poweroff.target \
        "$systemdsystemunitdir"/reboot.target \
        "$systemdsystemunitdir"/remote-cryptsetup.target \
        "$systemdsystemunitdir"/remote-fs.target \
        "$systemdsystemunitdir"/remote-fs-pre.target \
        "$systemdsystemunitdir"/rescue.target \
        "$systemdsystemunitdir"/rpcbind.target \
        "$systemdsystemunitdir"/shutdown.target \
        "$systemdsystemunitdir"/sigpwr.target \
        "$systemdsystemunitdir"/slices.target \
        "$systemdsystemunitdir"/sockets.target \
        "$systemdsystemunitdir"/swap.target \
        "$systemdsystemunitdir"/sys-kernel-config.mount \
        "$systemdsystemunitdir"/sysinit.target \
        "$systemdsystemunitdir"/sysinit.target.wants/kmod-static-nodes.service \
        "$systemdsystemunitdir"/syslog.socket \
        "$systemdsystemunitdir"/system.slice \
        "$systemdsystemunitdir"/systemd-fsck@.service \
        "$systemdsystemunitdir"/systemd-halt.service \
        "$systemdsystemunitdir"/systemd-kexec.service \
        "$systemdsystemunitdir"/systemd-poweroff.service \
        "$systemdsystemunitdir"/systemd-reboot.service \
        "$systemdsystemunitdir"/systemd-validatefs@.service \
        "$systemdsystemunitdir"/systemd-vconsole-setup.service \
        "$systemdsystemunitdir"/systemd-volatile-root.service \
        "$systemdsystemunitdir"/timers.target \
        "$systemdsystemunitdir"/umount.target \
        systemctl \
        echo swapoff \
        kmod insmod rmmod modprobe modinfo depmod lsmod \
        mount umount reboot poweroff \
        systemd-run systemd-escape \
        systemd-cgls

    if [[ $hostonly ]]; then
        inst_multiple -H -o \
            "$systemdutilconfdir"/system.conf \
            "$systemdutilconfdir"/system.conf.d/*.conf \
            "$systemdsystemconfdir"/modprobe@.service \
            "$systemdsystemconfdir/modprobe@.service.d/*.conf" \
            /etc/hosts \
            /etc/hostname \
            /etc/nsswitch.conf \
            /etc/machine-id \
            /etc/machine-info \
            /etc/vconsole.conf \
            /etc/locale.conf
    fi

    if ! [[ -e "$initdir/etc/machine-id" ]]; then
        : > "$initdir/etc/machine-id"
        chmod 444 "$initdir/etc/machine-id"
    fi

    inst_multiple nologin
    {
        grep '^adm:' /etc/passwd 2> /dev/null
        # we don't use systemd-networkd, but the user is in systemd.conf tmpfiles snippet
        grep '^systemd-network:' /etc/passwd 2> /dev/null
    } >> "$initdir/etc/passwd"

    {
        grep '^wheel:' /etc/group 2> /dev/null
        grep '^adm:' /etc/group 2> /dev/null
        grep '^utmp:' /etc/group 2> /dev/null
        grep '^root:' /etc/group 2> /dev/null
        # we don't use systemd-networkd, but the user is in systemd.conf tmpfiles snippet
        grep '^systemd-network:' /etc/group 2> /dev/null
    } >> "$initdir/etc/group"

    local _systemdbinary="$systemdutildir"/systemd

    if ldd "$_systemdbinary" | grep -qw libasan; then
        local _wrapper="$systemdutildir"/systemd-asan-wrapper
        cat > "$initdir"/"$_wrapper" << EOF
#!/bin/bash
mount -t proc -o nosuid,nodev,noexec proc /proc
exec $_systemdbinary
EOF
        chmod 755 "$initdir"/"$_wrapper"
        _systemdbinary="$_wrapper"
        unset _wrapper
    fi
    ln_r "$_systemdbinary" "/init"
    ln_r "$_systemdbinary" "/sbin/init"

    unset _systemdbinary

    inst_binary true
    ln_r "$(find_binary true)" "/usr/bin/loginctl"
    ln_r "$(find_binary true)" "/bin/loginctl"

    for i in \
        emergency.target \
        rescue.target; do
        [[ -f "$systemdsystemunitdir"/$i ]] || continue
        $SYSTEMCTL -q --root "$initdir" add-wants "$i" systemd-vconsole-setup.service
    done

    mkdir -p "$initdir/etc/systemd"

    $SYSTEMCTL -q --root "$initdir" set-default initrd.target

    # Install library file(s)
    _arch=${DRACUT_ARCH:-$(uname -m)}
    inst_libdir_file \
        {"tls/$_arch/",tls/,"$_arch/",}"libbpf.so*" \
        {"tls/$_arch/",tls/,"$_arch/",}"libgcrypt.so*" \
        {"tls/$_arch/",tls/,"$_arch/",}"libkmod.so*" \
        {"tls/$_arch/",tls/,"$_arch/",}"libnss_*" \
        {"tls/$_arch/",tls/,"$_arch/",}"systemd/libsystemd*.so"

}
