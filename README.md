# yudi-ksu-modules

小米平板 6 Max（yudi）自编译 GKI 内核的 KernelSU 模块。内核只提供功能并保持原厂默认值，这些模块负责在开机后按你的选择打开它们。

| 模块 | 版本 | 作用 |
| --- | --- | --- |
| [yudi-tweaks](modules/yudi-tweaks/README.md) | 2.3 | 内核功能的运行时开关和状态页：BBRv3、zram 算法、le9uo、KSM、ADIOS、空闲调度器、MFZ 白名单、RCU 惰性回调等 |
| [ntsync](modules/ntsync/README.md) | 1.1 | 创建 `/dev/ntsync`，供 Wine 和 Proton 使用 |

内核源码、镜像和功能说明见 [gki-kernel-5.10-xiaomi-pad6max](https://github.com/OneFeiFan/gki-kernel-5.10-xiaomi-pad6max)。

## 安装

打包所有模块：

```sh
./scripts/package.sh
```

在 KernelSU 管理器里安装 `dist/` 下对应的 zip。已经 root 且连着 adb 的设备，也可以直接运行 `./scripts/install.sh`。

## 维护

修改文档时遵守内核仓库的[写作规范](https://github.com/OneFeiFan/gki-kernel-5.10-xiaomi-pad6max/blob/pad6max/docs/writing-guide.md)。每个模块的详细说明写在它自己目录下的 README 里，这里只保留索引。

## 许可

GPL-2.0，见 [LICENSE](LICENSE)。
