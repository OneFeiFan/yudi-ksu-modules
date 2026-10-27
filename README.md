# yudi-ksu-modules

KernelSU modules for the Xiaomi Pad 6 Max (yudi) running the custom GKI 5.10 kernel.

These modules only change runtime settings. They do not patch or replace kernel code.

## Modules

| Module | Purpose |
| --- | --- |
| `yudi-tweaks` | WebUI for runtime toggles: BBRv3, le9uo, zram lz4kd, KSM, ADIOS and DAMON. |
| `ntsync` | Creates `/dev/ntsync` at boot for Wine/Proton. Requires `CONFIG_NTSYNC=y`. |

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
Changing zram requires `swapoff`, `reset`, setting the algorithm and re-enabling swap.
The module skips the switch when zram swap is in use above a small threshold.

The WebUI writes `/data/adb/yudi-tweaks.conf`; changes take effect after a reboot.
KernelSU provides the WebUI entry automatically when `webroot/index.html` exists.

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

The script packages the modules, installs them with `ksud module install`,
and reboots. It expects `adb` and a working `su` (KernelSU).

## Verify

```sh
cat /proc/sys/vm/max_map_count
cat /proc/sys/fs/inotify/max_user_watches
cat /proc/sys/fs/inotify/max_user_instances
cat /proc/sys/net/ipv4/tcp_congestion_control
cat /proc/sys/vm/workingset_protection
cat /sys/block/zram0/comp_algorithm
grep ntsync /proc/misc
```

Expected after reboot with the defaults: `1048576`, `524288`, `1024`, `bbr3`,
`1`, `[lz4kd]`, `127 ntsync`.

## Notes

- `yudi-tweaks` only works fully on the custom kernel; on the stock kernel it
  skips features that are not compiled in.
- `ntsync` only creates the device node. The kernel must provide `CONFIG_NTSYNC=y`.
- The zram switch is intentionally conservative. If the swap device is busy,
  the module leaves the current algorithm alone.

## License

GPL-2.0. See `LICENSE`.
