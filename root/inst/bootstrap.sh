#!/bin/sh

echo "Bootstrapping $*"

script="$1"
shift

mkdir /t
mount -osize=256M,nr_inodes=20000 -t tmpfs /dev/shm /t/
mkdir /t/lib /t/bin /t/inst
cp -L /lib/* /t/lib/
cp -L /bin/* /sbin/* /usr/bin/* /usr/sbin/* /t/bin/
cp -L /inst/* /t/inst/
# Not recreating all links in /inst to NOT restart services while in bootstrap mode
rm -f /inst/*
for f in /lib/* /inst/dcounter /inst/bash.sh ; do ln -snf /t/$f /$f 2>/dev/null ; done
for f in /bin/* /sbin/* /usr/bin/* /usr/sbin/* ; do ln -snf /t/bin/${f##*/} /$f; done
kill -QUIT -1
sleep 2
umount /read-write || mount -oremount,ro /read-write || umount -f /read-write || umount -l /read-write

exec /t/$script "$@"

