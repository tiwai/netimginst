#!/bin/bash

# Remove updater script if no persistent r/w area available (CDs)
test -d /read-write || rm -f /inst/selfupdate.sh

# Additional scripts (until next major update)
test ! -e /inst/dia_gauge -a -e /read-write/inst/dia_gauge && ln -snf /read-write/inst/dia_gauge /inst/dia_gauge
test -d /read-write && ln -snf /read-write/inst/selfupdate.sh /inst/selfupdate.sh
echo "Network_Image_Installer-2.2.5" >/etc/ImageVersion

/inst/network.sh
/inst/checkupdate.sh
exec /inst/installer.sh

