#!/bin/sh

# Prepare everything for Ludwig Nussel's setupgrubfornfsinstall
disk="$1"

# Reboot hard
do_reboot() {
    cd
    test -e /boot.off && rm /boot && mv /boot{.off,}
    umount /mnt/disk 2>/dev/null

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


if [ ! -d /mnt/disk ] ; then
# If /mnt/disk doesn't exist yet, the disk isn't partitioned + grub setup yet

  device=ask
  while [ ! -e "$device" ] ; do
    cat >/tmp/msg <<- EOACCEPT
	Deleting all partitions on drive $disk !
	
	This will destroy all data! Make sure the right disk is used!
	
	EOACCEPT
    fdisk -l | grep '^Disk /dev/sd' >>/tmp/msg

    dialog --backtitle "$title" --no-shadow --no-collapse --cr-wrap --ok-label OK --cancel-label Back --extra-button --extra-label "Change Drive" --yesno "`cat /tmp/msg`" 0 0
    case $? in
        0)
            device="/dev/$disk"
            ;;
        3)
            echo -n "Please enter drive: "
            read disk
            test "x$disk" = x && exit 1
            ;;
        *)
            exit 0
            ;;
    esac
  done
  part="${device}1"

  trap "cd /; umount -f /mnt/disk 2>/dev/null; rmdir /mnt/disk 2>/dev/null; test -e /boot.off && rm /boot && mv /boot{.off,}" EXIT

  echo -e "unit: sectors\n${part}: start=63,size=100000,Id=83,bootable" | sfdisk --force $device || exit 1
  # This is ... racy
  sleep 2
  mke2fs $part || exit 1

  mkdir /mnt/disk
  mount $part /mnt/disk
  mkdir /mnt/disk/boot
  cp -a /boot/grub /mnt/disk/boot/
  cp /boot/message /mnt/disk/boot/
  rm /mnt/disk/boot/grub/device.map /tmp/device.map

  echo "quit" | grub --device-map /tmp/device.map --batch
  grubdev="`sed -e "\\@/dev/sda@"'!d;s/[ 	].*//' </tmp/device.map`"
  test "x$grubdev" = x && exit 1
  grubpart="`echo $grubdev | sed -e 's/)/,0)/'`"
  cat >/mnt/disk/boot/grub/menu.lst <<- EOMENU
	timeout 10
	gfxmenu $grubpart/boot/message
	root $grubpart
	EOMENU

  if [ ! -e /boot.off ] ; then
    mv /boot{,.off}
    test -e /boot && exit 1
    ln -snf /mnt/disk/boot /boot
  fi

  echo -e "root $grubpart\nsetup --force-lba $grubdev $grubpart\nquit" | grub --batch || exit 1
  echo -e "grub:  root $grubpart ; setup --force-lba $grubdev $grubpart"

  trap "test -e /boot.off && rm /boot && mv /boot{.off,}" EXIT

else
# If /mnt/disk exists, determine the disk that is mounted there

  device="`df /mnt/disk | sed -e '/^\/dev/!d;s/^\/dev\/\([^ ]*\) .*/\1/'`"
  rootdev="`df / | sed -e '/^\/dev/!d;s/^\/dev\/\([^ ]*\) .*/\1/'`"
  if [ "x$device" = x -o "$device" = "$rootdev" ] ; then
    echo "Illegal or usb device $device - not continuing"
    sleep 2
    exit 1
  fi

fi

if [ ! -e /boot.off ] ; then
  trap "test -e /boot.off && rm /boot && mv /boot{.off,}" EXIT
  mv /boot{,.off}
  test -e /boot && exit 1
  ln -snf /mnt/disk/boot /boot
fi

sleep 2
/inst/setupgrubfornfsinstall && do_reboot

rm /boot
mv /boot{.off,}

trap "" EXIT

exit 1

