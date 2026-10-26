# yudi-ksu-modules

KernelSU modules for the Xiaomi Pad 6 Max (yudi) running the custom GKI 5.10 kernel.

These are small user-space helpers that complement the kernel. They do not
replace or patch any kernel code.

## Modules

| Module | Purpose |
| --- | --- |
| `ntsync` | Creates `/dev/ntsync` at boot for Wine/Proton. Requires `CONFIG_NTSYNC=y`. |
| `sysctl-tune` | Raises mmap and inotify limits used by Wine, JVM applications and development containers. |

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

The script copies the modules to `/data/adb/modules/` and reboots the device.
It expects `adb` and a working `su` (KernelSU).

## Verify

```sh
cat /proc/sys/vm/max_map_count
cat /proc/sys/fs/inotify/max_user_watches
cat /proc/sys/fs/inotify/max_user_instances
grep ntsync /proc/misc
```

Expected values:

```
1048576
524288
1024
127 ntsync
```

## Uninstall

```sh
adb shell su -c 'rm -rf /data/adb/modules/sysctl-tune'
adb shell su -c 'rm -rf /data/adb/modules/ntsync'
adb reboot
```

## Notes

- `sysctl-tune` sets values in `service.sh`, so they are applied late in boot.
  Edit that file if your workload needs different limits.
- `ntsync` only creates the device node. The kernel must already provide
  `CONFIG_NTSYNC=y`; otherwise `/dev/ntsync` will exist but the driver will not.
- The scripts assume a root shell with permission to write `/proc/sys` and to
  relabel files under `/data/adb/modules/`.

## License

GPL-2.0. See `LICENSE`.
