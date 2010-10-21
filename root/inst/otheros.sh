#!/bin/sh

# Prepare everything for Ludwig Nussel's setupgrubfornfsinstall

cmdfile=/tmp/bootstrap.cmd
rm -f $cmdfile

test -d /mnt/boot/grub ; res=$?
mkdir -p /mnt/boot
if [ ! -d /mnt/boot ] ; then
    echo "Cannot create /mnt/boot"
    exit 1
fi
test $res = 0 || cp -a /boot/grub /mnt/boot/

mount --bind /mnt/boot /boot || exit 1
/inst/setupgrubfornfsinstall ; res=$?

test $res = 0 && eval "/bin/sh -x /boot/*/kexec"
umount /boot
test $res = 0  && echo >$cmdfile "exec /inst/bootstrap.sh /inst/kexec.sh"

exit $res

