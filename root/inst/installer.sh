#!/bin/sh

#
# Config
#
server=ask
dir=ask
image=ask
# Known names for image: full file name, version, "latest", "ask" (actually, anyting not found)

. /inst/config

# Get args from boot line and addon commandline in /
test -e /cmdline && eval `tr ' ' '\n' </cmdline | grep '^server=\|dir=\|image='`
eval `tr ' ' '\n' </proc/cmdline | grep '^server=\|dir=\|image='`


# On exit cleanup
trap "cd /; umount 2>/dev/null /mnt/disk; umount 2>/dev/null /mnt/image; umount 2>/dev/null /mnt/iso; umount 2>/dev/null /mnt/net;" EXIT
set +H

# Reboot hard
do_reboot() {
    cd
    umount /mnt/disk
    umount /mnt/image
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

# Restart installer
do_restart() {
    cd /
    umount 2>/dev/null /mnt/disk
    umount 2>/dev/null /mnt/image
    umount 2>/dev/null /mnt/iso
    umount 2>/dev/null /mnt/net
    trap "" EXIT
    exec $0 $@
}


#
# Init
#

mkdir -p /mnt/net /mnt/iso /mnt/image /mnt/disk
title="`cat /etc/ImageVersion`"

# Get supposed harddisk
# Find largest disk
disk="`fdisk -lu | perl -e 'while (<>) { if (/^Disk \/dev\/(sd.): .*, (\d+) bytes/ && $2 > $s) { $d=$1; $s=$2 }} print "$d"'`"
if [ ! -e "/dev/$disk" ] ; then
    echo "Cannot find disk:"
    fdisk -lu
fi


#
# Get network configuration
#

netdev="`cat /tmp/net_device 2>/dev/null`"

# Check if network is available
if [ "x$netdev" = x ] ; then
    dialog --backtitle "$title" --no-shadow --no-collapse --cr-wrap --ok-label "Redetect Network" --cancel-label "Reboot" --extra-button --extra-label "Continue" --yesno "Cannot connect to any network.\nRetry, reboot, or continue after fixing manually." 8 70
    case $? in
    0)  # Redetect
	exit 1
	;;
    3)  # Continue
	;;
    *)  # Reboot
	do_reboot
	;;
    esac
fi
title="$title  -  Host: `hostname`"

# Get wire(less) speed
netspeed="`iwconfig $netdev 2>&1 | sed '/Bit Rate/!d;s/.*Bit Rate= *\([0-9]*\) *Mb.*/\1/'`"
if [ "x$netspeed" = x ] ; then
    netspeed="`ethtool $netdev 2>&1 | sed '/Speed:/!d;s/.*Speed: *\([0-9]*\) *Mb.*/\1/'`"
fi
net="${netdev:-[no net]} (${netspeed}Mb/s)"


#
# Find compressed image
#

while ! mount -o ro,nolock,tcp $server /mnt/net ; do
    test "x$server" = xask || sleep 2
    dialog 2>/tmp/selection --backtitle "$title" --no-shadow --cancel-label "Redetect Network" --extra-label "" --inputmenu "Please select server:directory and subdirectory via $net" 0 75 15 "${selection[@]}"
    read n n2 server dir </tmp/selection
    case "$n" in
    "RENAMED")
	;;
    "")
	exit 1
	;;
    *)
	script=${sel_script[$(($n-1))]}
	if [ "x$script" != x -a "x$script" != xx ] ; then
	    trap "" EXIT
	    $script "$disk" && exit 0
	    (echo "Sleeping 10 seconds - Press Ctrl-C to continue"; sleep 10)
	    do_restart
	fi
	server=${sel_server[$(($n-1))]}
	dir=${sel_subdir[$(($n-1))]}
	;;
    esac
done

while ! cd /mnt/net/$dir ; do
    test "x$dir" = xask || echo "Cannot cd to $dir"
    echo -n "Please enter subdirectory ('.' for current, or press enter to leave): "
    read dir
    test "x$dir" = x && exit 1
done

#vers="`/bin/ls -U | sed -e '/\.iso$/!d;s/.*-\([0-9.]\+\).iso/\1/' | sort -rn `"
vers="`/bin/ls -U | perl -e 'while (<>) { chomp; s/.*-//; s/\.iso$// || next; $n=$_; s/\b(\d+)\b/"0"x(8-length($1)).$1/ge; $v{$_}=$n; } for $k (sort {$b cmp $a} keys %v) { print "$v{$k}\n" }'`"

echo "Available image versions on $server"
echo ""
echo "$vers" | perl -ne 'chomp; printf "%-18s  ", $_; print "\n" if ++$i % 4 == 0;'
echo ""
echo ""
echo ""

test "x$image" = "xlatest" && image="`echo "$vers" | tail -1`"

iso="`echo *-$image.iso`"
while [ ! -e "$iso" ] ; do
    test "x$image" = xask || echo "Cannot find selected image $image"
    test "x$image" = xask || sleep 2
    unset args
    i=0
    for f in $vers ; do
	args[$i]=$f
	i=$(($i+1))
	args[$i]="`echo *-$f.iso`"
	i=$(($i+1))
    done
    dialog 2>/tmp/selection --backtitle "$title" --no-shadow --cancel-label "Back" --menu "Please select image" 0 0 0 "${args[@]}"
    image="`cat /tmp/selection`"
    test "x$image" = x && do_restart
    iso="`echo *-$image.iso`"
done

if mount -o loop,ro -t udf "$iso" /mnt/iso ; then :; else
    echo "mounting $iso on /mnt/iso failed"
    sleep 2
    exit 1
fi

d="/mnt/iso"
file="`echo $d/*.squashfs`"
if [ -e "$file" ] ; then
    if mount -o loop,ro "$file" /mnt/image ; then :; else
	echo "mounting $file on /mnt/image failed"
	sleep 2
	exit 1
    fi
    d="/mnt/image"
fi

file="`echo $d/*.bz2`"
test -e "$file" || file="`echo $d/*.gz`"
test -e "$file" || file="`echo $d/*.raw`"

if [ ! -e "$file" ] ; then
    /bin/ls -al $d
    echo "Cannot find compressed image in iso - exiting"
    sleep 2
    exit 1
fi

md5="$file.md5"
test -e "$file" || file="${file%.*}.md5"
if [ -e "$md5" ] ; then
    read sum1 blocks blocksize remain <"$md5"
    size=$(($blocks * $blocksize))
else
    size=`stat -c %s "$file"`
fi
sizeM=$(($size / 1048576))
echo ""
echo ""

# Verify with user

device=ask
while [ ! -e "$device" ] ; do
    cat >/tmp/msg <<- EOACCEPT
	Ready to dump image

	    $server/$dir/
	    $iso

	via $net on drive $disk.

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
	    do_restart
	    ;;
    esac
done

# Dump on disk

case "$file" in
*.bz2)	expand="bunzip2"	;;
*.gz)	expand="gunzip"		;;
*.raw)	expand="cat"		;;
esac
progress=""
test -x /inst/dcounter -a "$sizeM" -gt 0 && progress='((/inst/dcounter -s $sizeM -l "" 3>&1 1>&2 2>&3 3>&- | perl -e '\''$|=1; while (<>) { /(\d+)/; print "$1\n" }'\'' | dialog --backtitle "$title" --no-shadow --stdout --gauge "$proginfo" 0 75 ) 2>&1) | '
test -x /inst/dia_gauge -a "$sizeM" -gt 0 && progress='(/inst/dia_gauge $sizeM "$proginfo - %.1f MB/s" | dialog --backtitle "$title" --no-shadow --stdout --gauge "$proginfo" 0 75 ) 2>&1 | '

proginfo="Dumping $image to $disk via $net"
eval "$expand < \"$file\" | $progress dd of=/dev/$disk conv=fdatasync bs=1M 2>/dev/null" || exit 1

umount 2>/dev/null /mnt/image
umount 2>/dev/null /mnt/iso

# if recovery tarball available and not on disk, mount disk and copy
# Only do this if recovery tarball is NEWER than the iso image.
if [ -e "${iso%.iso}.recovery.tar.gz" -a "${iso%.iso}.recovery.tar.gz" -nt "$iso" ] ; then
    sizeM=$(($(stat -c %s "${iso%.iso}.recovery.tar.gz") / 1048576))
    echo "Detecting root partition..."
    /sbin/blockdev --rereadpt /dev/$disk
    /sbin/udevadm trigger
    /sbin/udevadm settle
    sleep 1
    vgchange -ay
    sleep 1
    part=""
    for p in /dev/${disk}* /dev/dm-* ; do
	echo "Trying $p..."
	if mount $p /mnt/disk 2>/dev/null; then
	    if [ -e /mnt/disk/etc/ImageVersion -a ! -e /mnt/disk/recovery.tar.gz ] ; then
		part=$p
	    fi
	    umount /mnt/disk
	fi
    done
    echo "Result: $part"
    if [ "x$part" != x ] ; then
	if mount $part /mnt/disk ; then
	    proginfo="Dumping recovery tarball to $part via $net"
	    eval "dd if=\"${iso%.iso}.recovery.tar.gz\" bs=1M 2>/dev/null | $progress dd of=/mnt/disk/recovery.tar.gz conv=fdatasync bs=1M 2>/dev/null" || exit 1
	    umount /mnt/disk
	fi
    fi
fi

# Done

echo "Done. Rebooting"

do_reboot


