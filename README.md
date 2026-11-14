# Android 8.1 Oreo (Go edition) для Acer Iconia Tab A500/A501

Кастомная прошивка на базе AOSP `android-8.1.0_r81` для Acer Iconia Tab A500/A501
(кодовое имя **picasso**, NVIDIA Tegra 2 T250, двухъядерный Cortex-A9, 1 ГБ RAM, без NEON).

Ядро 3.8.13.28 (общее с [портом 7.1.2](https://github.com/beeline09/acer-iconia-tab-a50x-android-7-1-2)).

## Возможности

- Android 8.1.0 с оптимизациями Go edition (`ro.config.low_ram=true`, `MALLOC_SVELTE`)
- Работающая графика: собственный `FramebufferNativeWindow` + LineageOS HWC1 SurfaceFlinger
- GLES2-контекст с уровнем совместимости GLES1 (bootanimation, SurfaceFlinger)
- Поддержка `LD_SHIM_LIBS` в линкере для старых блобов NVIDIA/Broadcom
- Поддержка non-PIE исполняемых файлов в линкере bionic (блобы эпохи ICS)
- DNS-кеш в bionic (`hosts_cache` — ускорение разрешения имён)
- Реализации `strcmp`/`memchr` без NEON (Tegra 2 не имеет NEON)
- Bootanimation с поддержкой тем (`/data/system/theme/bootanimation.zip`)
- TCG-предзагрузка в Zygote (libjaunt для управления GPU carveout)
- 206 CA-сертификатов (обновлённый root store)

## Не работает (пока)

| Функция | Статус | Примечания |
|---|---|---|
| Wi-Fi | Частично | Заглушка `wifi_set_mode`; нужен HIDL-шим поверх bcmdhd |
| Bluetooth | Частично | HCI-слой переписан в 8.1; обход мусорных байтов BCM4329 не перенесён |
| Камера | Отключена | Модуль `camera.tegra` исключён (можно включить) |
| GPS | Отключён | `gpsd.te` удалён (можно включить) |
| Телефония/STK | Стоковый AOSP | Бэкпорт Samsung STK из 7.1 не перенесён |

## Состав репозитория

| Путь | Описание |
|---|---|
| `kernel/acer/picasso/` | Исходники ядра Linux 3.8.13.28 + `build.sh` |
| `device/acer/picasso/` | Device tree (AndroidProducts, BoardConfig, init.rc, fstab) |
| `device/samsung/p4-common/` | Общий device tree (sepolicy, шимы, аудио, bootanimation) |
| `patches/` | Патчи платформы (полные git-binary diff относительно чистого `android-8.1.0_r81`) |
| `packages/apps/Browser/` | Браузер из 7.1 (исправлен для 8.1: `android.util.Base64`) |
| `vendor/decatf/` | Открытые компоненты (WebView, Launcher3, busybox, addon.d) |
| `hardware/broadcom/` | Драйверы Wi-Fi/Bluetooth Broadcom (bcmdhd) |
| `tools/` | Инструменты сборки (make-full-zip.py, update-binary, neon_check, fixperms) |
| `setup-81.sh` | Подготовка чистого дерева AOSP (патчи + device/vendor) |
| `build-all-81.sh` | Полный конвейер сборки (ядро → setup → make → CWM zip) |
| `extract-blobs.sh` | Извлечение проприетарных блобов NVIDIA/Broadcom с устройства |
| `DECISIONS.md` | Технический журнал решений (обоснование каждого патча) |

## Сборка

### Требования

- Ubuntu 20.04/22.04 (или WSL2), ~250 ГБ диска, 16+ ГБ RAM
- JDK 8 (`~/jdk8-old` или аналогичный)
- Пакет `lib32z1` (`sudo apt install lib32z1`)
- `ccache` (рекомендуется)

### Шаги

```bash
# 1. Синхронизация AOSP (только -j4, Google отдаёт 429 на больших значениях)
mkdir -p ~/aosp && cd ~/aosp
repo init -u https://android.googlesource.com/platform/manifest -b android-8.1.0_r81
repo sync -j4 --no-clone-bundle

# 2. Клонирование репозитория
git clone https://github.com/beeline09/acer-iconia-tab-a50x-android-8-1.git
cd acer-iconia-tab-a50x-android-8-1

# 3. Извлечение блобов (с работающего устройства с root, или из репо 7.1.2)
./extract-blobs.sh

# 4. Полная сборка
./build-all-81.sh ~/aosp    # → picasso-81-a50x-full.zip
```

### Извлечение блобов

Если есть устройство с прошивкой 7.1.2 и root (adb root или Magisk):

```bash
adb root
./extract-blobs.sh
```

Блобы НЕ входят в репозиторий (проприетарные NVIDIA/Broadcom).

## Патчи платформы

Семь файлов в `patches/`, применяются `setup-81.sh` к чистому дереву `android-8.1.0_r81`:

| Патч | Проекты | Ключевые изменения |
|---|---|---|
| `patches-bionic.patch` | bionic | strcmp без NEON (10 ARM-вариантов → cortex-a15), hosts_cache, `LD_SHIM_LIBS` + non-PIE + textrel в линкере, `_PATH_BSHELL2` |
| `patches-build.patch` | build/make | `armv7-a.mk`: vfpv3-d16 + cortex-a9 (без NEON), cmdline без buildvariant |
| `patches-frameworks-base.patch` | frameworks/base | Bootanimation (GLES2 + gles1_compat + decode-on-the-fly + темы), TCG-предзагрузка в Zygote, EGL-воркараунд `WORKAROUND_BUG_10194508` |
| `patches-frameworks-native.patch` | frameworks/native | HWC1 SurfaceFlinger (LineageOS), `FramebufferNativeWindow` в libui, `ro.sf.hwrotation` |
| `patches-system-core.patch` | system/core | Tegra-последовательность перезагрузки (выгрузка Wi-Fi + CPU governor), права `init.d`, null-фикс в cryptfs |
| `patches-system-sepolicy.patch` | system/sepolicy | Типы theme-overlay, домен `interfacer`, `crash_dump`/`tombstoned` (замена `debuggerd`) |
| `patches-wifi.patch` | frameworks/opt/net/wifi | JNI-заглушка `setMode` (полный HIDL-шим в планах) |

Подробное обоснование по каждому файлу — в `DECISIONS.md`.

## Особенности хост-окружения (Ubuntu 22.04 / WSL2)

1. **Jack-компилятор**: `SERVER_HOST` должен оставаться `localhost` в `~/.jack-settings`
   (несоответствие CN TLS-сертификата на 127.0.0.1). Все файлы в `~/.jack-server`
   требуют `chmod 600`. В WSL2 Jack-сервер выживает только под systemd user unit.
2. **Prebuilt Python 2.7** (32-бит, без zlib): `build-all-81.sh` автоматически
   устанавливает обёртки на системный `python2.7`.
3. **Android.mk**: комментарии внутри continuation-списков (`\`) вызывают
   ошибку "missing separator" — держите комментарии снаружи.
4. **Изменения public API**: после правок запускать `make update-api`,
   иначе `apicheck` валит сборку.
5. `repo sync -j4` только (429 rate limits от Google при большем параллелизме).

## CWM-прошивка

Выходной zip (`picasso-81-a50x-full.zip`) совместим со старым
TegraOwners CWM recovery:

- Python zipfile, general-purpose flags = 0x0 (без data-descriptor)
- Без подписи (CERT.RSA вызывает ошибку проверки CWM)
- `update-binary` (edify ELF) первой записью
- Путь на устройстве: `/sdcard/0/Download/`

## Разделы устройства

| Раздел | Размер | Назначение |
|---|---|---|
| `mmcblk0p2` | 8 МБ | boot (ядро + ramdisk) |
| `mmcblk0p3` | 600 МБ | system |
| `mmcblk0p7` | 10 МБ | boot2 (второй слот для тестов) |
| `mmcblk0p8` | ~57 ГБ | data |

Bootmenu (Skrilax V8) запоминает выбранный слот — возвращайте первый
вручную после тестирования.

## Почему Android 8.1 — потолок для Tegra 2

- **Нет NEON**: Chromium/WebView навсегда остаются на v54; платформенный Rust
  (Android 12+) требует NEON для armv7 — не собирается
- **HWC1**: блобы NVIDIA поддерживают только HWC1; путь HWC1-адаптера мёртв с Android 9+
- **1 ГБ RAM**: Go edition ориентирован на 512 МБ–1 ГБ; даже Go на 10+ работает плохо
- Android 9 теоретически возможен, но проблемы с HWC1-адаптером делают его непрактичным

## Связанные репозитории

- [acer-iconia-tab-a50x-android-7-1-2](https://github.com/beeline09/acer-iconia-tab-a50x-android-7-1-2) — Android 7.1.2 (общее ядро)
- [magisk-picasso-noNEON](https://github.com/beeline09/magisk-picasso-noNEON) — Magisk v31.1 без NEON

## Лицензия

Apache 2.0 (AOSP). Проприетарные блобы не входят — используйте `extract-blobs.sh`.
