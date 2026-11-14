#!/system/bin/sh
mknod /dev/zram0 b 253 0 2>/dev/null
echo $((256*1024*1024)) > /sys/block/zram0/disksize 2>/dev/null
mkswap /dev/zram0 >/dev/null 2>&1
swapon -p 3 /dev/zram0 2>/dev/null
echo 80 > /proc/sys/vm/swappiness
