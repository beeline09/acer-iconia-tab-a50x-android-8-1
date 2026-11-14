# Local path
LOCAL_PATH := device/acer/picasso

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/fstab.picasso:root/fstab.picasso

PRODUCT_PROPERTY_OVERRIDES += \
    ro.carrier=wifi-only \
    ro.hardware=picasso

# Phase 1b-3: ramdisk init files, wifi nvram, touch idc
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init.picasso.rc:root/init.picasso.rc \
    $(LOCAL_PATH)/rootdir/etc/init.picasso.usb.rc:root/init.picasso.usb.rc \
    $(LOCAL_PATH)/rootdir/etc/ueventd.picasso.rc:root/ueventd.picasso.rc \
    $(LOCAL_PATH)/wifi/bcm4329.cal:system/etc/wifi/bcm4329.cal \
    $(LOCAL_PATH)/idc/atmel-maxtouch.idc:system/usr/idc/atmel-maxtouch.idc

# Wi-Fi firmware is a device-extracted Broadcom blob (not distributable in trees).
# Drop fw_bcm4329.bin into device/acer/picasso/wifi/ (adb pull from the old ROM)
# and it gets installed automatically.
ifneq (,$(wildcard $(LOCAL_PATH)/wifi/fw_bcm4329.bin))
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/wifi/fw_bcm4329.bin:system/etc/firmware/fw_bcm4329.bin
endif

# Phase 2 (from live device): wifi fw/nvram/BT, keylayout, terminal, adb over network
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/wifi/fw_bcmdhd.bin:system/vendor/firmware/fw_bcmdhd.bin \
    $(LOCAL_PATH)/wifi/fw_bcmdhd_apsta.bin:system/vendor/firmware/fw_bcmdhd_apsta.bin \
    $(LOCAL_PATH)/wifi/bcm4329.hcd:system/etc/firmware/bcm4329.hcd \
    $(LOCAL_PATH)/keylayout/gpio-keys.kl:system/usr/keylayout/gpio-keys.kl

# Root terminal on device (userdebug su) and network adb (USB port is dead)
PRODUCT_PACKAGES += Terminal
PRODUCT_PROPERTY_OVERRIDES += persist.adb.tcp.port=5555

# Variant A (decatf p4 mirror): single-origin NVIDIA graphics stack (vendor/samsung/p4)
PRODUCT_COPY_FILES += \
    vendor/acer/picasso/proprietary/lib/hw/hwcomposer.tegra_v0.so:system/lib/hw/hwcomposer.tegra_v0.so \
    vendor/acer/picasso/proprietary/lib/hw/gralloc.tegra.so:system/lib/hw/gralloc.tegra.so \
    vendor/acer/picasso/proprietary/lib/hw/gralloc.tegra.so:system/lib/hw/gralloc.picasso.so
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += ro.adb.secure=0
PRODUCT_PROPERTY_OVERRIDES += ro.zygote.disable_gl_preload=true

# tegraowners glv copies (interposer dlopen targets)
PRODUCT_COPY_FILES += \
    vendor/acer/picasso/proprietary/lib/glv2tegra.so:system/lib/glv2tegra.so \
    vendor/acer/picasso/proprietary/lib/glv1tegra.so:system/lib/glv1tegra.so

# SF sh-wrapper: env guard + software vsync (init strips env from services)
PRODUCT_COPY_FILES += device/acer/picasso/scripts/sf.sh:system/etc/sf.sh
PRODUCT_COPY_FILES += device/acer/picasso/picasso-wifi.rc:system/etc/init/picasso-wifi.rc

# PICASSO: boot visuals - static logo written to the framebuffer a few seconds
# into boot (before SurfaceFlinger), then the GLES2 boot animation. The
# picasso-splash.rc also switches the eMMC to cfq (I/O priorities for the
# boot animation, see bootanim.rc).
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/bootanimation/bootanimation.zip:system/media/bootanimation.zip \
    $(LOCAL_PATH)/bootanimation/splash.raw:system/media/splash.raw \
    $(LOCAL_PATH)/scripts/picasso-splash.sh:system/bin/picasso-splash.sh \
    $(LOCAL_PATH)/rootdir/etc/init/picasso-splash.rc:system/etc/init/picasso-splash.rc

# PICASSO: periodic TRIM of /data and /cache (stock MountServiceIdler needs
# charging + deviceIdle, which an always-on device never reaches).
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/scripts/picasso-fstrim.sh:system/bin/picasso-fstrim.sh \
    $(LOCAL_PATH)/rootdir/etc/init/picasso-fstrim.rc:system/etc/init/picasso-fstrim.rc

# PICASSO: NULL-safe str* guard, preloaded into every process via
# init.environ.rc (system/core) - workaround for the ICS-era tegra blobs.
PRODUCT_PACKAGES += libnullguard

# PICASSO: 256 MB zram swap
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init/zram.rc:system/etc/init/zram.rc \
    $(LOCAL_PATH)/scripts/zram.sh:system/etc/zram.sh

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/cacerts/01419da9.0:system/etc/security/cacerts/01419da9.0 \
    $(LOCAL_PATH)/cacerts/04f60c28.0:system/etc/security/cacerts/04f60c28.0 \
    $(LOCAL_PATH)/cacerts/068570d1.0:system/etc/security/cacerts/068570d1.0 \
    $(LOCAL_PATH)/cacerts/073bfcc5.0:system/etc/security/cacerts/073bfcc5.0 \
    $(LOCAL_PATH)/cacerts/0d69c7e1.0:system/etc/security/cacerts/0d69c7e1.0 \
    $(LOCAL_PATH)/cacerts/128f4b91.0:system/etc/security/cacerts/128f4b91.0 \
    $(LOCAL_PATH)/cacerts/1ae85e5e.0:system/etc/security/cacerts/1ae85e5e.0 \
    $(LOCAL_PATH)/cacerts/1b0f7e5c.0:system/etc/security/cacerts/1b0f7e5c.0 \
    $(LOCAL_PATH)/cacerts/1ec40989.0:system/etc/security/cacerts/1ec40989.0 \
    $(LOCAL_PATH)/cacerts/219d9499.0:system/etc/security/cacerts/219d9499.0 \
    $(LOCAL_PATH)/cacerts/23f4c490.0:system/etc/security/cacerts/23f4c490.0 \
    $(LOCAL_PATH)/cacerts/252252d2.0:system/etc/security/cacerts/252252d2.0 \
    $(LOCAL_PATH)/cacerts/2add47b6.0:system/etc/security/cacerts/2add47b6.0 \
    $(LOCAL_PATH)/cacerts/2c63f966.0:system/etc/security/cacerts/2c63f966.0 \
    $(LOCAL_PATH)/cacerts/2d21b73c.0:system/etc/security/cacerts/2d21b73c.0 \
    $(LOCAL_PATH)/cacerts/302904dd.0:system/etc/security/cacerts/302904dd.0 \
    $(LOCAL_PATH)/cacerts/304d27c3.0:system/etc/security/cacerts/304d27c3.0 \
    $(LOCAL_PATH)/cacerts/31188b5e.0:system/etc/security/cacerts/31188b5e.0 \
    $(LOCAL_PATH)/cacerts/33ee480d.0:system/etc/security/cacerts/33ee480d.0 \
    $(LOCAL_PATH)/cacerts/34d996fb.0:system/etc/security/cacerts/34d996fb.0 \
    $(LOCAL_PATH)/cacerts/3afde786.0:system/etc/security/cacerts/3afde786.0 \
    $(LOCAL_PATH)/cacerts/3c899c73.0:system/etc/security/cacerts/3c899c73.0 \
    $(LOCAL_PATH)/cacerts/41a3f684.0:system/etc/security/cacerts/41a3f684.0 \
    $(LOCAL_PATH)/cacerts/47b283f6.0:system/etc/security/cacerts/47b283f6.0 \
    $(LOCAL_PATH)/cacerts/4c3982f2.0:system/etc/security/cacerts/4c3982f2.0 \
    $(LOCAL_PATH)/cacerts/53a1b57a.0:system/etc/security/cacerts/53a1b57a.0 \
    $(LOCAL_PATH)/cacerts/583d0756.0:system/etc/security/cacerts/583d0756.0 \
    $(LOCAL_PATH)/cacerts/595e996b.0:system/etc/security/cacerts/595e996b.0 \
    $(LOCAL_PATH)/cacerts/5acf816d.0:system/etc/security/cacerts/5acf816d.0 \
    $(LOCAL_PATH)/cacerts/5d139d02.0:system/etc/security/cacerts/5d139d02.0 \
    $(LOCAL_PATH)/cacerts/5f9a69fa.0:system/etc/security/cacerts/5f9a69fa.0 \
    $(LOCAL_PATH)/cacerts/5fdd185d.0:system/etc/security/cacerts/5fdd185d.0 \
    $(LOCAL_PATH)/cacerts/6b03dec0.0:system/etc/security/cacerts/6b03dec0.0 \
    $(LOCAL_PATH)/cacerts/6b483515.0:system/etc/security/cacerts/6b483515.0 \
    $(LOCAL_PATH)/cacerts/7892ad52.0:system/etc/security/cacerts/7892ad52.0 \
    $(LOCAL_PATH)/cacerts/7a7c655d.0:system/etc/security/cacerts/7a7c655d.0 \
    $(LOCAL_PATH)/cacerts/7a819ef2.0:system/etc/security/cacerts/7a819ef2.0 \
    $(LOCAL_PATH)/cacerts/7e067d03.0:system/etc/security/cacerts/7e067d03.0 \
    $(LOCAL_PATH)/cacerts/83e9984f.0:system/etc/security/cacerts/83e9984f.0 \
    $(LOCAL_PATH)/cacerts/869fbf79.0:system/etc/security/cacerts/869fbf79.0 \
    $(LOCAL_PATH)/cacerts/8761519c.0:system/etc/security/cacerts/8761519c.0 \
    $(LOCAL_PATH)/cacerts/8794b4e3.0:system/etc/security/cacerts/8794b4e3.0 \
    $(LOCAL_PATH)/cacerts/88950faa.0:system/etc/security/cacerts/88950faa.0 \
    $(LOCAL_PATH)/cacerts/89c02a45.0:system/etc/security/cacerts/89c02a45.0 \
    $(LOCAL_PATH)/cacerts/8ca696b9.0:system/etc/security/cacerts/8ca696b9.0 \
    $(LOCAL_PATH)/cacerts/8d10a21f.0:system/etc/security/cacerts/8d10a21f.0 \
    $(LOCAL_PATH)/cacerts/8f6cd7bb.0:system/etc/security/cacerts/8f6cd7bb.0 \
    $(LOCAL_PATH)/cacerts/9339512a.0:system/etc/security/cacerts/9339512a.0 \
    $(LOCAL_PATH)/cacerts/93851c9e.0:system/etc/security/cacerts/93851c9e.0 \
    $(LOCAL_PATH)/cacerts/9479c8c3.0:system/etc/security/cacerts/9479c8c3.0 \
    $(LOCAL_PATH)/cacerts/9591a472.0:system/etc/security/cacerts/9591a472.0 \
    $(LOCAL_PATH)/cacerts/985c1f52.0:system/etc/security/cacerts/985c1f52.0 \
    $(LOCAL_PATH)/cacerts/98aaf404.0:system/etc/security/cacerts/98aaf404.0 \
    $(LOCAL_PATH)/cacerts/99e1b953.0:system/etc/security/cacerts/99e1b953.0 \
    $(LOCAL_PATH)/cacerts/9aef356c.0:system/etc/security/cacerts/9aef356c.0 \
    $(LOCAL_PATH)/cacerts/a716d4ed.0:system/etc/security/cacerts/a716d4ed.0 \
    $(LOCAL_PATH)/cacerts/a9d40e02.0:system/etc/security/cacerts/a9d40e02.0 \
    $(LOCAL_PATH)/cacerts/ab59055e.0:system/etc/security/cacerts/ab59055e.0 \
    $(LOCAL_PATH)/cacerts/b30d5fda.0:system/etc/security/cacerts/b30d5fda.0 \
    $(LOCAL_PATH)/cacerts/b3fb433b.0:system/etc/security/cacerts/b3fb433b.0 \
    $(LOCAL_PATH)/cacerts/b74d2bd5.0:system/etc/security/cacerts/b74d2bd5.0 \
    $(LOCAL_PATH)/cacerts/b92fd57f.0:system/etc/security/cacerts/b92fd57f.0 \
    $(LOCAL_PATH)/cacerts/b936d1c6.0:system/etc/security/cacerts/b936d1c6.0 \
    $(LOCAL_PATH)/cacerts/bd43e1dd.0:system/etc/security/cacerts/bd43e1dd.0 \
    $(LOCAL_PATH)/cacerts/bf64f35b.0:system/etc/security/cacerts/bf64f35b.0 \
    $(LOCAL_PATH)/cacerts/c44cc0c0.0:system/etc/security/cacerts/c44cc0c0.0 \
    $(LOCAL_PATH)/cacerts/c491639e.0:system/etc/security/cacerts/c491639e.0 \
    $(LOCAL_PATH)/cacerts/c559d742.0:system/etc/security/cacerts/c559d742.0 \
    $(LOCAL_PATH)/cacerts/c7f1359b.0:system/etc/security/cacerts/c7f1359b.0 \
    $(LOCAL_PATH)/cacerts/cbb3f32b.0:system/etc/security/cacerts/cbb3f32b.0 \
    $(LOCAL_PATH)/cacerts/ccc52f49.0:system/etc/security/cacerts/ccc52f49.0 \
    $(LOCAL_PATH)/cacerts/d16a5865.0:system/etc/security/cacerts/d16a5865.0 \
    $(LOCAL_PATH)/cacerts/d39b0a2c.0:system/etc/security/cacerts/d39b0a2c.0 \
    $(LOCAL_PATH)/cacerts/d41b5e2a.0:system/etc/security/cacerts/d41b5e2a.0 \
    $(LOCAL_PATH)/cacerts/d96b65e2.0:system/etc/security/cacerts/d96b65e2.0 \
    $(LOCAL_PATH)/cacerts/da7377f6.0:system/etc/security/cacerts/da7377f6.0 \
    $(LOCAL_PATH)/cacerts/dbff3a01.0:system/etc/security/cacerts/dbff3a01.0 \
    $(LOCAL_PATH)/cacerts/e071171e.0:system/etc/security/cacerts/e071171e.0 \
    $(LOCAL_PATH)/cacerts/e13665f9.0:system/etc/security/cacerts/e13665f9.0 \
    $(LOCAL_PATH)/cacerts/e7c037b4.0:system/etc/security/cacerts/e7c037b4.0 \
    $(LOCAL_PATH)/cacerts/e7dd1bc4.0:system/etc/security/cacerts/e7dd1bc4.0 \
    $(LOCAL_PATH)/cacerts/ed39abd0.0:system/etc/security/cacerts/ed39abd0.0 \
    $(LOCAL_PATH)/cacerts/edcbddb5.0:system/etc/security/cacerts/edcbddb5.0 \
    $(LOCAL_PATH)/cacerts/ee37c333.0:system/etc/security/cacerts/ee37c333.0 \
    $(LOCAL_PATH)/cacerts/ee532fd5.0:system/etc/security/cacerts/ee532fd5.0 \
    $(LOCAL_PATH)/cacerts/f013ecaf.0:system/etc/security/cacerts/f013ecaf.0 \
    $(LOCAL_PATH)/cacerts/f058632f.0:system/etc/security/cacerts/f058632f.0 \
    $(LOCAL_PATH)/cacerts/f459871d.0:system/etc/security/cacerts/f459871d.0 \
    $(LOCAL_PATH)/cacerts/f8fc53da.0:system/etc/security/cacerts/f8fc53da.0 \
    $(LOCAL_PATH)/cacerts/fb5fa911.0:system/etc/security/cacerts/fb5fa911.0 \
    $(LOCAL_PATH)/cacerts/fd08c599.0:system/etc/security/cacerts/fd08c599.0 \
    $(LOCAL_PATH)/cacerts/fde84897.0:system/etc/security/cacerts/fde84897.0 \
    $(LOCAL_PATH)/cacerts/ffa7f1eb.0:system/etc/security/cacerts/ffa7f1eb.0
