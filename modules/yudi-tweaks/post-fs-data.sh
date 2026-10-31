#!/system/bin/sh
MODDIR=${0%/*}
# 在模块挂载、PerfInit 启动之前，按当前配置生成 perfinit.conf 覆盖
sh "$MODDIR/zram_conf.sh" "$MODDIR"
