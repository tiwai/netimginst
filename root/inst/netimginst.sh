#!/bin/bash

# Remove updater script if no persistent r/w area available (CDs)
test -d /read-write || rm -f /inst/selfupdate.sh

/inst/network.sh
/inst/checkupdate.sh
exec /inst/installer.sh

