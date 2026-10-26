#!/system/bin/sh
mknod /dev/ntsync c 10 127 2>/dev/null
chmod 666 /dev/ntsync
chcon u:object_r:device:s0 /dev/ntsync
