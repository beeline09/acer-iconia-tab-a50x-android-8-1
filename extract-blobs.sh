#!/bin/bash
# Извлечение проприетарных блобов NVIDIA/Broadcom с устройства picasso
# Требуется: работающая система с root (adb root или Magisk)
set -e

OUT=vendor/acer/picasso/proprietary
mkdir -p $OUT/bin $OUT/lib $OUT/lib/egl $OUT/lib/hw $OUT/etc/firmware $OUT/lib/modules

echo "Извлечение блобов с устройства..."

# GPU / графика (NVIDIA)
for f in libEGL_tegra.so libGLESv1_CM_tegra.so libGLESv2_tegra.so; do
  adb pull /system/lib/egl/$f $OUT/lib/egl/ 2>/dev/null || true
done
for f in glv1tegra.so glv2tegra.so; do
  adb pull /system/lib/$f $OUT/lib/ 2>/dev/null || true
done
# gralloc
adb pull /system/lib/hw/gralloc.tegra.so $OUT/lib/hw/ 2>/dev/null || true
adb pull /system/lib/hw/lights.picasso.so $OUT/lib/hw/ 2>/dev/null || true

# Multimedia (NVIDIA nvmm)
for f in $(adb shell ls /system/lib/libnv*.so | tr -d '\r'); do
  adb pull $f $OUT/lib/ 2>/dev/null || true
done

# Firmware
for f in $(adb shell ls /system/etc/firmware/nvrm_*.bin /system/etc/firmware/nvmm_*.axf 2>/dev/null | tr -d '\r'); do
  adb pull $f $OUT/etc/firmware/ 2>/dev/null || true
done

# Wi-Fi / BT (Broadcom)
adb pull /system/vendor/firmware/fw_bcmdhd.bin $OUT/etc/firmware/ 2>/dev/null || true
adb pull /system/vendor/firmware/fw_bcmdhd_apsta.bin $OUT/etc/firmware/ 2>/dev/null || true
adb pull /system/etc/firmware/bcm4329.hcd $OUT/etc/firmware/ 2>/dev/null || true

echo ""
echo "Извлечено файлов: $(find $OUT -type f | wc -l)"
echo "Путь: $OUT"
echo ""
echo "⚠️  Эти файлы проприетарные (NVIDIA, Broadcom)."
echo "    НЕ публикуйте их в открытом репозитории."
