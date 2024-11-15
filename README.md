dracut-core
====

Started on top of [openSUSE dracut](https://github.com/openSUSE/dracut/tree/SUSE/059):

- Removed non-`systemd` code and other unnecessary code.
- Removed the ability to create UEFI executables (it's not complete, and
[ukify](https://www.freedesktop.org/software/systemd/man/latest/ukify.html) is
way better for that purpose).
- Removed the extra `dracut-cpio` Rust binary.
- Removed the messy `--sysroot` option.
- Removed some old modules and others rarely used.
- Left only `network-legacy` and `network-manager` as the available network handlers.
- Reworked RPM packaging, splitting functionality into subpackages.
- Added an `-split-kernel` option (see https://cfp.all-systems-go.io/all-systems-go-2024/talk/9T8LTT/)
- Plus some other performance improvements...

OBS devel repo for openSUSE Tumbleweed:

```
$ zypper ar https://download.opensuse.org/repositories/home:/afeijoo:/devel/openSUSE_Tumbleweed/?ssl_verify=no dracut-core-repo
$ zypper ref dracut-core-repo
$ zypper in dracut-core
```

- for Slowroll: `s/Tumbleweed/Slowroll/`
- for Leap 15.6: `s/openSUSE_Tumbleweed/15.6/`
- for Leap 15.5: `s/openSUSE_Tumbleweed/15.5/`

OBS devel repo for Fedora Rawhide:

```
$ dnf config-manager --add-repo https://download.opensuse.org/repositories/home:/afeijoo:/devel:/fedora/Fedora_Rawhide/home:afeijoo:devel:fedora.repo
$ dnf install dracut-core --repo home_afeijoo_devel_fedora --best --allowerasing
```

- for Fedora 40: `s/Fedora_Rawhide/Fedora_40/`

Licensed under the GPLv2
