# ntsync

创建 `/dev/ntsync` 设备节点，供 Wine 和 Proton 使用 NTSync。

内核把 NTSync 注册为 misc 设备，次设备号在开机时动态分配，不能写死。模块在开机早期读取 `/sys/class/misc/ntsync/dev` 里的主次设备号，再创建对应的节点。

验证：

```sh
su -c 'cat /sys/class/misc/ntsync/dev'
ls -l /dev/ntsync      # 主次设备号应与上一条一致
```
