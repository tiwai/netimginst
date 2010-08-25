#!/bin/sh
if [ "x$2" = x ] ; then
  echo 1>&2 "Usage: $0 <root> [<command> [args]]"
  exit 1
fi
r="$1"
shift

mount --bind /dev      $r/dev
mount --bind /proc     $r/proc
mount --bind /sys      $r/sys
mount --bind /dev/pts  $r/dev/pts

chroot "$r" "$@"

umount $r/dev/pts
umount $r/sys
umount $r/proc
umount $r/dev

