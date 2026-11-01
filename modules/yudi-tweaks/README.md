# yudi-tweaks

自编译内核功能的运行时开关和状态页。内核保持原厂默认值，本模块在开机时按配置打开所选的功能。le9uo 是例外：它在内核里默认就是开启的，关闭开关时模块会把它关掉。

设置通过 KernelSU 管理器里的 WebUI 修改，保存在 `/data/adb/yudi-tweaks.conf`，一般在重启后生效。

## 开关

| 开关 | 默认 | 作用 |
| --- | --- | --- |
| sysctl 上限 | 开 | 提高 `max_map_count` 和 inotify 的上限，满足容器和 Wine 的需要 |
| BBRv3 | 开 | 拥塞控制改为 BBRv3 |
| le9uo | 开 | 内存回收时保护文件缓存 |
| zram 算法 | 开，lz4kd | 让系统用所选算法初始化 zram |
| 强制重新初始化 zram | 关 | 上一项没有生效时的备用方案，见下文 |
| 加载月亮内存模块 | 关 | 关闭时阻止移植包里的第三方内存模块加载，见下文 |
| KSM | 关 | 合并内容相同的内存页 |
| ADIOS | 关 | IO 调度器改为 ADIOS |
| DAMON_RECLAIM | 关 | 主动回收长时间未访问的内存 |
| 空闲调度器 | 跟随系统 | 可选 TEO 或厂商的 qcom-cpu-lpm |
| MFZ 白名单 | 开 | 往小米内存冻结的名单里加应用，见下文 |
| 实验调参 | 全关 | 一组运行时参数，见下文 |

空闲调度器在 WebUI 保存时立即切换，重启后再按配置应用一次。选「跟随系统」时模块不做任何修改。

WebUI 里还显示 CPU 配额（Droidspaces 的 `--cpus`）是否可用。这个功能由内核的 CFS 带宽提供，模块没有对应的开关。

## zram 算法

小米的 PerfInit（`/system_ext/xbin/system_perf_init`）在开机早期读取 `/system_ext/etc/perfinit.conf` 里的 `comp_algo` 来初始化 zram，并在设置容量之前挂上内存扩展（ExtM）的写回设备。

模块在安装时和每次开机早期复制这份配置，只把 `comp_algo` 换成所选的算法，再覆盖原文件。PerfInit 于是直接用所选算法初始化 zram，写回设备也保持不变。所选算法必须已经在 `/proc/crypto` 里注册，否则模块不做覆盖。开机后 `service.sh` 只核对并记录算法、容量和写回设备。

如果覆盖没有生效，可以打开「强制重新初始化 zram」。模块会先 `swapoff` 再重置 zram，在设置容量之前恢复原来的写回设备和写回额度，容量沿用系统的设置。已经使用的 swap 超过 64 MB 时，模块跳过这一步，避免卡顿。

## 第三方内存模块

HyperOS 移植包在 `/vendor/etc/moon_modules/` 里带有 4 个闭源的内存模块（moon_kshrink_lruvecd、moon_look_around、moon_mapped_protect、moon_binder），由 vendor 的 `init.qti.kernel.rc` 在开机后期加载，与内核无关。它们的作用和 le9uo、Kcompressd 重叠，所以模块默认阻止它们加载：用空文件覆盖这些 `.ko`。覆盖生效之前的那一次开机，`service.sh` 会在开机完成后卸载已经加载的模块。打开「加载月亮内存模块」可以恢复原样。

## MFZ 白名单

小米的内存冻结只处理名单里的应用。应用被冻结后，系统按它占用的内存分三档处理：超过 2 GB 压缩，超过 3 GB 写回闪存，超过 4 GB 结束进程。它不是保活开关：普通的小应用加进名单后基本没有变化；占用 2 到 4 GB 的游戏或大应用，更有可能在后台留住。

WebUI 可以勾选已安装的第三方应用，也可以手动输入包名，保存后重启生效。名单写到两处，因为不同的内存冻结实现读取的位置不同：

- `/data/system/mfz.xml`：系统原有名单加上你选的应用。如果这个文件被系统或云控改过，其中的应用会保留并合并进来。
- 模块里覆盖 `/product/etc/mfz.xml` 的文件：以原文件为底本，保留其中的其他配置，只在末尾追加你选的应用，并带一行 `yudi-tweaks mfz overlay` 注释作标记。

系统原有的名单在开机早期从原始的 `/product/etc/mfz.xml` 读取，保存为 `mfz_base.txt` 和 `mfz_product_orig.xml`，升级模块时沿用。读不到原文件时，用内置的 7 个游戏作为原有名单。

关闭这个开关时，模块只删除自己写的文件；`/data/system/mfz.xml` 如果被系统改过，就保留不动。

## 实验调参

这些开关只修改运行时参数，不改内核，默认全部关闭，打开后重启生效。建议一次只打开一项，并做 8 小时的待机对比。

| 开关 | 写入 |
| --- | --- |
| `VM_STAT` | `vm.stat_interval=10` |
| `TCP_IDLE` | `net.ipv4.tcp_slow_start_after_idle=0` |
| `TCP_FASTOPEN` | `net.ipv4.tcp_fastopen=3` |
| `F2FS_FSYNC` | 所有 f2fs 分区的 `min_fsync_blocks=20` |
| `VM_WMARK` | `vm.watermark_boost_factor=0` |
| `VM_PAGECLUSTER` | `vm.page-cluster=0` |
| `IO_IOSTATS` | 所有 `sd*` 设备的 `queue/iostats=0` |
| `F2FS_GC_URGENT` | 所有 f2fs 分区的 `gc_urgent_sleep_time=50` |
| `TCP_ECN` | `net.ipv4.tcp_ecn=1` |
| `RCU_LAZY` | `rcutree.enable_rcu_lazy=1` |

`IO_IOSTATS` 会让 `/proc/diskstats` 的统计不再准确。`TCP_ECN` 在个别网络设备上可能出问题。

`RCU_LAZY` 打开内核的 RCU 惰性回调，需要内核支持。它在保存后立即写入内核参数，便于做对比测试。这是实验功能，打开前先做挂起唤醒和网络开关的测试。

待机对比的做法：

```sh
dumpsys batterystats --reset
# 全部关闭作为基线：熄屏，拔掉充电线和 USB，等 8 小时
dumpsys batterystats --charged | head -60
# 打开要测的那一项，重启，再重复一次
```

## 验证

```sh
cat /proc/sys/vm/max_map_count                  # 1048576
cat /proc/sys/fs/inotify/max_user_watches       # 524288
cat /proc/sys/fs/inotify/max_user_instances     # 1024
cat /proc/sys/net/ipv4/tcp_congestion_control   # bbr3
cat /proc/sys/vm/workingset_protection          # 1
cat /sys/block/zram0/comp_algorithm             # 方括号里是 lz4kd
su -c 'cat /data/system/mfz.xml'
cat /sys/module/rcutree/parameters/enable_rcu_lazy
```

注释里是默认设置下的期望值。装有 Droidspaces 时，可以再运行 `su -c '/data/local/Droidspaces/bin/droidspaces check'`，确认 CPU 配额可用。
