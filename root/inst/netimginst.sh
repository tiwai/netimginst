#!/bin/bash

# Remove updater script if no persistent r/w area available (CDs)
test -d /read-write || rm -f /inst/selfupdate.sh

/inst/network.sh
/inst/checkupdate.sh
test -e /tmp/selfupdate.cmd && source /tmp/selfupdate.cmd
exec /inst/installer.sh

