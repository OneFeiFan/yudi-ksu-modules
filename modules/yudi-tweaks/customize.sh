# 安装时就生成一次 perfinit.conf 覆盖，保证装完后的第一次开机就生效
sh "$MODPATH/zram_conf.sh" "$MODPATH"
if [ -f "$MODPATH/system/system_ext/etc/perfinit.conf" ]; then
	ui_print "- PerfInit 将以 $(grep -o '"comp_algo"[^,}]*' "$MODPATH/system/system_ext/etc/perfinit.conf") 初始化 zram"
else
	ui_print "- 未生成 perfinit.conf 覆盖（zram 开关关闭、算法未注册或原配置不含 comp_algo）"
fi
sh "$MODPATH/moon_block.sh" "$MODPATH"
if [ -d "$MODPATH/system/vendor/etc/moon_modules" ]; then
	ui_print "- 将屏蔽 /vendor/etc/moon_modules 下的 $(ls "$MODPATH/system/vendor/etc/moon_modules" | wc -l) 个月亮内存模块"
fi
