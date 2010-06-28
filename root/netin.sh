#!/bin/sh

## On exit reboot
trap "cd /; umount 2>/dev/null /mnt/iso; umount 2>/dev/null /mnt/net;" EXIT
set +H

# Default args
mkdir -p /mnt/net /mnt/iso
server=ask
dir=ask
image=ask
dialog=true
# Known names for image: full file name, version, "latest", "ask" (actually, anyting not found)

# Known servers
all_servers=(1 "berg:/data_build/   image" 2 "berg:/data/         released-images" 3 "hewson:/data        image")

# Get args from boot line and addon commandline in /
test -e /cmdline && eval `tr ' ' '\n' </cmdline | grep '^server=\|dir=\|image=\|dialog='`
eval `tr ' ' '\n' </proc/cmdline | grep '^server=\|dir=\|image=\|dialog='`
test "x$dialog" = xtrue || dialog=false

# TODO: this might still call dialog
/netconf.sh
netdev="`cat /tmp/net_device`"

# Get wire(less) speed
netspeed="`iwconfig $netdev 2>&1 | sed '/Bit Rate/!d;s/.*Bit Rate= *\([0-9]*\) *Mb.*/\1/'`"
if [ "x$netspeed" = x ] ; then
    netspeed="`ethtool $netdev 2>&1 | sed '/Speed:/!d;s/.*Speed: *\([0-9]*\) *Mb.*/\1/'`"
fi
net="${netdev:-[no net]} (${netspeed}Mb/s)"

# Get supposed harddisk
# Find largest disk
disk="`fdisk -lu | perl -e 'while (<>) { if (/^Disk \/dev\/(sd.): .*, (\d+) bytes/ && $2 > $s) { $d=$1; $s=$2 }} print "$d"'`"
if [ ! -e "/dev/$disk" ] ; then
    echo "Cannot find disk:"
    fdisk -lu
fi

if $dialog ; then :; else
    cat <<-EOINI
	
	
	===== Network Image Installer =====
	
	
	net    = $net
	disk   = $disk
	
	server = $server
	dir    = $dir
	image  = $image
	
	
	EOINI
fi

# Find compressed image

while ! mount $server /mnt/net ; do
    if $dialog ; then
        test "x$server" = xask || sleep 2
	dialog 2>/tmp/selection --no-shadow --inputmenu "Please select server:directory and subdirectory via $net" 0 75 15 "${all_servers[@]}"
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
    else
        test "x$server" = xask || echo "Cannot mount server $server"
	echo "Known servers: " "${all_servers[@]}"
	echo -n "Please enter server:directory (or press enter to leave): "
	read server
	test "x$server" = x && exit 1
    fi
done

while ! cd /mnt/net/$dir ; do
    test "x$dir" = xask || echo "Cannot cd to $dir"
    echo -n "Please enter subdirectory ('.' for current, or press enter to leave): "
    read dir
    test "x$dir" = x && exit 1
done

vers="`/bin/ls -U | sed -e '/\.iso$/!d;s/.*-\([0-9.]\+\).iso/\1/' | sort -rn `"

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
    if $dialog ; then
        test "x$image" = xask || sleep 2
	unset args
	i=0
	for f in $vers ; do
	    args[$i]=$f
	    i=$(($i+1))
	    args[$i]="`echo *-$f.iso`"
	    i=$(($i+1))
	done
	dialog 2>/tmp/selection --no-shadow --menu "Please select image" 0 0 0 "${args[@]}"
	image="`cat /tmp/selection`"
	test "x$image" = x && exit 1
    else
	echo -n "Please select image (or press enter to leave): "
	read image
	test "x$image" = x && exit 1
    fi
    iso="`echo *-$image.iso`"
done

$dialog || echo "Found image $server/$dir/$iso"
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

$dialog || echo "Found compressed image $file"
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

    if $dialog ; then
	dialog --no-shadow --no-collapse --cr-wrap --yes-label OK --no-label ABORT --extra-button --extra-label "Change Drive" --yesno "`cat /tmp/msg`" 0 0
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
	    exit 1
	    ;;
	esac
    else
	cat /tmp/msg
	echo ">>> Press <return> to continue, enter anything else to abort <<<"
	read i
	test "x$i" = x || exit 1
	device="/dev/$disk"
    fi
done

# Dump on disk

case "$file" in
*.bz2)	expand="bunzip2"	;;
*.gz)	expand="gunzip"		;;
esac
progress=""
test -x /dcounter -a "$sizeM" -gt 0 && $dialog && progress='((/dcounter -s $sizeM -l "" 3>&1 1>&2 2>&3 3>&- | perl -e '\''$|=1; while (<>) { /(\d+)/; print "$1\n" }'\'' | dialog --stdout --gauge "Dumping $image to $disk" 0 75 ) 2>&1) | '

eval "$expand < \"$file\" | $progress dd of=/dev/$disk bs=1M" || exit 1

# Done

echo "Done. Rebooting"

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

