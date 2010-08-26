#!/bin/sh

url="$1"
owndisk="$2"

# Reboot hard
do_reboot() {
    cd
    umount /mnt/iso
    umount /mnt/net

    sleep 3
    trap "" EXIT

    sync
    #mount -oremount,ro /
    echo u >/proc/sysrq-trigger
    echo s >/proc/sysrq-trigger
    sync
    sleep 1
    /sbin/reboot -f
    sleep 10000
}

sizeM=`curl -I -s "$url" | sed -e '/^Content-Length:/!d; s/.* //;s/\s//g'`
test "$sizeM" -gt 0 && sizeM=$(($sizeM / 1048576))

progress=""
test -x /inst/dcounter -a "$sizeM" -gt 0 && progress='/inst/dcounter -s $sizeM | '

eval "curl -s \"$url\" | $progress dd of=$owndisk bs=1M"

if [ $? != 0 ] ; then
    echo ""
    echo "FAILED !"
    echo ""
    sleep 5
fi
sync

echo "Done. Rebooting"

do_reboot

