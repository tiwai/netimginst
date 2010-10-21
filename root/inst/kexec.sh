#!/bin/sh

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

kexec -e

echo "kexec failed... Sleeping 60 seconds, press Ctrl-C to continue"
sleep 60

do_reboot

