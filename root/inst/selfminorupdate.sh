#!/bin/sh

if [ "x$1" != x- ] ; then
    cp $0 /tmp/selfminorupdate.sh || exit 1
    exec /tmp/selfminorupdate.sh - "$@"
fi

shift
vers="$1"
file="$2"

root=/
test -d /read-write && root=/read-write/

tar -C $root -xvf "$file" || exit 1

sed -i -e 's/-[.0-9]*$/-'"$vers/" /etc/ImageVersion

echo "Done updating. Restarting..."
sleep 2

exit 0

