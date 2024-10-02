dracut-core
====

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
