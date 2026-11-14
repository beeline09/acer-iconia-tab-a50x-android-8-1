# Журнал технических решений — порт Android 8.1 для picasso

Постатейное обоснование всех патчей платформы и изменений device tree.
Читать перед модификацией любого файла из списка ниже.

## bionic

- `libc/Android.bp`: все 10 блоков ARM-вариантов — пути `strcmp.S` заменены
  `cortex-a9/krait/kryo` → `cortex-a15` (реализация без NEON)
- `libc/arch-arm/generic/bionic/memchr.S`: НОВЫЙ — замена без NEON
- `libc/dns/net/hosts_cache.{c,h}`: НОВЫЙ — DNS-кеш (подхватывается wildcard `dns/**/*.c`)
- `libc/dns/net/getaddrinfo.c`: подключение к hosts_cache
- `libc/include/paths.h`: `_PATH_BSHELL2 = "/sbin/sh"` (совместимость со старыми бинарями)
- `linker/linker.cpp`: инфраструктура `LD_SHIM_LIBS`, non-PIE `R_ARM_COPY`,
  разрешение textrel (старые блобы NVIDIA)
- `linker/linker_main.cpp`: парсинг env `LD_SHIM_LIBS`
- `linker/linker_soinfo.h`: декларация `for_each_matching_shim()` (безопасный шаблон)
- `linker/linker_non_pie.{cpp,h}`: НОВЫЙ — поддержка non-PIE
- `linker/Android.bp`: cflag `ENABLE_NON_PIE_SUPPORT`, `-Os` для ARM,
  include `device/samsung/p4-common/include` для non-PIE заголовка
- `Android.mk` (корень): удалён — 8.1 использует только Android.bp

## build/make

- `core/combo/arch/arm/armv7-a.mk`: `ARCH_ARM_HAVE_NEON` пусто,
  `-mcpu=cortex-a9 -mfpu=vfpv3-d16` (таргет Tegra 2)
- `core/Makefile`: `INTERNAL_KERNEL_CMDLINE` без `buildvariant` (CWM-прошивка
  не требует его, экономит место в cmdline)
- `target/product/core.mk`: `Browser` (наше приложение) вместо `Browser2`,
  добавлен `BuiltInPrintService`
- `core/combo/select.mk`: возвращён к стоку (BOARD_GLOBAL_CFLAGS не используется)

## frameworks/base

- `cmds/bootanimation/BootAnimation.{cpp,h}`: GLES 2.0-контекст (драйвер Tegra 2
  не создаёт ES 1.x), эмуляция fixed-function через `gles1_compat`,
  decode-on-the-fly (защита GPU carveout), поддержка тем bootanimation,
  `initTexture(keepMap)`
- `cmds/bootanimation/gles1_compat.{cpp,h}`: НОВЫЙ — шим GLES1-на-GLES2
  (textured-quad shader, glDrawTexiOES, texEnv REPLACE)
- `cmds/bootanimation/Android.mk`: `gles1_compat.cpp` в libbootanimation,
  `libGLESv2` в shared libraries
- `cmds/bootanimation/bootanim.rc`: `ioprio rt 4` (real-time I/O для page-ins)
- `core/jni/com_android_internal_os_Zygote.cpp`: `EnableTcg`/`PreloadTcg`
  (предзагрузка libjaunt для управления GPU carveout не-system-server процессов)
- `core/java/android/app/ActivityThread.java`: удалён `CONFIG_THEME_FONT`
  (LOS theme font — неприменимо на AOSP 8.1)
- `core/res`: удалены ресурсы `reboot_*`, `ic_lock_power_reboot`,
  `shutdown_reboot_options/actions` (advanced reboot — LOS-фича, не перенесена)

## frameworks/native

- `services/surfaceflinger/SurfaceFlinger_hwc1.cpp`: LineageOS 15.1 HWC1
  реализация + `ro.sf.hwrotation` в `getDisplayInfo()` (90/270° swap w/h)
- `services/surfaceflinger/SurfaceFlinger.{cpp,h}`: LineageOS 15.1 (путь HWC2,
  не компилируется при TARGET_USES_HWC2=false)
- `services/surfaceflinger/Android.mk`: LineageOS 15.1 (выбор модуля,
  libbfqio удалена)
- `services/surfaceflinger/DisplayDevice.cpp`: НАША версия с
  `EGL_NEEDS_FNW` (FramebufferNativeWindow) + `ro.sf.hwrotation`
- `libs/ui/FramebufferNativeWindow.cpp` + `include/ui/FramebufferNativeWindow.h`:
  НОВЫЙ — прямой доступ к framebuffer без gralloc-аллокаций
- `libs/ui/Android.bp`: FNW.cpp в srcs, include для gralloc.h + window.h
- `opengl/libs/EGL/eglApi.cpp`: `WORKAROUND_BUG_10194508` в
  `getNativePixelFormat()` (драйвер Tegra 2 сообщает корректный формат через
  `EGL_NATIVE_VISUAL_ID`)
- `opengl/libs/Android.bp`: `-DWORKAROUND_BUG_10194508=1` в cflags libEGL

## frameworks/opt/net/wifi

- `WifiNative.java`: декларация native `setMode()` (заглушка)
- `WifiStateMachine.java`: вызовы `setMode(0)`/`setMode(1)` для переключения STA/AP
- `jni/com_android_server_wifi_WifiNative.cpp`: JNI-заглушка `setMode`
  (возвращает JNI_TRUE — полный HIDL-шим поверх bcmdhd в планах)

## system/core

- `init/reboot.cpp`: `TurnOffWifiAndHotplugCpu()` — выгрузка модуля dhd +
  CPU governor на 1 ГГц + отключение cpu1 перед ребутом (стабильность Tegra 2)
- `libcutils/fs_config.cpp`: права `system/etc/init.d/*` (00755)
- `vold/cryptfs.cpp`: null-проверка `fstab_rec` в `isConvertibleToFBE()`

## system/sepolicy

- `private/app.te`: права чтения theme_data_file
- `private/untrusted_app.te`: kernel module_request
- `private/domain.te`: исключения ics_blob_file убраны (обрабатывается в device policy)
- `public/service.te`: объявление типа `interfacer_service`
- `public/property.te`: объявление типа `theme_prop`

## device/samsung/p4-common

- `BoardConfigCommon.mk`: `BOARD_PLAT_PRIVATE_SEPOLICY_DIRS` (device-политика
  объединена с platform private — требуется для видимости legacy-доменов),
  `TARGET_NO_RECOVERY=true`, `MALLOC_SVELTE=true` (урезанный jemalloc),
  удалён `MALLOC_IMPL=dlmalloc` (недоступен в 8.1)
- `sepolicy/`: `crash_dump`/`tombstoned` заменили `debuggerd`,
  `theme.te` + `interfacer.te` (device-side), `file.te`: объявления типов
  `ics_blob_file`, `theme_data_file`, `gpsd.te` удалён
- `libstagefrighthw/Android.mk`: добавлена `liblog` (строгая линковка 8.1)
- `libshims/gui/Android.mk.disabled`: libgui_shim отключён (SurfaceComposerClient
  на 1005 строк требует адаптации к 8.1 API)
- `rootdir/etc/init.p3.rc`: удалена пара `libnvwinsys.so|libgui_shim.so` из
  LD_SHIM_LIBS
- `p4-common.mk`: `camera.tegra` закомментирована, `egl.cfg` через PRODUCT_COPY_FILES

## Известные ограничения

- Wi-Fi: `setMode` — заглушка; полная поддержка 8.1 требует HIDL wifi@1.0
  реализацию поверх bcmdhd
- Bluetooth: обход мусорных байтов BCM4329 не перенесён (HCI-слой переписан)
- Камера: HAL `camera.tegra` отключена (включить + починить CameraWrapper)
- GPS: gpsd.te удалён (включить + починить домен)
- Телефония/STK: стоковый AOSP (бэкпорт Samsung STK из 7.1 не перенесён)
