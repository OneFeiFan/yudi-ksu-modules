#!/system/bin/sh

MODDIR=${0%/*}
CFG=/data/adb/yudi-tweaks.conf
LOG=/data/adb/yudi-tweaks.log
ZRAM_DEV=/dev/block/zram0
ZRAM_SYS=/sys/block/zram0

: > "$LOG"
log() { echo "$(date '+%H:%M:%S') $*" >> "$LOG"; }

getval() {
	grep -m1 "^$1=" "$CFG" 2>/dev/null | cut -d= -f2-
}

SYSCTL=$(getval SYSCTL); SYSCTL=${SYSCTL:-1}
BBR3=$(getval BBR3); BBR3=${BBR3:-1}
LE9UO=$(getval LE9UO); LE9UO=${LE9UO:-1}
KSM=$(getval KSM); KSM=${KSM:-0}
ADIOS=$(getval ADIOS); ADIOS=${ADIOS:-0}
ZRAM=$(getval ZRAM); ZRAM=${ZRAM:-1}
ZRAM_ALGO=$(getval ZRAM_ALGO); ZRAM_ALGO=${ZRAM_ALGO:-lz4kd}
ZRAM_SIZE=$(getval ZRAM_SIZE); ZRAM_SIZE=${ZRAM_SIZE:-17179869184}
ZRAM_FORCE=$(getval ZRAM_FORCE); ZRAM_FORCE=${ZRAM_FORCE:-0}
DAMON=$(getval DAMON); DAMON=${DAMON:-0}
GOV=$(getval GOV)

if [ "$SYSCTL" = 1 ]; then
	echo 1048576 > /proc/sys/vm/max_map_count
	echo 524288 > /proc/sys/fs/inotify/max_user_watches
	echo 1024 > /proc/sys/fs/inotify/max_user_instances
	log "sysctl applied"
fi

if [ "$BBR3" = 1 ]; then
	if grep -qw bbr3 /proc/sys/net/ipv4/tcp_available_congestion_control; then
		echo bbr3 > /proc/sys/net/ipv4/tcp_congestion_control
		log "bbr3 enabled"
	else
		log "bbr3 not available"
	fi
fi

if [ -e /proc/sys/vm/workingset_protection ]; then
	if [ "$LE9UO" = 1 ]; then
		echo 1 > /proc/sys/vm/workingset_protection
		echo 15 > /proc/sys/vm/anon_min_ratio
		echo 15 > /proc/sys/vm/clean_min_ratio
		log "le9uo enabled"
	else
		echo 0 > /proc/sys/vm/workingset_protection
		log "le9uo disabled"
	fi
fi

if [ "$KSM" = 1 ] && [ -e /sys/kernel/mm/ksm/run ]; then
	echo 1 > /sys/kernel/mm/ksm/run
	log "ksm enabled"
fi

if [ "$ADIOS" = 1 ]; then
	for d in sda sdb sdc sdd sde sdf; do
		[ -e "/sys/block/$d/queue/scheduler" ] || continue
		echo adios > "/sys/block/$d/queue/scheduler" 2>/dev/null && log "adios on $d"
	done
fi

if [ -n "$GOV" ] && [ -w /sys/devices/system/cpu/cpuidle/current_governor ]; then
	if grep -qw "$GOV" /sys/devices/system/cpu/cpuidle/available_governors; then
		echo "$GOV" > /sys/devices/system/cpu/cpuidle/current_governor && log "governor $GOV"
	else
		log "governor $GOV not available"
	fi
fi

has_algo() {
	grep -qE "^name[[:space:]]*: $1\$" /proc/crypto 2>/dev/null
}

zram_state() {
	echo "algo=$(sed -n 's/.*\[\([^]]*\)\].*/\1/p' "$ZRAM_SYS/comp_algorithm") disksize=$(cat "$ZRAM_SYS/disksize") backing=$(cat "$ZRAM_SYS/backing_dev" 2>/dev/null || echo n/a)"
}

# 强制重新初始化：沿用系统设好的容量，并在设容量之前恢复 ExtM 的写回设备
reinit_zram() {
	algo=$1
	size=$(cat "$ZRAM_SYS/disksize")
	[ "$size" -gt 0 ] 2>/dev/null || size=$ZRAM_SIZE
	bdev=$(cat "$ZRAM_SYS/backing_dev" 2>/dev/null)
	wle=$(cat "$ZRAM_SYS/writeback_limit_enable" 2>/dev/null)
	wl=$(cat "$ZRAM_SYS/writeback_limit" 2>/dev/null)
	swapoff "$ZRAM_DEV" 2>/dev/null
	echo 1 > "$ZRAM_SYS/reset" || return 1
	echo "$algo" > "$ZRAM_SYS/comp_algorithm" || return 1
	if [ -n "$bdev" ] && [ "$bdev" != none ]; then
		echo "$bdev" > "$ZRAM_SYS/backing_dev" || log "zram: restore backing_dev $bdev failed"
	fi
	echo "$size" > "$ZRAM_SYS/disksize" || return 1
	[ -n "$wle" ] && echo "$wle" > "$ZRAM_SYS/writeback_limit_enable" 2>/dev/null
	[ -n "$wl" ] && echo "$wl" > "$ZRAM_SYS/writeback_limit" 2>/dev/null
	mkswap "$ZRAM_DEV" >/dev/null 2>&1 || return 1
	swapon "$ZRAM_DEV" 2>/dev/null || return 1
	return 0
}

if [ "$ZRAM" = 1 ] && [ -e "$ZRAM_SYS/comp_algorithm" ]; then
	# 正常情况下 PerfInit 已按 perfinit.conf 覆盖里的算法初始化好 zram，这里只核对
	i=0
	while [ "$(cat "$ZRAM_SYS/initstate" 2>/dev/null)" != 1 ] && [ $i -lt 60 ]; do
		sleep 1; i=$((i + 1))
	done
	log "zram: $(zram_state)"
	case "$(cat "$ZRAM_SYS/comp_algorithm")" in
		*"[$ZRAM_ALGO]"*) log "zram already $ZRAM_ALGO" ;;
		*)
			if ! has_algo "$ZRAM_ALGO"; then
				log "zram: $ZRAM_ALGO not registered in /proc/crypto"
			elif [ "$(cat "$ZRAM_SYS/initstate" 2>/dev/null)" != 1 ]; then
				# 系统没有初始化 zram，直接按配置初始化
				echo "$ZRAM_ALGO" > "$ZRAM_SYS/comp_algorithm" && echo "$ZRAM_SIZE" > "$ZRAM_SYS/disksize" \
					&& mkswap "$ZRAM_DEV" >/dev/null 2>&1 && swapon "$ZRAM_DEV" 2>/dev/null \
					&& log "zram: initialized $(zram_state)" || log "zram: init failed"
			elif [ "$ZRAM_FORCE" != 1 ]; then
				log "zram: perfinit.conf override not effective, leave as is (ZRAM_FORCE=1 to reinit)"
			else
				used=$(awk '$1 ~ /zram0/ {print $4}' /proc/swaps 2>/dev/null)
				used=${used:-0}
				if [ "$used" -gt 65536 ]; then
					log "zram swap in use ($used KB), skip reinit"
				elif reinit_zram "$ZRAM_ALGO"; then
					log "zram: reinit $(zram_state)"
				else
					log "zram: reinit failed $(zram_state)"
				fi
			fi
			;;
	esac
fi

# 为下次开机更新 perfinit.conf 覆盖（WebUI 改了算法或开关后生效）
sh "$MODDIR/zram_conf.sh" "$MODDIR"

if [ "$DAMON" = 1 ] && [ -e /sys/module/damon_reclaim/parameters/enabled ]; then
	echo 100 > /sys/module/damon_reclaim/parameters/wmarks_high
	echo 50 > /sys/module/damon_reclaim/parameters/wmarks_mid
	echo 20 > /sys/module/damon_reclaim/parameters/wmarks_low
	echo Y > /sys/module/damon_reclaim/parameters/enabled
	log "damon reclaim enabled"
fi
