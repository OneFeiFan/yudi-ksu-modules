#!/bin/sh
set -eu

ADB=${ADB:-adb}
cd "$(dirname "$0")/.."

for dir in modules/*; do
	id=$(basename "$dir")
	echo "installing $id"
	"$ADB" push "$dir" "/data/local/tmp/$id" >/dev/null
	"$ADB" shell "su -c 'rm -rf /data/adb/modules/$id; cp -r /data/local/tmp/$id /data/adb/modules/$id; chmod 644 /data/adb/modules/$id/module.prop; find /data/adb/modules/$id -name \"*.sh\" -exec chmod 755 {} +; chcon -R u:object_r:system_file:s0 /data/adb/modules/$id'"
done

echo "rebooting"
"$ADB" reboot
