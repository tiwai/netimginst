#!/bin/bash

nii_url="http://ivanova.suse.de/NetworkImageInstaller"
vers="`cat /etc/ImageVersion`"

owndisk="`cat /proc/mounts | sed -e '/\/read-write /!d; s/[0-9]\+ .*//'`"
if [ "x$owndisk" == x -o ! -e "$owndisk" ] ; then
    echo "Cannot determine root disk"
    sleep 2
    owndisk=""
fi

/inst/network.sh

netdev="`cat /tmp/net_device 2>/dev/null`"
# Get wire(less) speed
netspeed="`iwconfig $netdev 2>&1 | sed '/Bit Rate/!d;s/.*Bit Rate= *\([0-9]*\) *Mb.*/\1/'`"
if [ "x$netspeed" = x ] ; then
    netspeed="`ethtool $netdev 2>&1 | sed '/Speed:/!d;s/.*Speed: *\([0-9]*\) *Mb.*/\1/'`"
fi
net="${netdev:-[no net]} (${netspeed}Mb/s)"


# Check if update is available
if [ "x$netdev" != x -a "x$owndisk" != x ] ; then
    if curl -f -s -I "$nii_url/current" >/dev/null ; then
	new="`curl -s "$nii_url/current"`"
	if [ "${new/.i?86/}" != "$vers" ] ; then
	    if curl -f -s -I "$nii_url/$new.raw" > /dev/null ; then
		cat >/tmp/msg <<- EOUPDATE
		There is a new NetworkImageInstaller available.
		Update USB stick?

		This is       $vers
		Available is  ${new/.i?86/}
		
		Update via $net on drive $owndisk?
		This will destroy all data! Make sure the right disk is used!
		EOUPDATE
		fdisk -l | grep '^Disk /dev' >>/tmp/msg
		dialog --backtitle "$vers" --no-shadow --no-collapse --cr-wrap --yes-label "Update" --no-label "Continue" --yesno "`cat /tmp/msg`" 20 70
		case $? in
		0)
		    exec /inst/bootstrap.sh /inst/selfupdate.sh "$nii_url/$new.raw" "$owndisk"
		    ;;
    		esac
	    fi
	fi
    fi
fi

exec /inst/installer.sh

