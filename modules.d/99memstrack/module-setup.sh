#!/bin/bash

check() {
    require_binaries nohup memstrack || return 1
    return 0
}

depends() {
    echo systemd
    return 0
}

install() {
    inst_multiple nohup
    inst "/bin/memstrack" "/bin/memstrack"

    inst "$moddir/memstrack-start.sh" "/bin/memstrack-start"
    inst_hook cleanup 99 "$moddir/memstrack-report.sh"

    inst "$moddir/memstrack.service" "$systemdsystemunitdir/memstrack.service"

    $SYSTEMCTL -q --root "$initdir" add-wants initrd.target memstrack.service
}
