# yudi-ksu-modules

小米平板 6 Max（yudi）自定义 GKI 5.10 内核的 KernelSU 模块。

| 模块 | 版本 | 作用 |
| --- | --- | --- |
| `yudi-tweaks` | 1.5 | 运行时开关和状态页 |
| `ntsync` | 1.1 | 从 misc 设备创建 `/dev/ntsync` |

## yudi-tweaks

内核保持 stock 默认值，模块在开机时应用选中的设置。le9uo 是例外：内核补丁
默认开启，模块在关闭开关时写 0。

| 开关 | 默认 |
| --- | --- |
| sysctl 上限（`max_map_count`、inotify） | 开 |
| BBRv3 | 开 |
| le9uo | 开 |
| zram 切换到 lz4kd | 开 |
| KSM | 关 |
| ADIOS 调度器 | 关 |
| DAMON_RECLAIM | 关 |

CPU 限制（`Droidspaces --cpus`）来自内核的 CFS 带宽支持，WebUI 只显示状态，
模块没有对应开关。

切换 zram 算法会先 `swapoff` + `reset`，再重新启用 swap；swap 使用量高时跳过。

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
