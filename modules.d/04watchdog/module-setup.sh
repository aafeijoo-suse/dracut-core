#!/bin/bash

# called by dracut
check() {
    return 255
}

# called by dracut
depends() {
    echo watchdog-modules
    return 0
}

# called by dracut
install() {
    inst_hook emergency 02 "$moddir/watchdog-stop.sh"
    inst_multiple -o wdctl
}
