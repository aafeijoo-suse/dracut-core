#
# spec file for package dracut-core
#
# Copyright (c) 2024 SUSE LLC
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via https://bugs.opensuse.org/
#

%define dracutlibdir %{_prefix}/lib/dracut
%define dracutversion 1000

Name:           dracut-core
Version:        0.0.1~devel
Release:        0
Summary:        Event driven initramfs infrastructure (core)
License:        GPLv2+ and LGPLv2+ and GPLv2
Group:          System/Base
URL:            https://github.com/aafeijoo-suse/dracut-core
Source0:        dracut-core-%{version}.tar.xz
Source1:        dracut-core-rpmlintrc
BuildRequires:  asciidoc
BuildRequires:  bash
BuildRequires:  docbook-dtds
BuildRequires:  docbook-style-xsl
BuildRequires:  glibc-all-langpacks
BuildRequires:  libxslt
BuildRequires:  openjpeg2
BuildRequires:  pkgconfig(libkmod)
BuildRequires:  pkgconfig(systemd) >= 249
Requires:       bash >= 4
Requires:       coreutils
Requires(post): coreutils
Requires:       cpio
Requires:       elfutils
Requires:       file
Requires:       filesystem
Requires:       findutils
Requires:       gawk
Requires:       grep
Requires:       gzip
Requires:       hardlink
Requires:       kmod
Recommends:     pigz
Requires:       procps-ng
Requires:       sed
Requires:       systemd >= 249
Requires:       systemd-udev >= 249
Recommends:     (tpm2.0-tools if tpm2-tss)
Requires:       util-linux >= 2.21
Requires:       xz
Provides:       dracut = %{dracutversion}
Conflicts:      dracut

%description
dracut contains tools to create a bootable initramfs for Linux kernels >= 2.6.
dracut contains various modules which are driven by the event-based udev
and systemd. Having root on MD, DM, LVM2, LUKS is supported as well as
NFS, iSCSI, NBD, FCoE.

%ifnarch %ix86
%package fips
Summary:        dracut modules to build a dracut initramfs with an integrity check
Group:          System/Base
Requires:       %{name} = %{version}-%{release}
Requires:       libkcapi-hmaccalc
Provides:       dracut-fips = %{dracutversion}

%description fips
This package requires everything which is needed to build an
initramfs with dracut, which does an integrity check of the kernel
and its cryptography during startup.
%endif

%ifnarch %ix86
%package ima
Summary:        dracut modules to build a dracut initramfs with IMA
Group:          System/Base
Requires:       %{name} = %{version}-%{release}
Requires:       evmctl
Requires:       keyutils
Provides:       dracut-ima = %{dracutversion}

%description ima
This package requires everything which is needed to build an
initramfs (using dracut) which tries to load an IMA policy during startup.
%endif

%package network
Summary:        dracut modules to build a dracut initramfs with network support
Group:          System/Base
Requires:       %{name} = %{version}-%{release}
Requires:       iputils
Requires:       iproute
Requires:       NetworkManager
# NetworkManager >= 1.20 has an internal DHCP client
Requires:       (dhcp-client if NetworkManager < 1.20)
Requires:       (jq if nvme-cli)
Provides:       dracut-network = %{dracutversion}

%description network
This package requires everything which is needed to build an initramfs with
dracut with network support.

%package live
Summary:        dracut modules to build a dracut initramfs with live image capabilities
Group:          System/Base
Requires:       %{name} = %{version}-%{release}
Requires:       %{name}-network = %{version}-%{release}
Requires:       curl
Requires:       device-mapper
Requires:       fuse
Requires:       ntfs-3g
Requires:       parted
Requires:       tar
Provides:       dracut-live = %{dracutversion}

%description live
This package requires everything which is needed to build an initramfs with
dracut with live image capabilities.

%prep
%autosetup

%build
%configure \
  --systemdsystemunitdir=%{_unitdir} \
  --bashcompletiondir=%{_datadir}/bash-completion/completions \
  --libdir=%{_prefix}/lib \
  --initrd-prefix "initramfs-" \
  --initrd-suffix ".img"
%make_build all CFLAGS="%{optflags}" %{?_smp_mflags}

%install
%make_install

echo -e "#!/bin/bash\nDRACUT_VERSION=%{version}-%{release}" > %{buildroot}%{dracutlibdir}/dracut-version.sh

# remove SUSE specific modules
rm -rf %{buildroot}%{dracutlibdir}/modules.d/99suse
rm -rf %{buildroot}%{dracutlibdir}/modules.d/99suse-initrd

# remove architecture specific modules
%ifnarch s390 s390x
rm -rf %{buildroot}%{dracutlibdir}/modules.d/81cio_ignore
rm -rf %{buildroot}%{dracutlibdir}/modules.d/91zipl
rm -rf %{buildroot}%{dracutlibdir}/modules.d/95dasd_mod
rm -rf %{buildroot}%{dracutlibdir}/modules.d/95dcssblk
%else
rm -rf %{buildroot}%{dracutlibdir}/modules.d/00warpclock
%endif

mkdir -p %{buildroot}/boot/dracut
mkdir -p %{buildroot}%{_localstatedir}/lib/dracut/overlay
mkdir -p %{buildroot}%{_localstatedir}/log
touch %{buildroot}%{_localstatedir}/log/dracut.log

install -D -m 0644 dracut.conf.d/fedora.conf.example %{buildroot}%{dracutlibdir}/dracut.conf.d/01-dist.conf
install -m 0644 dracut.conf.d/debug.conf.example %{buildroot}%{_sysconfdir}/dracut.conf.d/99-debug.conf
%ifnarch %ix86
install -m 0644 dracut.conf.d/fips.conf.example %{buildroot}%{_sysconfdir}/dracut.conf.d/40-fips.conf
install -m 0644 dracut.conf.d/ima.conf.example %{buildroot}%{_sysconfdir}/dracut.conf.d/40-ima.conf
%endif
# bsc#915218
%ifarch s390 s390x
install -m 0644 dracut.conf.d/s390x_persistent_policy.conf.example %{buildroot}%{_sysconfdir}/dracut.conf.d/10-persistent_policy.conf
%else
install -m 0644 dracut.conf.d/persistent_policy.conf.example %{buildroot}%{_sysconfdir}/dracut.conf.d/10-persistent_policy.conf
%endif

# create a link to dracut-util to be able to parse kernel command line arguments at generation time
ln -s %{dracutlibdir}/dracut-util %{buildroot}%{dracutlibdir}/dracut-getarg

%ifnarch %ix86
%files fips
%license COPYING
%config %{_sysconfdir}/dracut.conf.d/40-fips.conf
%{dracutlibdir}/modules.d/01fips
%endif

%ifnarch %ix86
%files ima
%license COPYING
%config %{_sysconfdir}/dracut.conf.d/40-ima.conf
%{dracutlibdir}/modules.d/96securityfs
%{dracutlibdir}/modules.d/97masterkey
%{dracutlibdir}/modules.d/98integrity
%endif

%files network
%license COPYING
%{dracutlibdir}/modules.d/35network-legacy
%{dracutlibdir}/modules.d/35network-manager
%{dracutlibdir}/modules.d/40network
%{dracutlibdir}/modules.d/45url-lib
%{dracutlibdir}/modules.d/90kernel-network-modules
%{dracutlibdir}/modules.d/90qemu-net
%{dracutlibdir}/modules.d/95cifs
%{dracutlibdir}/modules.d/95fcoe
%{dracutlibdir}/modules.d/95fcoe-uefi
%{dracutlibdir}/modules.d/95iscsi
%{dracutlibdir}/modules.d/95nbd
%{dracutlibdir}/modules.d/95nfs
%{dracutlibdir}/modules.d/95nvmf
%{dracutlibdir}/modules.d/95ssh-client

%files live
%{dracutlibdir}/modules.d/90dmsquash-live
%{dracutlibdir}/modules.d/90dmsquash-live-autooverlay
%{dracutlibdir}/modules.d/90dmsquash-live-ntfs
%{dracutlibdir}/modules.d/90livenet
%{dracutlibdir}/modules.d/90overlayfs
%{dracutlibdir}/modules.d/99img-lib

%files
%license COPYING
%doc README.md dracut.html
%doc docs/HACKING.md
%{_bindir}/dracut
%{_bindir}/lsinitrd
%dir %{_datadir}/bash-completion
%dir %{_datadir}/bash-completion/completions
%{_datadir}/bash-completion/completions/dracut
%{_datadir}/bash-completion/completions/lsinitrd
%{_datadir}/pkgconfig/dracut.pc

%config(noreplace) %{_sysconfdir}/dracut.conf
%dir %{_sysconfdir}/dracut.conf.d
%dir %{dracutlibdir}/dracut.conf.d
%{dracutlibdir}/dracut.conf.d/01-dist.conf
%config %{_sysconfdir}/dracut.conf.d/99-debug.conf
%config %{_sysconfdir}/dracut.conf.d/10-persistent_policy.conf

%{_mandir}/man8/dracut.8*
%{_mandir}/man1/lsinitrd.1*
%{_mandir}/man7/dracut.kernel.7*
%{_mandir}/man7/dracut.cmdline.7*
%{_mandir}/man7/dracut.bootup.7*
%{_mandir}/man7/dracut.modules.7*
%{_mandir}/man8/dracut-cmdline.service.8*
%{_mandir}/man8/dracut-initqueue.service.8*
%{_mandir}/man8/dracut-pre-pivot.service.8*
%{_mandir}/man8/dracut-pre-trigger.service.8*
%{_mandir}/man8/dracut-pre-udev.service.8*
%{_mandir}/man8/dracut-mount.service.8.*
%{_mandir}/man8/dracut-pre-mount.service.8.*
%{_mandir}/man8/dracut-shutdown.service.8.*
%{_mandir}/man5/dracut.conf.5*

%dir %{dracutlibdir}
%{dracutlibdir}/skipcpio
%{dracutlibdir}/dracut-functions.sh
%{dracutlibdir}/dracut-init.sh
%{dracutlibdir}/dracut-functions
%{dracutlibdir}/dracut-version.sh
%{dracutlibdir}/dracut-logger.sh
%{dracutlibdir}/dracut-initramfs-restore
%{dracutlibdir}/dracut-install
%{dracutlibdir}/dracut-util
%{dracutlibdir}/dracut-getarg

%dir %{dracutlibdir}/modules.d
%{dracutlibdir}/modules.d/00bash
%{dracutlibdir}/modules.d/00systemd
%ifnarch s390 s390x
%{dracutlibdir}/modules.d/00warpclock
%endif
%ifarch %ix86
%exclude %{dracutlibdir}/modules.d/01fips
%endif
%{dracutlibdir}/modules.d/01systemd-ask-password
%{dracutlibdir}/modules.d/01systemd-coredump
%{dracutlibdir}/modules.d/01systemd-creds
%{dracutlibdir}/modules.d/01systemd-integritysetup
%{dracutlibdir}/modules.d/01systemd-journald
%{dracutlibdir}/modules.d/01systemd-ldconfig
%{dracutlibdir}/modules.d/01systemd-modules-load
%{dracutlibdir}/modules.d/01systemd-pcrphase
%{dracutlibdir}/modules.d/01systemd-repart
%{dracutlibdir}/modules.d/01systemd-sysctl
%{dracutlibdir}/modules.d/01systemd-sysext
%{dracutlibdir}/modules.d/01systemd-sysusers
%{dracutlibdir}/modules.d/01systemd-tmpfiles
%{dracutlibdir}/modules.d/01systemd-udevd
%{dracutlibdir}/modules.d/01systemd-veritysetup
%{dracutlibdir}/modules.d/03modsign
%{dracutlibdir}/modules.d/03rescue
%{dracutlibdir}/modules.d/04watchdog
%{dracutlibdir}/modules.d/06dbus-broker
%{dracutlibdir}/modules.d/06dbus-daemon
%{dracutlibdir}/modules.d/06rngd
%{dracutlibdir}/modules.d/09dbus
%{dracutlibdir}/modules.d/10i18n
%{dracutlibdir}/modules.d/30convertfs
%{dracutlibdir}/modules.d/50drm
%{dracutlibdir}/modules.d/50plymouth
%{dracutlibdir}/modules.d/62bluetooth
%{dracutlibdir}/modules.d/80lvmmerge
%{dracutlibdir}/modules.d/80lvmthinpool-monitor
%ifarch s390 s390x
%{dracutlibdir}/modules.d/81cio_ignore
%endif
%{dracutlibdir}/modules.d/90btrfs
%{dracutlibdir}/modules.d/90crypt
%{dracutlibdir}/modules.d/90dm
%{dracutlibdir}/modules.d/90dmraid
%{dracutlibdir}/modules.d/90kernel-modules-extra
%{dracutlibdir}/modules.d/90kernel-modules
%{dracutlibdir}/modules.d/90lvm
%{dracutlibdir}/modules.d/90mdraid
%{dracutlibdir}/modules.d/90multipath
%{dracutlibdir}/modules.d/90nvdimm
%{dracutlibdir}/modules.d/90qemu
%{dracutlibdir}/modules.d/91crypt-gpg
%{dracutlibdir}/modules.d/91crypt-loop
%{dracutlibdir}/modules.d/91fido2
%{dracutlibdir}/modules.d/91pcsc
%{dracutlibdir}/modules.d/91pkcs11
%{dracutlibdir}/modules.d/91tpm2-tss
%ifarch s390 s390x
%{dracutlibdir}/modules.d/91zipl
%endif
%ifarch s390 s390x
%{dracutlibdir}/modules.d/95dasd_mod
%{dracutlibdir}/modules.d/95dcssblk
%endif
%{dracutlibdir}/modules.d/95debug
%{dracutlibdir}/modules.d/95lunmask
%{dracutlibdir}/modules.d/95resume
%{dracutlibdir}/modules.d/95rootfs-block
%{dracutlibdir}/modules.d/95terminfo
%{dracutlibdir}/modules.d/95udev-rules
%{dracutlibdir}/modules.d/95virtfs
%{dracutlibdir}/modules.d/95virtiofs
%{dracutlibdir}/modules.d/97biosdevname
%ifarch %ix86
%exclude %{dracutlibdir}/modules.d/96securityfs
%exclude %{dracutlibdir}/modules.d/97masterkey
%exclude %{dracutlibdir}/modules.d/98integrity
%endif
%{dracutlibdir}/modules.d/98dracut-systemd
%{dracutlibdir}/modules.d/98ecryptfs
%{dracutlibdir}/modules.d/98selinux
%{dracutlibdir}/modules.d/99base
%{dracutlibdir}/modules.d/99fs-lib
%{dracutlibdir}/modules.d/99memstrack
%{dracutlibdir}/modules.d/99shutdown
%{dracutlibdir}/modules.d/99squash
%{dracutlibdir}/modules.d/99uefi-lib
%attr(0640,root,root) %ghost %config(missingok,noreplace) %{_localstatedir}/log/dracut.log
%dir %{_unitdir}/initrd.target.wants
%dir %{_unitdir}/sysinit.target.wants
%{_unitdir}/*.service
%{_unitdir}/*/*.service

%changelog
