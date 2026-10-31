#!/system/bin/sh
# 屏蔽移植包自带的月亮内存模块（/vendor/etc/moon_modules/*.ko）。
# 它们由 vendor 的 init.qti.kernel.rc 在开机后期 insmod，与内核无关；init 的 rc
# 早于 KernelSU 挂载，改不了，所以改为用空文件覆盖这些 .ko，让 insmod 失败。
# 用法：sh moon_block.sh <模块目录>
MOD=$1
CFG=${YT_CFG:-/data/adb/yudi-tweaks.conf}
SRCDIR=${YT_MOONDIR:-/vendor/etc/moon_modules}
DSTDIR=$MOD/system/vendor/etc/moon_modules

getval() { grep -m1 "^$1=" "$CFG" 2>/dev/null | cut -d= -f2-; }
MOON_MODS=$(getval MOON_MODS); MOON_MODS=${MOON_MODS:-0}

[ -n "$MOD" ] || exit 1
if [ "$MOON_MODS" = 1 ] || [ ! -d "$SRCDIR" ]; then
	rm -rf "$DSTDIR"
	rmdir "$MOD/system/vendor/etc" "$MOD/system/vendor" "$MOD/system" 2>/dev/null
	exit 0
fi
mkdir -p "$DSTDIR" || exit 1
for f in "$SRCDIR"/*.ko; do
	[ -e "$f" ] || continue
	# 覆盖已挂载时，原目录里看到的是空文件，跳过即可
	[ -s "$f" ] || [ -e "$DSTDIR/${f##*/}" ] || continue
	: > "$DSTDIR/${f##*/}"
	chmod 0644 "$DSTDIR/${f##*/}"
	ctx=$(ls -Z "$f" 2>/dev/null | awk '{print $1}')
	case "$ctx" in u:*) chcon "$ctx" "$DSTDIR/${f##*/}" 2>/dev/null ;; esac
done
exit 0
