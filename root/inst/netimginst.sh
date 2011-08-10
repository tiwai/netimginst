#!/bin/bash

# Remove updater script if no persistent r/w area available (CDs)
test -d /read-write || rm -f /inst/selfupdate.sh

# Intermediate fix until 2.5: link config
test -d /read-write && ln -snf /read-write/inst/config /inst/config

cmdfile=/tmp/bootstrap.cmd
rm -f $cmdfile

/inst/network.sh
/inst/checkupdate.sh
test -e $cmdfile && source $cmdfile
/inst/installer.sh
test -e $cmdfile && source $cmdfile

