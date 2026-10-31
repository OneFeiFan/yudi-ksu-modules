# yudi-ksu-modules

小米平板 6 Max（yudi）自定义 GKI 5.10 内核的 KernelSU 模块。

| 模块 | 版本 | 作用 |
| --- | --- | --- |
| `yudi-tweaks` | 1.8 | 运行时开关和状态页 |
| `ntsync` | 1.1 | 从 misc 设备创建 `/dev/ntsync` |

## yudi-tweaks

内核保持 stock 默认值，模块在开机时应用选中的设置。le9uo 是例外：内核补丁
默认开启，模块在关闭开关时写 0。

| 开关 | 默认 |
| --- | --- |
| sysctl 上限（`max_map_count`、inotify） | 开 |
| BBRv3 | 开 |
| le9uo | 开 |
| zram 使用选定算法（默认 lz4kd） | 开 |
| 强制重新初始化 zram（高级） | 关 |
| 加载月亮内存模块（高级） | 关（默认屏蔽） |
| KSM | 关 |
| ADIOS 调度器 | 关 |
| DAMON_RECLAIM | 关 |
| cpuidle governor（跟随系统 / TEO / qcom-cpu-lpm） | 跟随系统 |

governor 在 WebUI 保存时立即切换；重启后由模块按配置再应用。选「跟随系统」时模块
不写 governor，保持厂商默认。

CPU 限制（`Droidspaces --cpus`）来自内核的 CFS 带宽支持，WebUI 只显示状态，
模块没有对应开关。

zram 算法不再靠开机后重置切换。小米的 PerfInit（`/system_ext/xbin/system_perf_init`）
在 `load-bpf-programs` 阶段读取 `/system_ext/etc/perfinit.conf` 的 `comp_algo`
初始化 zram，并在设置容量前挂上内存扩展（ExtM）的写回设备。模块在安装时和每次
post-fs-data 阶段复制这份配置，只把 `comp_algo` 换成选定的算法，以无系统方式覆盖；
PerfInit 于是直接按该算法初始化，写回设备保留。算法必须已注册在 `/proc/crypto`，
否则不覆盖。开机后 `service.sh` 只核对并记录算法、容量和写回设备。

若覆盖没有生效，可在高级选项打开「强制重新初始化 zram」：模块会 `swapoff` +
`reset`，在设置容量之前恢复原来的写回设备和写回额度，沿用系统设的容量；swap 已用
超过 64 MB 时跳过。

移植包在 `/vendor/etc/moon_modules/` 带了 4 个闭源内存模块（moon_kshrink_lruvecd、
moon_look_around、moon_mapped_protect、moon_binder），由 vendor 的
`init.qti.kernel.rc` 在开机后期 `insmod`，与内核无关。它们和 le9uo、Kcompressd 的
目标重叠，默认屏蔽：模块用空文件覆盖这些 `.ko`，让加载失败；覆盖还没生效的那次
开机，`service.sh` 在开机完成后把已加载的卸载掉。打开「加载月亮内存模块」恢复原样。

WebUI 写入 `/data/adb/yudi-tweaks.conf`，重启后生效。KernelSU 在
`webroot/index.html` 存在时显示 WebUI。

## ntsync

从 `/sys/class/misc/ntsync/dev` 读主次设备号创建节点。minor 由内核动态分配，
不能写死。

## 安装

```sh
./scripts/package.sh
```

用 KernelSU 安装 `dist/<module>.zip`；或者在已 root 的设备上运行
`./scripts/install.sh`（走 adb + su）。

## 验证

```sh
cat /proc/sys/vm/max_map_count
cat /proc/sys/fs/inotify/max_user_watches
cat /proc/sys/fs/inotify/max_user_instances
cat /proc/sys/net/ipv4/tcp_congestion_control
cat /proc/sys/vm/workingset_protection
cat /sys/block/zram0/comp_algorithm
su -c 'cat /sys/class/misc/ntsync/dev'
ls -l /dev/ntsync
```

默认值下预期：`1048576`、`524288`、`1024`、`bbr3`、`1`、`[lz4kd]`，ntsync 的
主次设备号与 sysfs 一致。

如果设备上装了 Droidspaces，可以再跑
`su -c '/data/local/Droidspaces/bin/droidspaces check'`，确认 CPU 限制可用；
没装可以跳过。

## 内核镜像

内核发布里有两个镜像，内核相同：

- `yudi-5.10.272-<日期>-ksu.img`：带 KernelSU
- `yudi-5.10.272-<日期>-noroot.img`：不带 root

2026-10-29 在设备上验证：7298 个导出符号、CRC 差异 0；vendor_boot 355 个、
vendor_dlkm 315 个模块，失败 0；加载 420 个模块；NTSync 11/11、futex_waitv
7/7、epoll 63/63。

源码与补丁：<https://github.com/OneFeiFan/gki-kernel-5.10-xiaomi-pad6max>

## License

GPL-2.0，见 `LICENSE`。
