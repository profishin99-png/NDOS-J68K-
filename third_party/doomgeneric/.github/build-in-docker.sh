#!/bin/bash

# Build ToaruOS
NEWUID=`stat -c '%u' .`
if [[ "$NEWUID" == "0" ]]; then
    echo "Are you running this on Docker for Mac? Owner UID is 0, going to use 501 instead."
    NEWUID=501
fi
useradd -u $NEWUID local
chown -R local:local /root
ln -s /root/gcc_local /root/misaka/util/local
runuser -u local -- sh -c 'make base/lib/libc.so && make -j4' >/tmp/toaru.stdout.log 2>/tmp/toaru.stderr.log

# Now build our repository
runuser -u local -- bash -c 'source util/activate.sh; cd /root/repo/doomgeneric && make -j16 -f Makefile.toaru'

rm util/local

