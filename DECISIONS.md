# Журнал решений порта 8.1 (frameworks/base и др.) — НЕ ОТКАТЫВАТЬ зафиксированное

## ЗАФИКСИРОВАНО (работает, не трогать):
- bionic: strcmp→cortex-a15 (10 вариантов bp), hosts_cache (wildcard), paths.h BSHELL2, линкер (shim/non-PIE/textrel/env), Android.bp линкера (include+NON_PIE+Os)
- build/make: Makefile theirs+cmdline fix (строка 628), armv7-a.mk OURS (vfpv3-d16!), core.mk Browser+PrintService, остальное theirs
- system: reboot.cpp (Tegra TurnOff*), fs_config init.d, cryptfs null-fix, vold theirs
- sepolicy: private-append (7 файлов), PLAT_PRIVATE_DIRS (BoardConfig), theme-типы в p4-common/file.te, interfacer.te в p4-common, crash_dump/tombstoned замены, seapp interfacer в device
- native: LOS15.1 (SF.cpp/h/mk/_hwc1 + gui 4), hwc1+hwrotation, DisplayDevice НАШ (FNW!), FNW.cpp в libui bp, eglApi WORKAROUND в getNativePixelFormat + cflags в bp libEGL (cc_library_shared!), RenderEngine pristine, opengl mk theirs
- bootanimation: наш BootAnimation.cpp/h (ES2+gles1_compat+scratchTex+THEME+keepMap), mk: gles1 в libbootanimation, rc: ioprio rt, h: include gles1_compat.h (не gl.h!)
- base: Zygote TCG (JAUNT_LIB+2 функции+вызовы после NativeBridgeAvailable), ActivityThread без THEME_FONT, ColorUtil→findContrastColorAgainstDark, StorageManager pristine-хвост, PMS без disabledComponents
- wifi: setMode native+JNI заглушка+SM вызовы; wifi-jni server=false НЕТ (~/.jack убран, сервер жив под юнитом jack-server! SERVER_HOST=localhost ОБЯЗАТЕЛЬНО)
- device: camera.tegra ВЫКЛ (юзер), gpsd.te удалён, libgui_shim ВЫКЛ (mk.disabled), LD_SHIM без nvwinsys/камер, egl.cfg PRODUCT_COPY_FILES, MALLOC_IMPL снесён (jemalloc+SVELTE)
- overlays: decatf overlay без disabledComponents-массивов

## 14.11 ~01:20 КЛАСС-ЗАЧИСТКА:
- services/core/java ЦЕЛИКОМ pristine (LOS-фичи: advanced reboot, темы-idmap, shortcut-дубли, clipboard-guard — НЕ picasso-критично)
- frameworks/opt/telephony ЦЕЛИКОМ pristine (наш STK/RIL-бэкпорт ждёт методов из откаченных файлов; телефония-этап отложен, как камера/GPS)
- frameworks/av ЦЕЛИКОМ pristine (наши хвосты GraphicBufferSource/EffectBundle; NEON-замены кодеков — оптимизация, не критично; вернуть при желании отдельным этапом)
- prebuilts python2.7.5: zlib.so скопирован из prebuilts/gdb (32-бит модуль отсутствовал; Ubuntu 22 x64, lib32z1 уже стоял)
- prebuilt python2.7.5 (32-бит, без zlib) -> обёртки bin/python2(.7) ведут на системный /usr/bin/python2.7 (64-бит, gzip OK); ELFCLASS64-модуль удалён
- TARGET_NO_RECOVERY := true (recovery.img не строится: CWM отдельно; mkbootimg падал на ramdisk-recovery)
- packages/apps+providers: все M-файлы -> pristine (Settings/Bluetooth/PackageInstaller LOS-хвосты); наши ?? каталоги (Browser/ThemeInterfacer/ExactCalculator) остаются

## ★ ФИНАЛ 14.11.2026 02:32 — MAKE_RC=0
- 81 итерация. system.img 488МБ, boot.img 4.9МБ (prebuilt zImage + 8.1 ramdisk)
- Последний класс: packages/apps M-файлы → pristine по-репо + untracked LOS-хвосты (projekt_*, dashboard_*) удалены; ExactCalculator = НАШ из эталона (сток конфликтует с overlay); Browser DataUri → android.util.Base64
- update-api выполнен (stopWifiDriver и пр. вычищены из api txt)
