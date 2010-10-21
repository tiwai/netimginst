#!/bin/bash

# Usage: $0              - check for updates via Changelog
#        $0 [new]        - check for update to [new]
#        $0 [new] [old]  - check for update to [new] from [old]

# Returns command for update in /tmp/selfupdate.cmd if required

force_new="$1"
force_old="$2"

nii_url="http://ivanova.suse.de/NetworkImageInstaller"
chlog="Changelog"
tarbase="update-"
base="Network_Image_Installer.i686-"
vers="`sed -e 's/.*-//' < /etc/ImageVersion`"
vers=${force_old:-$vers}
cmdfile=/tmp/bootstrap.cmd
rm -f $cmdfile

owndisk="`cat /proc/mounts | sed -e '/\/read-write /!d; s/[0-9]\+ .*//'`"
if [ "x$owndisk" == x -o ! -e "$owndisk" ] ; then
    echo "Cannot determine root disk"
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
test "x$netdev" != x || exit 0
rm -f /tmp/chlog /tmp/chlog2
curl -s -f -o /tmp/chlog "$nii_url/$chlog" >/dev/null
curl -s -f -o /tmp/chlog2 "$nii_url/current" >/dev/null
test -e /tmp/chlog -o -e /tmp/chlog2 || exit 0

test -e /tmp/chlog  || cp /tmp/chlog2 /tmp/chlog
new="`head -1 /tmp/chlog`"
test -e /tmp/chlog2 && new="`head -1 /tmp/chlog2`"
echo "Version: $vers   New: $new"

new=${force_new:-$new}
test "$new" = "$vers" && exit 0

if [ -e /inst/selfminorupdate.sh -a "${new%.*}" == "${vers%.*}" ] && curl -s -f -o /tmp/files.tar.gz "$nii_url/$tarbase$new.tar.gz" ; then
    cat >/tmp/msg <<- EOUPDATE
	A new minor version update is available:  \\Z7\\Zb$new\\Zn  (current: $vers)
	Update USB stick via $net (scripts only) ?
	
	Changes:\\Zb
	
	EOUPDATE
    sed -e "/^$vers/,\$d" </tmp/chlog >>/tmp/msg
    DIALOGRC=/inst/dialogrc-update dialog --colors --backtitle "$vers" --no-collapse --cr-wrap --yes-label "Update" --no-label "Continue" --defaultno --yesno "`head -18 /tmp/msg`" 23 75 && echo >$cmdfile "exec /inst/selfminorupdate.sh '$new' /tmp/files.tar.gz"
    exit 0
fi
if [ -e /inst/selfupdate.sh -a "x$owndisk" != x ] && curl -f -s -I "$nii_url/$base$new.raw" > /dev/null ; then
    diskdef=`fdisk -l | sed -e "\\@^Disk $owndisk@"'!d;s/,.*//'`
    cat >/tmp/msg <<- EOUPDATE
	A new major version update is available:  \\Z7\\Zb$new\\Zn  (current: $vers)
	
	Update USB stick via $net on $diskdef ?
	\\Z1This will destroy all data! Make sure the right disk is used!\\Zn
	
	Changes:\\Zb
	
	EOUPDATE
    sed -e "/^$vers/,\$d" </tmp/chlog >>/tmp/msg
    DIALOGRC=/inst/dialogrc-update dialog --colors --backtitle "$vers" --no-collapse --cr-wrap --yes-label "Update" --no-label "Continue" --defaultno --yesno "`head -18 /tmp/msg`" 23 75 && echo >$cmdfile "exec /inst/bootstrap.sh /inst/selfupdate.sh '$nii_url/$base$new.raw' '$owndisk'"
    exit 0
fi
if [ -e /inst/selfupdate.sh -a "x$owndisk" != x ] && curl -f -s -I "$nii_url/$base${new%.*}.0.raw" > /dev/null ; then
    diskdef=`fdisk -l | sed -e "\\@^Disk $owndisk@"'!d;s/,.*//'`
    cat >/tmp/msg <<- EOUPDATE
	A new major version update is available:  \\Z7\\Zb${new%.*}.0\\Zn  (current: $vers)
	Additionally a minor update to \\Z7\\Zb$new\\Zn will be required afterwards.
	
	Update USB stick via $net on $diskdef ?
	\\Z1This will destroy all data! Make sure the right disk is used!\\Zn
	
	Changes:\\Zb
	
	EOUPDATE
    sed -e "/^$vers/,\$d" </tmp/chlog >>/tmp/msg
    DIALOGRC=/inst/dialogrc-update dialog --colors --backtitle "$vers" --no-collapse --cr-wrap --yes-label "Update" --no-label "Continue" --defaultno --yesno "`head -18 /tmp/msg`" 23 75 && echo >$cmdfile "exec /inst/bootstrap.sh /inst/selfupdate.sh '$nii_url/$base${new%.*}.0.raw' '$owndisk'"
    exit 0
fi
if [ -e /inst/selfminorupdate.sh ] && curl -s -f -o /tmp/files.tar.gz "$nii_url/$tarbase${vers%.*}.$((${vers##*.}+1)).tar.gz" ; then
    cat >/tmp/msg <<- EOUPDATE
	A new minor version update is available:  \\Z7\\Zb${vers%.*}.$((${vers##*.}+1))\\Zn  (current: $vers)
	Additionally a major update to \\Z7\\Zb$new\\Zn will be required afterwards.
	Update USB stick via $net (scripts only) ?
	
	Changes:\\Zb
	
	EOUPDATE
    new=${vers%.*}.$((${vers##*.}+1))
    sed -e "/^$vers/,\$d" </tmp/chlog >>/tmp/msg
    DIALOGRC=/inst/dialogrc-update dialog --colors --backtitle "$vers" --no-collapse --cr-wrap --yes-label "Update" --no-label "Continue" --defaultno --yesno "`head -18 /tmp/msg`" 23 75 && echo >$cmdfile "exec /inst/selfminorupdate.sh '$new' /tmp/files.tar.gz"
    exit 0
fi

exit 0

