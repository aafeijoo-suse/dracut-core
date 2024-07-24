dracut-mini
====

Like [dracut](https://github.com/dracutdevs/dracut), but minimal and only for
systemd systems.

OBS devel repo for openSUSE Tumbleweed:

```
$ zypper ar https://download.opensuse.org/repositories/home:/afeijoo:/devel/openSUSE_Tumbleweed/?ssl_verify=no dracut-mini
$ zypper ref dracut-mini
$ zypper in --from dracut-mini dracut
```

OBS devel repo for Fedora Rawhide:

```
$ dnf config-manager --add-repo https://download.opensuse.org/repositories/home:/afeijoo:/devel:/fedora/Fedora_Rawhide/home:afeijoo:devel:fedora.repo
$ dnf install dracut --repo home_afeijoo_devel_fedora --best --allowerasing
```

(for Fedora 40: s/Fedora_Rawhide/Fedora_40/)

Licensed under the GPLv2
