#!/system/bin/sh
# PICASSO: periodic TRIM for /data and /cache.
# The stock trim (MountServiceIdler) needs charging + deviceIdle, which an
# always-on device (e.g. a wall clock) never reaches, and without TRIM the
# old eMMC gets very slow at writing. ext4 on 3.8 forgets what it trimmed on
# every mount, so a full pass runs at most every 3 days, 5 min after boot,
# at idle I/O priority.
STAMP=/data/misc/picasso/last_fstrim
INTERVAL=259200   # 3 days
sleep 300
now=$(date +%s)
last=$(cat $STAMP 2>/dev/null || echo 0)
if [ $((now - last)) -lt $INTERVAL ]; then
    echo "picasso-fstrim: skipped (last $(( (now - last) / 3600 )) h ago)" > /dev/kmsg
    exit 0
fi
for fs in /cache /data; do
    out=$(/system/xbin/fstrim -v $fs 2>&1)
    echo "picasso-fstrim: $out" > /dev/kmsg
done
mkdir -p /data/misc/picasso
date +%s > $STAMP
