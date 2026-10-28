#!/system/bin/sh
# ntsync is a misc device; its minor is allocated dynamically.
dev=$(cat /sys/class/misc/ntsync/dev 2>/dev/null)
[ -n "$dev" ] || exit 0
mknod /dev/ntsync c "${dev%:*}" "${dev#*:}" 2>/dev/null
chmod 666 /dev/ntsync
chcon u:object_r:device:s0 /dev/ntsync
