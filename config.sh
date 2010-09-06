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
rm -rf /usr/share/locale /usr/share/doc /usr/lib/locale


# Addapt bootloader config
sed -i -e 's/ showopts/ showopts server=berg.suse.de:\/data_build dir=image image=ask/' /etc/sysconfig/bootloader
sed -i -e 's/ ide=nodma/ dialog=false ide=nodma/' /etc/sysconfig/bootloader

# Allow sysrq
sed -i -e 's/^ENABLE_SYSRQ=.*/ENABLE_SYSRQ="yes"/' /etc/sysconfig/sysctl

# Remove potentially available network configurations
find /etc/sysconfig/network \( -name ifcfg-\* -a \! -name ifcfg-lo \) -exec rm \{\} \;

true
