#!/bin/bash

nii_url="http://ivanova.suse.de/NetworkImageInstaller"
chlog="Changelog"
tarbase="update-"
base="Network_Image_Installer.i686-"
vers="`sed -e 's/.*-//' < /etc/ImageVersion`"

owndisk="`cat /proc/mounts | sed -e '/\/read-write /!d; s/[0-9]\+ .*//'`"
if [ "x$owndisk" == x -o ! -e "$owndisk" ] ; then
    echo "Cannot determine root disk"
    sleep 2
    owndisk=""
fi

netdev="`cat /tmp/net_device 2>/dev/null`"
# Get wire(less) speed
netspeed="`iwconfig $netdev 2>&1 | sed '/Bit Rate/!d;s/.*Bit Rate= *\([0-9]*\) *Mb.*/\1/'`"
if [ "x$netspeed" = x ] ; then
    netspeed="`ethtool $netdev 2>&1 | sed '/Speed:/!d;s/.*Speed: *\([0-9]*\) *Mb.*/\1/'`"
fi
net="${netdev:-[no net]} (${netspeed}Mb/s)"


# Check if update is available
if [ "x$netdev" != x -a "x$owndisk" != x ] ; then
    if curl -s -f -o /tmp/chlog "$nii_url/$chlog" >/dev/null ; then
	new="`head -1 /tmp/chlog`"
	if [ "$new" != "$vers" ] ; then
	    if [ "${new%.*}" == "${vers%.*}" ] && curl -s -f -o /tmp/files.tar.gz "$nii_url/$tarbase$new.tar.gz" ; then
		cat >/tmp/msg <<- EOUPDATE
		A new minor version update is available:  \\Z7\\Zb$new\\Zn  (current: $vers)
		Update USB stick via $net (scripts only) ?

		Changes:\\Zb

		EOUPDATE
		sed -e "/^$vers/,\$d" </tmp/chlog >>/tmp/msg
		DIALOGRC=/inst/dialogrc-update dialog --colors --backtitle "$vers" --no-collapse --cr-wrap --yes-label "Update" --no-label "Continue" --defaultno --yesno "`head -18 /tmp/msg`" 23 75 && exec /inst/selfminorupdate.sh "$new" /tmp/files.tar.gz
		exit 0
	    fi
	    if curl -f -s -I "$nii_url/$base$new.raw" > /dev/null ; then
		diskdef=`fdisk -l | sed -e "\\@^Disk $owndisk@"'!d;s/,.*//'`
		cat >/tmp/msg <<- EOUPDATE
		A new major version update is available:  \\Z7\\Zb$new\\Zn  (current: $vers)
		
		Update USB stick via $net on $diskdef ?
		\\Z1This will destroy all data! Make sure the right disk is used!\\Zn

		Changes:\\Zb

		EOUPDATE
		sed -e "/^$vers/,\$d" </tmp/chlog >>/tmp/msg
		DIALOGRC=/inst/dialogrc-update dialog --colors --backtitle "$vers" --no-collapse --cr-wrap --yes-label "Update" --no-label "Continue" --defaultno --yesno "`head -18 /tmp/msg`" 23 75 && exec /inst/bootstrap.sh /inst/selfupdate.sh "$nii_url/$base$new.raw" "$owndisk"
		exit 0
	    fi
	fi
    fi
fi

exit 0

