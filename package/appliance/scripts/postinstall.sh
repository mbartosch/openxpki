#!/bin/bash
echo "postinstall arg1: $1"
chroot $1 /bin/run-parts /usr/local/lib/appliance-config/postinstall.d/
