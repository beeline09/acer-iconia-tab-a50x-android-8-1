# Linux Kernel 3.8.13.28 для Acer Iconia Tab A500/A501 (picasso, Tegra 2)

База: [ThinkTwice](https://github.com/ThinkTwice) (Thor), [digetx](https://github.com/digetx) — TegraOwners 3.8.13.28

Android 7.1.2 Nougat на планшете 2011 года с NVIDIA Tegra 2.

## Что здесь особенного

- **UID-routing бэкпорт** (коммит `d1bf7205`) — netd 7.1 использует FRA_UID_START/END (ядро 3.14+), без этого нет интернета
- **Без eMMC-задержки** (коммит `a615aefe`) — убрана диагностическая пауза 6 секунд
- **Полный .config** (коммит `3c9dc265`) — picasso_a501_71_defconfig со всеми нужными опциями
- **SELinux + seccomp** — обязательны для init 7.1 (без SELinux → recovery loop)

## Сборка

### Требования

- Linux x86_64 (Ubuntu 20.04+, WSL2 ок)
- **arm-eabi-gcc 4.8** (НЕ 4.9 — раздувает ядро за лимит загрузчика)
- Пакеты: `git bc bison flex build-essential`

### Быстрая сборка

```bash
git clone https://github.com/beeline09/picasso-android-kernel
cd picasso-android-kernel

# Тулчейн
git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-eabi-4.8 ~/toolchain
export PATH=~/toolchain/bin:$PATH

./build.sh
```

### Ручная сборка

```bash
export ARCH=arm CROSS_COMPILE=arm-eabi-
export KBUILD_BUILD_USER=$USER KBUILD_BUILD_HOST=$(hostname)

# Хост-инструменты уже включены (фикс GCC 10+)
chmod +x scripts/dtc/dtc scripts/mod/modpost scripts/basic/fixdep \
  scripts/sortextable scripts/selinux/genheaders/genheaders \
  scripts/selinux/mdp/mdp scripts/conmakehash scripts/kallsyms
find scripts \( -name "*.o" -o -name "*.tab.h" -o -name "*.tab.c" -o -name "*.lex.c" \) -exec touch {} \; 2>/dev/null

make picasso_a501_71_defconfig
make olddefconfig
make -j$(nproc) zImage dtbs

# Склейка DTB (ОБЯЗАТЕЛЬНО!)
cat arch/arm/boot/zImage arch/arm/boot/dts/tegra20-picasso.dtb > zImage-final
```

### Результат

`zImage-final` — готовое ядро с device tree. **Должно быть меньше 4 032 056 байт** (лимит загрузчика Skrilax V8).

## Создание boot.img

Ядро + ramdisk = boot образ для прошивки:

```python
#!/usr/bin/env python3
import struct, sys
d = open(sys.argv[1], "rb").read()   # сток boot (dd с устройства, 8 МБ)
kz = open(sys.argv[2], "rb").read()  # zImage-final
ps = struct.unpack_from("<I", d, 36)[0]
ks, rs = struct.unpack_from("<II", d, 8)
out = bytearray(d[:ps] + kz + b"\x00" * ((-(ps+len(kz))) % ps))
roff = ps + ((ks + ps - 1)//ps)*ps
out += bytearray(d[roff:roff+rs])
struct.pack_into("<I", out, 8, len(kz))
open(sys.argv[3], "wb").write(bytes(out))
```

## Критические правила

| Правило | Почему |
|---|---|
| **Только GCC 4.8** | 4.9 раздувает +664 КБ → не влезает в лимит 4,0 МБ |
| **DTB в хвост zImage** | `cat zImage dtb.dtb` — make НЕ добавляет сам |
| **console=tty0 в cmdline** | Без него Wi-Fi BCM4329 ловит HT timeout |
| **KBUILD_BUILD_USER** | Ваше имя в `uname -a` — НЕ использовать личные данные |

## Разделы picasso

| Раздел | Размер | Назначение |
|---|---|---|
| mmcblk0p2 | 8 МБ | boot (ядро + ramdisk) |
| mmcblk0p3 | 600 МБ | system |
| mmcblk0p7 | 10 МБ | boot2 (безопасный слот для тестов) |
| mmcblk0p8 | ~57 ГБ | data |

## Прошивка

```bash
adb root
adb push new-boot.img /data/local/tmp/
adb shell 'dd if=/data/local/tmp/new-boot.img of=/dev/block/mmcblk0p2 bs=1048576 && sync'
adb shell 'dd if=/dev/block/mmcblk0p2 bs=1 count=$(stat -c%s /data/local/tmp/new-boot.img) | md5sum'
```

## Связанные репозитории

- [android_picasso](https://github.com/beeline09/android_picasso) — device trees + патчи платформы
- [magisk-picasso-noNEON](https://github.com/beeline09/magisk-picasso-noNEON) — Magisk без NEON для Tegra 2

## Благодарности

- [**ThinkTwice**](https://github.com/ThinkTwice) (Thor) — оригинальное ядро для picasso
- [**digetx**](https://github.com/digetx) (Dmitry Osipenko) — TegraOwners, база 3.8.13.28
- [**decatf**](https://github.com/decatf) — p4-common Android 7.1.2
- [**topjohnwu**](https://github.com/topjohnwu) — Magisk v31.1

## Лицензия

GPL v2 (Linux kernel). См. [COPYING](COPYING).
