#!/system/bin/sh
# NULL-safe string guard for ICS tegra blobs + SF-owned software vsync
export LD_PRELOAD=/system/lib/libnullguard.so
setprop debug.sf.no_hw_vsync 1
exec /system/bin/surfaceflinger
