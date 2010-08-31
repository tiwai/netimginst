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
test -x /inst/dia_gauge -a "$sizeM" -gt 0 && progress='(/inst/dia_gauge $sizeM "Dumping update to $owndisk - %.1f MB/s" | dialog --backtitle "Updating Network Image Installer" --no-shadow --stdout --gauge "" 0 75 ) 2>&1 | '

eval "curl -s \"$url\" | $progress dd of=$owndisk oflag=dsync bs=1M 2>/dev/null"

if [ $? != 0 ] ; then
    echo ""
    echo "FAILED !"
    echo ""
    sleep 5
fi
sync

echo "Done. Rebooting"

do_reboot

