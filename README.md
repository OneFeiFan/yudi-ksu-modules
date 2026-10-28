# yudi-ksu-modules

KernelSU modules for the Xiaomi Pad 6 Max (yudi) running the custom GKI 5.10 kernel.

These modules only change runtime settings. They do not patch or replace kernel code.

## Modules

| Module | Version | Purpose |
| --- | --- | --- |
| `yudi-tweaks` | 1.2 | WebUI for runtime toggles and kernel status: BBRv3, le9uo, zram `lz4kd`, KSM, ADIOS and DAMON; also shows the CPU limit (CFS_BANDWIDTH) and the ntsync device. |
| `ntsync` | 1.1 | Creates `/dev/ntsync` at boot for Wine/Proton using the misc device's dynamic minor. Requires `CONFIG_NTSYNC=y`. |

## Kernel

The current verified image is `boot_272_p1p2.img`: 5.10.272 + KernelSU + the kABI-safe
`CONFIG_CFS_BANDWIDTH` split + the P0/P1/P2 fixes (module CRC rejection restored, IPC
`next_id` moved out of `struct ipc_ids`, `netns_ipv4` layout pins, ntsync time namespace
and owner checks). Gates: 7298 exported symbols with 0 CRC differences; all 355
`vendor_boot` and 315 `vendor_dlkm` modules pass the CRC scan; the device boots with 420
loaded modules.

Source and patches: <https://github.com/OneFeiFan/gki-kernel-5.10-xiaomi-pad6max>

`yudi-tweaks` only works fully on this kernel; on the stock kernel it skips features that
are not compiled in.

## yudi-tweaks

Defaults are deliberately conservative:

| Toggle | Default |
| --- | --- |
| sysctl limits (`max_map_count`, inotify) | on |
| BBRv3 | on |
| le9uo | on |
| zram switch to lz4kd | on |
| KSM | off |
| ADIOS scheduler | off |
| DAMON_RECLAIM | off |

The kernel keeps its stock defaults; the module applies the selected values at boot.
le9uo is the exception: the kernel patch enables `workingset_protection=1` by default,
and the module writes 0 when the toggle is off.

CPU limits (`Droidspaces --cpus`) are a kernel capability (`CONFIG_CFS_BANDWIDTH`, kABI
split); the WebUI only reports the status, there is no module toggle.

Changing zram requires `swapoff`, `reset`, setting the algorithm and re-enabling swap.
The module skips the switch when zram swap is in use above a small threshold.

The WebUI writes `/data/adb/yudi-tweaks.conf`; changes take effect after a reboot.
KernelSU provides the WebUI entry automatically when `webroot/index.html` exists.

## ntsync

Reads `/sys/class/misc/ntsync/dev` and creates the node with the actual major:minor; the
minor is allocated by the kernel and must not be hardcoded. The yudi-tweaks WebUI also
shows the current ntsync minor.

## Install

### From a zip

```sh
./scripts/package.sh
```

Install `dist/<module>.zip` with the KernelSU app.

### From adb

```sh
./scripts/install.sh
```

The script packages the modules, installs them with `ksud module install`, and reboots.
It expects `adb` and a working `su` (KernelSU).

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
grep ntsync /proc/misc
su -c '/data/local/Droidspaces/bin/droidspaces check'
```

Expected after reboot with the defaults: `1048576`, `524288`, `1024`, `bbr3`, `1`,
`[lz4kd]`, an ntsync major:minor matching `/sys/class/misc/ntsync/dev`, and Droidspaces
reporting CPU limit support.

## Notes

- `yudi-tweaks` skips features that are not compiled in on the stock kernel.
- `ntsync` only creates the device node; the kernel must provide `CONFIG_NTSYNC=y`.
- The zram switch is intentionally conservative. If the swap device is busy, the module
  leaves the current algorithm alone.
- The WebUI reports the CPU limit from `/dev/cpuctl/cpu.cfs_quota_us` or
  `/sys/fs/cgroup/cpu.max`; it does not change cgroup settings.

## License

GPL-2.0. See `LICENSE`.
