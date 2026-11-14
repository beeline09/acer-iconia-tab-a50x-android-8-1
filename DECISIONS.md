# Technical Decision Log — Android 8.1 Port for picasso

Per-file rationale for all platform patches and device tree changes.
Read this before modifying any file listed below.

## bionic

- `libc/Android.bp`: all 10 ARM variant blocks — `strcmp.S` paths replaced
  `cortex-a9/krait/kryo` → `cortex-a15` (no-NEON implementation)
- `libc/arch-arm/generic/bionic/memchr.S`: NEW — no-NEON replacement
- `libc/dns/net/hosts_cache.{c,h}`: NEW — DNS hosts cache (picked up by `dns/**/*.c` wildcard)
- `libc/dns/net/getaddrinfo.c`: hook into hosts_cache
- `libc/include/paths.h`: `_PATH_BSHELL2 = "/sbin/sh"` (legacy binary compat)
- `linker/linker.cpp`: `LD_SHIM_LIBS` infrastructure, non-PIE `R_ARM_COPY`,
  textrel permission (old NVIDIA blobs)
- `linker/linker_main.cpp`: `LD_SHIM_LIBS` env parsing
- `linker/linker_soinfo.h`: `for_each_matching_shim()` declaration (template-safe)
- `linker/linker_non_pie.{cpp,h}`: NEW — non-PIE support
- `linker/Android.bp`: `ENABLE_NON_PIE_SUPPORT` cflag, `-Os` for ARM,
  `device/samsung/p4-common/include` for non-PIE header
- `Android.mk` (root): removed — 8.1 uses Android.bp exclusively

## build/make

- `core/combo/arch/arm/armv7-a.mk`: `ARCH_ARM_HAVE_NEON` empty,
  `-mcpu=cortex-a9 -mfpu=vfpv3-d16` (Tegra 2 target)
- `core/Makefile`: `INTERNAL_KERNEL_CMDLINE` without `buildvariant` (CWM flash
  doesn't need it, saves cmdline space)
- `target/product/core.mk`: `Browser` (our app) instead of `Browser2`,
  added `BuiltInPrintService`
- `core/combo/select.mk`: reverted to stock (BOARD_GLOBAL_CFLAGS unused)

## frameworks/base

- `cmds/bootanimation/BootAnimation.{cpp,h}`: GLES 2.0 context (Tegra 2 driver
  can't create ES 1.x), `gles1_compat` fixed-function emulation, decode-on-the-fly
  (GPU carveout protection), theme bootanimation support, `initTexture(keepMap)`
- `cmds/bootanimation/gles1_compat.{cpp,h}`: NEW — GLES1-on-GLES2 shim
  (textured-quad shader, glDrawTexiOES, texEnv REPLACE)
- `cmds/bootanimation/Android.mk`: `gles1_compat.cpp` in libbootanimation,
  `libGLESv2` added to shared libraries
- `cmds/bootanimation/bootanim.rc`: `ioprio rt 4` (real-time I/O for page-ins)
- `core/jni/com_android_internal_os_Zygote.cpp`: `EnableTcg`/`PreloadTcg`
  (libjaunt GPU carveout preload for non-system-server processes)
- `core/java/android/app/ActivityThread.java`: removed `CONFIG_THEME_FONT`
  (LOS theme font — not applicable on AOSP 8.1)
- `core/res`: removed `reboot_*` resources, `ic_lock_power_reboot`,
  `shutdown_reboot_options/actions` (advanced reboot — LOS feature, not ported)

## frameworks/native

- `services/surfaceflinger/SurfaceFlinger_hwc1.cpp`: LineageOS 15.1 HWC1
  implementation + `ro.sf.hwrotation` in `getDisplayInfo()` (90/270° swap w/h)
- `services/surfaceflinger/SurfaceFlinger.{cpp,h}`: LineageOS 15.1 (HWC2 path,
  not compiled when TARGET_USES_HWC2=false)
- `services/surfaceflinger/Android.mk`: LineageOS 15.1 (module selection,
  libbfqio removed)
- `services/surfaceflinger/DisplayDevice.cpp`: OUR custom version with
  `EGL_NEEDS_FNW` (FramebufferNativeWindow) + `ro.sf.hwrotation`
- `libs/ui/FramebufferNativeWindow.cpp` + `include/ui/FramebufferNativeWindow.h`:
  NEW — direct framebuffer access without gralloc allocations
- `libs/ui/Android.bp`: FNW.cpp in srcs, include dirs for gralloc.h + window.h
- `opengl/libs/EGL/eglApi.cpp`: `WORKAROUND_BUG_10194508` in
  `getNativePixelFormat()` (Tegra 2 driver reports correct format via
  `EGL_NATIVE_VISUAL_ID`)
- `opengl/libs/Android.bp`: `-DWORKAROUND_BUG_10194508=1` in libEGL cflags

## frameworks/opt/net/wifi

- `WifiNative.java`: `setMode()` native declaration (stub)
- `WifiStateMachine.java`: `setMode(0)`/`setMode(1)` calls for STA/AP mode switch
- `jni/com_android_server_wifi_WifiNative.cpp`: `setMode` JNI stub (returns
  JNI_TRUE — full HIDL shim over bcmdhd pending)

## system/core

- `init/reboot.cpp`: `TurnOffWifiAndHotplugCpu()` — unload dhd module + CPU
  governor to 1 GHz + cpu1 offline before reboot (Tegra 2 stability)
- `libcutils/fs_config.cpp`: `system/etc/init.d/*` permissions (00755)
- `vold/cryptfs.cpp`: null-check for `fstab_rec` in `isConvertibleToFBE()`

## system/sepolicy

- `private/app.te`: theme_data_file read permissions
- `private/untrusted_app.te`: kernel module_request
- `private/domain.te`: removed ics_blob_file exceptions (handled in device policy)
- `public/service.te`: `interfacer_service` type declaration
- `public/property.te`: `theme_prop` type declaration

## device/samsung/p4-common

- `BoardConfigCommon.mk`: `BOARD_PLAT_PRIVATE_SEPOLICY_DIRS` (device policy
  merged into platform private — required for legacy domain visibility),
  `TARGET_NO_RECOVERY=true`, `MALLOC_SVELTE=true` (jemalloc trimmed),
  removed `MALLOC_IMPL=dlmalloc` (not available in 8.1)
- `sepolicy/`: `crash_dump`/`tombstoned` replaced `debuggerd`,
  `theme.te` + `interfacer.te` (device-side), `file.te`: `ics_blob_file`,
  `theme_data_file` type declarations, `gpsd.te` removed
- `libstagefrighthw/Android.mk`: `liblog` added (8.1 strict linking)
- `libshims/gui/Android.mk.disabled`: libgui_shim disabled (1005-line
  SurfaceComposerClient needs 8.1 API adaptation)
- `rootdir/etc/init.p3.rc`: removed `libnvwinsys.so|libgui_shim.so` from
  LD_SHIM_LIBS
- `p4-common.mk`: `camera.tegra` commented out, `egl.cfg` via PRODUCT_COPY_FILES

## Known limitations

- Wi-Fi: `setMode` is a stub; full 8.1 stack requires HIDL wifi@1.0
  implementation over bcmdhd
- Bluetooth: BCM4329 stray-byte workaround not ported (HCI layer rewritten)
- Camera: `camera.tegra` HAL disabled (re-enable + fix CameraWrapper)
- GPS: gpsd.te removed (re-enable + fix domain)
- Telephony/STK: pristine AOSP (Samsung STK backport from 7.1 not yet ported)
