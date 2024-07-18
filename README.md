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

Licensed under the GPLv2
