#!/system/bin/sh
# 生成 MFZ 冻结白名单：系统预置的 7 个游戏 + 用户在 WebUI 里选的应用。
# 同时写 /data/system/mfz.xml 和模块内的 /product 覆盖文件：不同的 mfz 实现
# 读取的路径不一样，两份内容保持一致。
# 用法：sh mfz_conf.sh <模块目录>
MOD=$1
CFG=${YT_CFG:-/data/adb/yudi-tweaks.conf}
DATA=/data/system/mfz.xml
PROD=$MOD/system/product/etc/mfz.xml
BASE='com.tencent.tmgp.pubgmhd com.tencent.tmgp.sgame com.miHoYo.Yuanshen com.miHoYo.ys.mi com.tencent.lolm com.miHoYo.ys.bilibili com.tencent.jkchess'

getval() { grep -m1 "^$1=" "$CFG" 2>/dev/null | cut -d= -f2-; }

[ -n "$MOD" ] || exit 1
MFZ=$(getval MFZ); MFZ=${MFZ:-1}
APPS=$(getval MFZ_APPS)

if [ "$MFZ" != 1 ]; then
	rm -f "$DATA" "$DATA.tmp" "$PROD" "$PROD.tmp"
	rmdir "$MOD/system/product/etc" "$MOD/system/product" 2>/dev/null
	exit 0
fi

# 合并、去重；包名只允许字母、数字、下划线和点，避免写出坏 XML
list=$BASE
oldifs=$IFS
IFS=', '
for p in $APPS; do
	case "$p" in
		''|*[!A-Za-z0-9_.]*) continue ;;
	esac
	case " $list " in
		*" $p "*) ;;
		*) list="$list $p" ;;
	esac
done
IFS=$oldifs

tmp=$DATA.tmp
mkdir -p "${DATA%/*}" || exit 1
{
	echo '<?xml version="1.0" encoding="utf-8"?>'
	echo '<contents>'
	for p in $list; do
		echo "    <designated-package name=\"$p\" />"
	done
	echo '</contents>'
} > "$tmp" || exit 1
mv -f "$tmp" "$DATA" || exit 1
chmod 644 "$DATA"
chcon u:object_r:system_data_file:s0 "$DATA" 2>/dev/null

mkdir -p "${PROD%/*}" || exit 1
cp -f "$DATA" "$PROD.tmp" && mv -f "$PROD.tmp" "$PROD" && chmod 644 "$PROD"
exit 0
