#!/bin/sh
set -eu

ADB=${ADB:-adb}
cd "$(dirname "$0")/.."

sh scripts/package.sh

for zip in dist/*.zip; do
	id=$(basename "$zip" .zip)
	echo "installing $id"
	"$ADB" push "$zip" "/data/local/tmp/$id.zip" >/dev/null
	"$ADB" shell "su -c '/data/adb/ksud module install /data/local/tmp/$id.zip'"
done

echo "rebooting"
"$ADB" reboot
