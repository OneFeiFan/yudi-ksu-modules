#!/system/bin/sh
# Wine/Proton and JVM workloads need a higher mmap count.
echo 1048576 > /proc/sys/vm/max_map_count

# Editors and dev containers watch many files.
echo 524288 > /proc/sys/fs/inotify/max_user_watches
echo 1024 > /proc/sys/fs/inotify/max_user_instances
