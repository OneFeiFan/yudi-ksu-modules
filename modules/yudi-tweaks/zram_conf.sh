#!/system/bin/sh
# 生成 PerfInit 配置的覆盖文件：只把 /system_ext/etc/perfinit.conf 里的
# "comp_algo" 换成选定的算法，其余原样保留。KernelSU 挂载后，PerfInit 开机时
# 自己就按这个算法初始化 zram，不需要模块再 reset，ExtM 的写回设备也保留。
# 用法：sh zram_conf.sh <模块目录>
MOD=$1
CFG=${YT_CFG:-/data/adb/yudi-tweaks.conf}
SRC=${YT_PERFINIT:-/system_ext/etc/perfinit.conf}
CRYPTO=${YT_CRYPTO:-/proc/crypto}
DST=$MOD/system/system_ext/etc/perfinit.conf

getval() { grep -m1 "^$1=" "$CFG" 2>/dev/null | cut -d= -f2-; }
drop() {
	rm -f "$DST" "$DST.tmp"
	rmdir "$MOD/system/system_ext/etc" "$MOD/system/system_ext" "$MOD/system" 2>/dev/null
	return 0
}

ZRAM=$(getval ZRAM); ZRAM=${ZRAM:-1}
ALGO=$(getval ZRAM_ALGO); ALGO=${ALGO:-lz4kd}

[ -n "$MOD" ] || exit 1
# 开关关闭、找不到原配置、或算法没有注册到内核压缩接口时，不覆盖
if [ "$ZRAM" != 1 ] || [ ! -f "$SRC" ] || ! grep -qE "^name[[:space:]]*: $ALGO\$" "$CRYPTO" 2>/dev/null; then
	drop; exit 0
fi

mkdir -p "${DST%/*}" || exit 1
sed -E 's/("comp_algo"[[:space:]]*:[[:space:]]*")[^"]*(")/\1'"$ALGO"'\2/' "$SRC" > "$DST.tmp" 2>/dev/null
# 原配置里没有 comp_algo（换了 ROM），就不覆盖
if ! grep -qE "\"comp_algo\"[[:space:]]*:[[:space:]]*\"$ALGO\"" "$DST.tmp" 2>/dev/null; then
	drop; exit 0
fi
cmp -s "$DST.tmp" "$DST" 2>/dev/null && { rm -f "$DST.tmp"; exit 0; }
mv -f "$DST.tmp" "$DST"
chmod 0644 "$DST"
# 沿用原文件的 SELinux 标签，保证 PerfInit 能读
ctx=$(ls -Z "$SRC" 2>/dev/null | awk '{print $1}')
case "$ctx" in u:*) chcon "$ctx" "$DST" 2>/dev/null ;; esac
exit 0
