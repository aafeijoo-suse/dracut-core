#!/bin/bash
[ -c /dev/watchdog ] && printf 'V' > /dev/watchdog
