#!/system/bin/sh
# 生成 MFZ 冻结白名单：系统原有名单 + 用户在 WebUI 里选的应用。
# 写两处：/data/system/mfz.xml 和模块内的 /product 覆盖文件（不同的 mfz 实现读取的路径不一样）。
#   - 基础名单从原始 /product/etc/mfz.xml 读取并保存在 mfz_base.txt；读不到时用内置的 7 个游戏
#   - /product 覆盖文件以原始文件为底本，只在根元素末尾追加用户选的应用，其余内容原样保留
#   - /data/system/mfz.xml 若被系统或云控改过（不是本模块上次写的内容），保留其中的应用并合并
#   - 关闭 MFZ 时只删除本模块写的文件
# 用法：sh mfz_conf.sh <模块目录>
MOD=$1
CFG=${YT_CFG:-/data/adb/yudi-tweaks.conf}
SYS=/product/etc/mfz.xml
DATA=/data/system/mfz.xml
PROD=$MOD/system/product/etc/mfz.xml
BASEF=$MOD/mfz_base.txt
SYSF=$MOD/mfz_product_orig.xml
OWN=$MOD/.mfz_data.sha
FALLBACK='com.tencent.tmgp.pubgmhd com.tencent.tmgp.sgame com.miHoYo.Yuanshen com.miHoYo.ys.mi com.tencent.lolm com.miHoYo.ys.bilibili com.tencent.jkchess'

getval() { grep -m1 "^$1=" "$CFG" 2>/dev/null | cut -d= -f2-; }
pkgs_of() { grep -o 'designated-package name="[^"]*"' "$1" 2>/dev/null | sed 's/.*name="//; s/"$//'; }
sha() { sha256sum "$1" 2>/dev/null | cut -c1-64; }

[ -n "$MOD" ] || exit 1
MFZ=$(getval MFZ); MFZ=${MFZ:-1}
APPS=$(getval MFZ_APPS)

MARK='yudi-tweaks mfz overlay'
# 原始 /product/etc/mfz.xml：带本模块标记的是覆盖文件（挂载之后读到的），不采用
if [ -f "$SYS" ] && ! grep -q "$MARK" "$SYS"; then
	l=$(pkgs_of "$SYS")
	if [ -n "$l" ]; then
		echo "$l" > "$BASEF"
		cp -f "$SYS" "$SYSF"
	fi
fi

if [ "$MFZ" != 1 ]; then
	rm -f "$PROD" "$PROD.tmp"
	rmdir "$MOD/system/product/etc" "$MOD/system/product" 2>/dev/null
	if [ -f "$DATA" ] && [ "$(sha "$DATA")" = "$(cat "$OWN" 2>/dev/null)" ]; then
		rm -f "$DATA"
	fi
	rm -f "$OWN"
	exit 0
fi

BASE=$(tr '\n' ' ' < "$BASEF" 2>/dev/null)
[ -n "$BASE" ] || BASE=$FALLBACK

# 合并、去重；包名只允许字母、数字、下划线和点，避免写出坏 XML
list=""
add() {
	case "$1" in ''|*[!A-Za-z0-9_.]*) return ;; esac
	case " $list " in *" $1 "*) ;; *) list="$list $1" ;; esac
}
for p in $BASE; do add "$p"; done
# 系统或云控改过的 /data 名单：保留其中的应用
if [ -f "$DATA" ] && [ "$(sha "$DATA")" != "$(cat "$OWN" 2>/dev/null)" ]; then
	for p in $(pkgs_of "$DATA"); do add "$p"; done
fi
oldifs=$IFS; IFS=', '
for p in $APPS; do add "$p"; done
IFS=$oldifs
list=${list# }

entries() {
	for p in $list; do echo "    <designated-package name=\"$p\" />"; done
}

# /data/system/mfz.xml：完整名单
tmp=$DATA.tmp
mkdir -p "${DATA%/*}" || exit 1
{
	echo '<?xml version="1.0" encoding="utf-8"?>'
	echo '<contents>'
	entries
	echo '</contents>'
} > "$tmp" || exit 1
mv -f "$tmp" "$DATA" || exit 1
chmod 644 "$DATA"
chcon u:object_r:system_data_file:s0 "$DATA" 2>/dev/null
sha "$DATA" > "$OWN"

# /product 覆盖文件：以原件为底本，在根元素的结束标签前追加原件里没有的应用
mkdir -p "${PROD%/*}" || exit 1
if [ -f "$SYSF" ]; then
	extra=""
	for p in $list; do
		case " $BASE " in *" $p "*) ;; *) extra="$extra $p" ;; esac
	done
	awk -v extra="$extra" -v mark="$MARK" '
		{ line[NR] = $0 }
		/<\/[A-Za-z_-]+>[[:space:]]*$/ { last = NR }
		END {
			n = split(extra, a, " ")
			for (i = 1; i <= NR; i++) {
				if (i == last) {
					printf "    <!-- %s -->\n", mark
					for (j = 1; j <= n; j++)
						printf "    <designated-package name=\"%s\" />\n", a[j]
				}
				print line[i]
			}
		}' "$SYSF" > "$PROD.tmp" || exit 1
else
	{
		echo '<?xml version="1.0" encoding="utf-8"?>'
		echo '<contents>'
		echo "    <!-- $MARK -->"
		entries
		echo '</contents>'
	} > "$PROD.tmp" || exit 1
fi
mv -f "$PROD.tmp" "$PROD" && chmod 644 "$PROD"
exit 0
