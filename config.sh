#!/bin/bash
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

# kiwi doesn't copy /.kconfig from source to build dir
test -f /kconfig && . /kconfig 
rm /kconfig

echo "Configure image: [$kiwi_iname] type [$kiwi_type]..."
env
echo "EOCONF"

suseConfig
/sbin/ldconfig
baseCleanMount

sed --in-place -e 's/# solver.onlyRequires.*/solver.onlyRequires = true/' /etc/zypp/zypp.conf

# Enable sshd
chkconfig sshd on

mkdir /studio
cp /image/.profile /studio/profile
cp /image/config.xml /studio/config.xml


# The 'kiwi_type' variable will contain the format of the appliance (oem =
# disk image, vmx = VMware, iso = CD/DVD, xen = Xen).

# Remove all documentation
docfiles=`find /usr/share/doc/packages -type f |grep -iv "copying\|license\|copyright"`
rm -f $docfiles
rm -rf /usr/share/info
rm -rf /usr/share/man

rm -rf /var/adm/backup/rpmdb/Packages-*
rm /var/log/zypper.log

# /usr/share/vim:24M /usr/share/cracklib
# Delete non en-US locales
for i in /usr/lib/locale/* /usr/share/locale/*; do
   test -d "$i" || continue
   case "${i##*/}" in
       en_US*)
	   ;;
       *)
	   rm -rf $i;;
   esac
done
# rm -rf /usr/lib64/gconv /usr/lib/gconv
rm -rf /usr/share/doc

# Addapt bootloader config
sed -i -e 's/ showopts/ showopts server=berg.suse.de:\/data_build dir=image image=ask/' /etc/sysconfig/bootloader
sed -i -e 's/ ide=nodma/ dialog=false ide=nodma/' /etc/sysconfig/bootloader

# Allow sysrq
sed -i -e 's/^ENABLE_SYSRQ=.*/ENABLE_SYSRQ="yes"/' /etc/sysconfig/sysctl

# Remove potentially available network configurations
find /etc/sysconfig/network \( -name ifcfg-\* -a \! -name ifcfg-lo \) -exec rm \{\} \;

# Create runlevel symlinks for Network Image Installer and inform systemctl
# about this service
/sbin/insserv -d netimginst
/bin/systemctl enable netimginst.service

true
