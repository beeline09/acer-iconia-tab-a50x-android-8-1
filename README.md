# acer-iconia-tab-a50x-android-8-1

Порт **Android 8.1.0 (Oreo, Go-профиль)** на Acer Iconia Tab A500/A501 (picasso,
NVIDIA Tegra 2, armv7 **без NEON**, 1 ГБ RAM). Система собирается зелёной
(`make -j` → system.img 488 МБ + boot.img), ядро 3.8.13.28 — общее с портом 7.1.2.

Родственное репо (7.1.2, ядро и механика CWM): `beeline09/acer-iconia-tab-a50x-android-7-1-2`.
Порт 8.1 получен из него переносом правок на `android-8.1.0_r81` (ночь 13–14.11.2026,
81 итерация сборки; полный журнал решений — в `DECISIONS.md`).

## Состав репозитория

| Каталог/файл | Что это |
|---|---|
| `kernel/acer/picasso` | ядро 3.8.13.28 (то же, что 7.1.2: Thor/digetx + UID-routing + SELinux + seccomp), `./build.sh` → `zImage-final` (склейка zImage+DTB) |
| `device/acer/picasso`, `device/samsung/p4-common` | device trees, **обновлённые под 8.1**: `BOARD_PLAT_PRIVATE_SEPOLICY_DIRS`, `TARGET_NO_RECOVERY`, jemalloc+`MALLOC_SVELTE` (dlmalloc в 8.1 удалён), камера/GPS выключены (этапы), libstagefrighthw+liblog, egl.cfg через PRODUCT_COPY_FILES, LD_SHIM без nvwinsys/камер |
| `patches/patches-*.patch` | ПОЛНЫЕ git-binary diff чистого `android-8.1.0_r81` → рабочее дерево по 7 проектам: bionic, build, frameworks-base, frameworks-native, wifi (opt/net/wifi), system-core, system-sepolicy. Untracked-файлы включены (add -N) |
| `packages/apps/Browser` | браузер из 7.1 (исправлен: `android.util.Base64` вместо libcore) |
| `vendor/decatf` | открытые компоненты: webview (54 МБ, non-NEON), Launcher3, busybox, addon.d; overlay почищен от LOS-массивов |
| `hardware/broadcom` | bcmdhd (Wi-Fi/BT драйверы) |
| `tools/` | `make-full-zip.py` (CWM-zip), update-binary (edify ELF), neon_check, fixperms |
| `setup-81.sh` | раскладка device/vendor/Browser + применение патчей на чистое дерево 8.1 |
| `build-all-81.sh` | полный конвейер: ядро → хост-фиксы → setup → make → cacerts → CWM-zip |
| `DECISIONS.md` | пофайловый журнал всех решений порта (читать первым!) |
| `extract-blobs.sh` | выгрузка проприетарных блобов NVIDIA/Broadcom с устройства |

## Быстрый старт

```bash
repo init -u https://android.googlesource.com/platform/manifest -b android-8.1.0_r81
repo sync -j4 --no-clone-bundle          # -j4! Google отдаёт 429 на -j20
git clone https://github.com/beeline09/acer-iconia-tab-a50x-android-8-1.git
cd acer-iconia-tab-a50x-android-8-1
./build-all-81.sh ~/aosp                  # → picasso-81-a50x-full.zip
```

Блобы: `adb` с рабочей системы (или из репо 7.1.2) → `./extract-blobs.sh`.
JDK8 обязателен (`~/jdk8-old`), ccache рекомендован.

## Почему 8.1 — потолок для этого железа (исследование 13.11)

- **NEON отсутствует** (Tegra 2): Chromium/WebView навсегда старые (наш webview-54);
  **с Android 12 платформенный Rust хардкодит NEON** на armv7 — 12+ не собирается в принципе.
- Android 9/P возможен, но HWC1-адаптер в 9-м мёртв, а все NVIDIA-блобы — hwc1.
- 10/11 доказаны на 3.4-ядрах с NEON — не наш случай.
- 8.1 Go (`ro.config.low_ram=true` + `MALLOC_SVELTE`) —官方 таргет для 512МБ–1ГБ.

## Ключевые технические решения порта (выжимка, детали в DECISIONS.md)

- **bionic**: неоновые `strcmp.S` (cortex-a9/krait/kryo — все 10 arm-вариантов bp) заменены
  на наш cortex-a15 (vfpv3-d16); `hosts_cache` (DNS-кеш) подхватывается wildcard'ом
  `dns/**/*.c`; `dlmalloc` УДАЛЁН (в 8.1 его нет) → jemalloc+svelte.
- **Линкер**: перенесены 5 механизмов 7.1 на 8.1-структуру (linker.cpp разбит на модули):
  `LD_SHIM_LIBS` (5 shim'ов NVIDIA-блобов, в т.ч. через header-шаблон linker_soinfo.h),
  non-PIE `R_ARM_COPY`, textrel-разрешение, env LD_SHIM_LIBS (linker_main.cpp), vi-scope.
- **Графика**: LOS 15.1 SurfaceFlinger_hwc1 (+наш `ro.sf.hwrotation`), НАШ DisplayDevice
  (FramebufferNativeWindow!), `FramebufferNativeWindow.cpp` в libui (+include gralloc.h
  и nativewindow для system/window.h 8.1), `WORKAROUND_BUG_10194508` в
  `getNativePixelFormat` (eglApi.cpp) + cflags в Android.bp libEGL.
- **bootanimation**: наш BootAnimation.cpp/h на базе 8.1: ES2-контекст + gles1_compat
  (Tegra не даёт ES1), decode-on-the-fly (carveout-killer workaround), theme-zip,
  `ioprio rt 4` в rc; gles1_compat.cpp в libbootanimation + libGLESv2.
- **Zygote**: TCG-preload (EnableTcg/PreloadTcg + JAUNT_LIB) — перенесён точно.
- **sepolicy 8.1**: device-политика через `BOARD_PLAT_PRIVATE_SEPOLICY_DIRS` (иначе не видны
  platform-домены: wpa/system_server!); `debuggerd`→`crash_dump`/`tombstoned`;
  theme/ics-типы объявлены в device file.te; interfacer.te живёт в device-наборе.
- **Отложенные этапы** (работает без них): Wi-Fi (8.1 = HIDL supplicant/wifi@1.0 — нужен
  shim над bcmdhd; сейчас `setMode`-заглушка в JNI), BT stray-bytes (HCI-слой переписан),
  камера, GPS (gpsd.te удалён), телефония/STK (telephony pristine).

## Хост-грабли (Ubuntu 22.04/WSL2 — собрано и задокументировано!)

1. **Jack**: сервер поднимается ТОЛЬКО с `SERVER_HOST=localhost` в `~/.jack-settings`
   (сертификат CN=localhost — 127.0.0.1 ломает TLS-аутентикацию!); все файлы
   `~/.jack-server` — права 600 (иначе «invalid permissions» и вечный auth-fail);
   `~/.jack {'server':false}` НЕ отключает setup-jack-server; в WSL Jack живёт только
   под systemd-юнитом (процессы вне юнитов умирают с ssh-сессией).
2. **prebuilt python2.7.5** — 32-бит и БЕЗ zlib-модуля (build_image.py падает на import gzip):
   build-all-81 сам ставит обёртки на системный `/usr/bin/python2.7`; lib32z1 в систему.
3. `LOCAL_CLANG := false` запрещён в 8.1; комментарии внутри `\`-continuation списков
   Android.mk = «missing separator» (ловили 3 раза!).
4. После правок public API — `make update-api`, иначе apicheck валит сборку.
5. `TARGET_NO_RECOVERY := true` — recovery.img не строим (CWM живёт отдельно).
6. repo sync «успешно» пропускает проекты только в старых манифестах; манифест 8.1 полный
   (590 проектов проверены), aosp-gaps 7.1-эры НЕ нужны.

## CWM-zip (старое TegraOwners recovery) — правила 7.1.2 неизменны

python-zipfile (flags 0x0), БЕЗ подписи, update-binary ПЕРВЫМ, порядок:
update-binary → boot.img → fixperms → updater-script → system/**; на планшет —
`/sdcard/0/Download/`. Разделы: boot p2 (8МБ), system p3 (600МБ), boot2 p7 (10МБ —
тестовый слот!), data p8.

## Статус (14.11.2026)

- ✅ Сборка зелёная: system.img 488 МБ + boot.img 5.1 МБ (81 итерация)
- ⏳ CWM-zip — финальная упаковка (tools/make-full-zip.py)
- ⏳ Живой тест на устройстве (второй слот boot2) — ближайшие дни
- ⏳ Этапы: Wi-Fi HIDL-shim (bcmdhd), BT stray-bytes, камера, GPS, телефония/STK

## Лицензии/блобы

Проприетарные блобы (NVIDIA/Broadcom) в репо НЕ входят — `extract-blobs.sh`.
Всё остальное — Apache 2.0 (AOSP) + наши правки в духе репо 7.1.2.
