#!/system/bin/sh
MODDIR=${0%/*}
# 在模块挂载、PerfInit 启动之前，按当前配置生成 perfinit.conf 覆盖
sh "$MODDIR/zram_conf.sh" "$MODDIR"
# 屏蔽移植包里的月亮内存模块（MOON_MODS=1 时不屏蔽）
sh "$MODDIR/moon_block.sh" "$MODDIR"
