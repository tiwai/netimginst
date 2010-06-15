#!/bin/bash
#================
# FILE          : config.sh
#----------------
# PROJECT       : OpenSuSE KIWI Image System
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH. All rights reserved
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : configuration script for SUSE based
#               : operating systems
#               :
#               :
# STATUS        : BETA
#----------------
#======================================
# Functions...
#--------------------------------------
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

# kiwi doesn't copy /.kconfig from source to build dir
test -f /kconfig && . /kconfig 

echo "Configure image: [$name]..."

echo "** Running suseConfig..."
suseConfig

echo "** Running ldconfig..."
/sbin/ldconfig

echo "** Running baseCleanMount..."
baseCleanMount

echo "** Removing kconfig..."
rm /kconfig

sed --in-place -e 's/# solver.onlyRequires.*/solver.onlyRequires = true/' /etc/zypp/zypp.conf

# Enable sshd
chkconfig sshd on
chown root:root /build-custom
chmod +x /build-custom
# run custom build_script after build
/build-custom
mkdir /studio
cp /image/.profile /studio/profile
cp /image/config.xml /studio/config.xml
true
