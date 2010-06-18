#!/bin/bash

# Prints and runs the given command. Aborts if the command fails.
function run_cmd {
  command=$1
  logfile=$2
  echo $command
  $command
  if [ $? -ne 0 ]; then
    echo
    echo "** Appliance creation failed!"
    if [ "$logfile" != '' ]; then
      echo "See $logfile for details."
    fi
    exit 1
  fi
}

# Get version number
vers="`sed -e '/<version>/!d;s/.*<version>//;s/<\/version>.*//;' < config.xml`"

# Check that we're root.
if [ `whoami` != 'root' ]; then
  echo "Please run this script as root."
  exit 1
fi

# Check that kiwi is installed.
kiwi=`which kiwi 2> /dev/null`
if [ $? -ne 0 ]; then
  echo "Kiwi is required but not found on your system."
  echo "Run the following command to install kiwi:"
  echo
  echo "  zypper install kiwi kiwi-tools kiwi-desc-* kiwi-doc"
  echo
  exit 1
fi

# Check kiwi version.
kiwi_ver='kiwi-3.74-147.1.x86_64'
installed_kiwi_ver=`rpm -q kiwi`
if [ "$installed_kiwi_ver" != "$kiwi_ver" ]; then
  echo "'$kiwi_ver' expected, but '$installed_kiwi_ver' found."
  while true; do
    read -p "Continue? [y/n] " yn
    case $yn in
      [Yy]* ) break;;
      [Nn]* ) exit;;
    esac
  done
fi

# Check architecture (i686, x86_64).
image_arch='i686'
sys_arch=`uname -m`
linux32=`which linux32 2>/dev/null`
if [ "$image_arch" = 'i686' ] && [ "$sys_arch" = 'x86_64' ]; then
  if [ "$linux32" = '' ]; then
    echo "'linux32' is required but not found."
    exit 1
  else
    kiwi="$linux32 $kiwi"
  fi
elif [ "$image_arch" = 'x86_64' ] && [ "$sys_arch" = 'i686' ]; then
  echo "Cannot build $image_arch image on a $sys_arch machine."
  exit 1
fi

# Create appliance
echo
echo "** Creating appliance..."
run_cmd "rm -rf build/root"
run_cmd "mkdir -p build image"

log='prepare.log'
run_cmd "$kiwi --prepare . --root build/root --logfile $log" $log

log='create.log'
run_cmd "$kiwi --create build/root -d image \
               --logfile $log" $log

base="image/Network_Image_Installer.i686-$vers"

# And we're done!
echo
echo "** Appliance created successfully!"
echo "$base.raw"
echo ""
echo "To boot one of the images using qemu-kvm, run the following command:"
echo "  qemu-kvm -m 512 -snapshot $base.raw &"
echo
