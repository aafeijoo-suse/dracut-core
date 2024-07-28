dracutla
====

Like the vampire, but instead of blood, it feeds on
[dracut](https://github.com/dracutdevs/dracut) code (it especially finds
non-systemd code appetizing).

OBS devel repo for openSUSE Tumbleweed:

```
$ zypper ar https://download.opensuse.org/repositories/home:/afeijoo:/devel/openSUSE_Tumbleweed/?ssl_verify=no dracutla
$ zypper ref dracutla
$ zypper in --from dracutla dracut
```

- for Slowroll: `s/Tumbleweed/Slowroll`
- for Leap 15.6: `s/openSUSE_Tumbleweed/15.6`
- for Leap 15.5: `s/openSUSE_Tumbleweed/15.5`

OBS devel repo for Fedora Rawhide:

```
$ dnf config-manager --add-repo https://download.opensuse.org/repositories/home:/afeijoo:/devel:/fedora/Fedora_Rawhide/home:afeijoo:devel:fedora.repo
$ dnf install dracut --repo home_afeijoo_devel_fedora --best --allowerasing
```

- for Fedora 40: `s/Fedora_Rawhide/Fedora_40/`

Licensed under the GPLv2
