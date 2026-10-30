#!/system/bin/sh

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

setup_zram() {
	algo=$1
	if ! grep -qw "$algo" "$ZRAM_SYS/comp_algorithm" 2>/dev/null; then
		algo=lz4
	fi
	echo "$algo" > "$ZRAM_SYS/comp_algorithm" || return 1
	echo "$ZRAM_SIZE" > "$ZRAM_SYS/disksize" || return 1
	mkswap "$ZRAM_DEV" >/dev/null 2>&1 || return 1
	swapon "$ZRAM_DEV" 2>/dev/null || return 1
	return 0
}

if [ "$ZRAM" = 1 ] && [ -e "$ZRAM_SYS/comp_algorithm" ]; then
	used=$(awk '$1 ~ /zram0/ {print $4}' /proc/swaps 2>/dev/null)
	used=${used:-0}
	case "$(cat "$ZRAM_SYS/comp_algorithm")" in
		*"[$ZRAM_ALGO]"*) log "zram already $ZRAM_ALGO" ;;
		*)
			if [ "$used" -gt 65536 ]; then
				log "zram swap in use ($used KB), skip switch"
			else
				swapoff "$ZRAM_DEV" 2>/dev/null
				if echo 1 > "$ZRAM_SYS/reset" 2>/dev/null; then
					if setup_zram "$ZRAM_ALGO"; then
						log "zram switched to $ZRAM_ALGO"
					else
						log "zram $ZRAM_ALGO failed, fallback lz4"
						echo 1 > "$ZRAM_SYS/reset" 2>/dev/null
						setup_zram lz4 || log "zram fallback failed"
					fi
				else
					log "zram reset failed"
				fi
			fi
			;;
	esac
fi

if [ "$DAMON" = 1 ] && [ -e /sys/module/damon_reclaim/parameters/enabled ]; then
	echo 100 > /sys/module/damon_reclaim/parameters/wmarks_high
	echo 50 > /sys/module/damon_reclaim/parameters/wmarks_mid
	echo 20 > /sys/module/damon_reclaim/parameters/wmarks_low
	echo Y > /sys/module/damon_reclaim/parameters/enabled
	log "damon reclaim enabled"
fi
