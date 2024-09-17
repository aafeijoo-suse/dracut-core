#!/bin/bash

. /lib/dracut-lib.sh
type crypttab_contains > /dev/null 2>&1 || . /lib/dracut-crypt-lib.sh

dev=$1
luks=$2

crypttab_contains "$luks" "$dev" && exit 0

allowdiscards="-"

# parse for allow-discards
if discarduuids=$(getargs "rd.luks.allow-discards"); then
    discarduuids=$(str_replace "$discarduuids" 'luks-' '')
    if strstr " $discarduuids " " ${luks##luks-}"; then
        allowdiscards="discard"
    fi
elif getargbool 0 rd.luks.allow-discards; then
    allowdiscards="discard"
fi

echo "$luks $dev - timeout=0,$allowdiscards" >> /etc/crypttab

systemctl daemon-reload
systemctl start cryptsetup.target

exit 0
