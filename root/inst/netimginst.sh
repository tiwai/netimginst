#!/bin/bash

# Additional scripts (until next major update)
test ! -e /inst/dia_gauge -a -e /read-write/inst/dia_gauge && ln -snf /read-write/inst/dia_gauge /inst/dia_gauge
test -d /read-write && ln -snf /read-write/inst/selfupdate.sh /inst/selfupdate.sh

/inst/network.sh
/inst/checkupdate.sh
exec /inst/installer.sh

