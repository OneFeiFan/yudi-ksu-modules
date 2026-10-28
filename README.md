# yudi-ksu-modules

KernelSU modules for the Xiaomi Pad 6 Max (yudi) running the custom GKI 5.10
kernel.

| Module | Version | Purpose |
| --- | --- | --- |
| `yudi-tweaks` | 1.5 | Runtime toggles and a status page |
| `ntsync` | 1.1 | Creates `/dev/ntsync` from the misc device |

## yudi-tweaks

The kernel keeps stock defaults. The module applies the selected values at
boot. le9uo is the exception: the kernel patch enables it by default, and the
module writes 0 when the toggle is off.

| Toggle | Default |
| --- | --- |
| sysctl limits (`max_map_count`, inotify) | on |
| BBRv3 | on |
| le9uo | on |
| zram switch to lz4kd | on |
| KSM | off |
| ADIOS scheduler | off |
| DAMON_RECLAIM | off |

CPU limits (`Droidspaces --cpus`) come from the kernel's CFS bandwidth
support. The WebUI reports the status; there is no module toggle.

Changing the zram algorithm does `swapoff` + `reset` and re-enables swap. The
module skips the switch when zram swap is in use above a small threshold.

The WebUI writes `/data/adb/yudi-tweaks.conf`. Changes apply after a reboot.
KernelSU shows the WebUI when `webroot/index.html` exists.

## ntsync

Reads `/sys/class/misc/ntsync/dev` and creates the node with the real
major:minor. The minor is allocated by the kernel and must not be hardcoded.

## Install

```sh
./scripts/package.sh
```

Install `dist/<module>.zip` with the KernelSU app, or use `./scripts/install.sh`
with adb and a working `su`.

## Verify

```sh
cat /proc/sys/vm/max_map_count
cat /proc/sys/fs/inotify/max_user_watches
cat /proc/sys/fs/inotify/max_user_instances
cat /proc/sys/net/ipv4/tcp_congestion_control
cat /proc/sys/vm/workingset_protection
cat /sys/block/zram0/comp_algorithm
su -c 'cat /sys/class/misc/ntsync/dev'
ls -l /dev/ntsync
su -c '/data/local/Droidspaces/bin/droidspaces check'
```

Expected with the defaults: `1048576`, `524288`, `1024`, `bbr3`, `1`,
`[lz4kd]`, an ntsync major:minor matching sysfs, and Droidspaces reporting CPU
limit support.

## Kernel images

The kernel release ships two images with the same kernel:

- `yudi-5.10.272-<date>-ksu.img` — with KernelSU
- `yudi-5.10.272-<date>-noroot.img` — without root

Verified on the device: 7298 exported symbols with 0 CRC differences, 355
`vendor_boot` and 315 `vendor_dlkm` modules with 0 failures, 420 loaded modules,
NTSync v2 selftest 11/11, futex_waitv 7/7, epoll 63/63.

Source and patches: <https://github.com/OneFeiFan/gki-kernel-5.10-xiaomi-pad6max>

## License

GPL-2.0。See `LICENSE`.
