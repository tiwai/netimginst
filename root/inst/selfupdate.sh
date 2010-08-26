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

progress=""
test -x /inst/dcounter -a "$sizeM" -gt 0 && progress='((/inst/dcounter -s $sizeM -l "" 3>&1 1>&2 2>&3 3>&- | perl -e '\''$|=1; while (<>) { /(\d+)/; print "$1\n" }'\'' | dialog --backtitle "$title" --stdout --gauge "Dumping $image to $disk via $net" 0 75 ) 2>&1) | '

eval "curl -s \"$url\" | $progress dd of=/dev/$owndisk bs=1M" || exit 1

echo "Done. Rebooting"

do_reboot

