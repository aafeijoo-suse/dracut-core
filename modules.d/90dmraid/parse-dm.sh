#!/bin/sh

if ! getargbool 1 rd.dm || getarg "rd.dm=0"; then
    info "rd.dm=0: removing DM RAID activation"
    udevproperty rd_NO_DM=1
fi

if ! command -v mdadm > /dev/null \
    || ! getargbool 1 rd.md.imsm \
    || ! getargbool 1 rd.md; then
    info "rd.md.imsm=0: no MD RAID for imsm/isw raids"
    udevproperty rd_NO_MDIMSM=1
fi

if ! command -v mdadm > /dev/null \
    || ! getargbool 1 rd.md.ddf \
    || ! getargbool 1 rd.md; then
    info "rd.md.ddf=0: no MD RAID for SNIA ddf raids"
    udevproperty rd_NO_MDDDF=1
fi

DM_RAIDS=$(getargs rd.dm.uuid)

if [ -z "$DM_RAIDS" ] && ! getargbool 0 rd.auto; then
    udevproperty rd_NO_DM=1
fi
