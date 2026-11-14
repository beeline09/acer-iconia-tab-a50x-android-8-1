#!/sbin/sh
find /system -type d -exec chmod 0755 {} \;
find /system -type f -exec chmod 0644 {} \;
for d in /system/bin /system/xbin /system/vendor/bin /system/etc/init.d; do
  [ -d "$d" ] && find "$d" -type f -exec chmod 0755 {} \;
done
sync
