#!/bin/sh

#
# Init
#

# On exit cleanup
trap "cd /; umount 2>/dev/null /mnt/iso; umount 2>/dev/null /mnt/net;" EXIT
set +H

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

# Default args
mkdir -p /mnt/net /mnt/iso
server=ask
dir=ask
image=ask
# Known names for image: full file name, version, "latest", "ask" (actually, anyting not found)
title="`cat /etc/ImageVersion`"

# Known servers
all_servers=(1 "berg:/data_build/   image" 2 "berg:/data/         released-images" 3 "hewson:/data        image")

# Get args from boot line and addon commandline in /
test -e /cmdline && eval `tr ' ' '\n' </cmdline | grep '^server=\|dir=\|image='`
eval `tr ' ' '\n' </proc/cmdline | grep '^server=\|dir=\|image='`

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

/netconf.sh
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

# Get wire(less) speed
netspeed="`iwconfig $netdev 2>&1 | sed '/Bit Rate/!d;s/.*Bit Rate= *\([0-9]*\) *Mb.*/\1/'`"
if [ "x$netspeed" = x ] ; then
    netspeed="`ethtool $netdev 2>&1 | sed '/Speed:/!d;s/.*Speed: *\([0-9]*\) *Mb.*/\1/'`"
fi
net="${netdev:-[no net]} (${netspeed}Mb/s)"


#
# Find compressed image
#

while ! mount -o ro $server /mnt/net ; do
    test "x$server" = xask || sleep 2
    dialog 2>/tmp/selection --backtitle "$title" --no-shadow --cancel-label "Redetect Network" --inputmenu "Please select server:directory and subdirectory via $net" 0 75 15 "${all_servers[@]}"
    read n n2 server dir </tmp/selection
    case "$n" in
	"RENAMED")
	;;
	"")
	exit 1
	;;
	*)
	echo ${all_servers[$(($n * 2 - 1))]} >/tmp/selection
	read server dir </tmp/selection
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
    test "x$image" = x && exec $0 "$@"
    iso="`echo *-$image.iso`"
done

if mount -o loop,ro -t udf "$iso" /mnt/iso ; then :; else
    echo "mounting $iso on /mnt/iso failed"
    sleep 2
    exit 1
fi

file="`echo /mnt/iso/*.bz2`"
test -e "$file" || file="`echo /mnt/iso/*.gz`"

if [ ! -e "$file" ] ; then
    /bin/ls -al /mnt/iso
    echo "Cannot find compressed image in iso - exiting"
    sleep 2
    exit 1
fi

read sum1 blocks blocksize remain <"$file.md5"
size=$(($blocks * $blocksize))
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
    fdisk -l | grep '^Disk /dev' >>/tmp/msg

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
	exec $0 "$@"
	;;
    esac
done

# Dump on disk

case "$file" in
*.bz2)	expand="bunzip2"	;;
*.gz)	expand="gunzip"		;;
esac
progress=""
test -x /dcounter -a "$sizeM" -gt 0 && progress='((/dcounter -s $sizeM -l "" 3>&1 1>&2 2>&3 3>&- | perl -e '\''$|=1; while (<>) { /(\d+)/; print "$1\n" }'\'' | dialog --backtitle "$title" --stdout --gauge "Dumping $image to $disk via $net" 0 75 ) 2>&1) | '

eval "$expand < \"$file\" | $progress dd of=/dev/$disk bs=1M" || exit 1

# Done

echo "Done. Rebooting"

do_reboot


