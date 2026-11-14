#!/bin/bash
# Сборка ядра picasso для Acer Iconia Tab A500/A501 (Tegra 2)
# Перед запуском: export PATH=<arm-eabi-4.8>/bin:$PATH
set -e
echo "=== picasso kernel build ==="

# Метаданные banner (для воспроизводимости; переопределяются снаружи при желании)
export KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-beeline09}"
export KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-picasso}"
# SOURCE_DATE_EPOCH = 2026-11-12 21:06:30 MSK (deployed ядро #19):
# фиксирует __DATE__/__TIME__ всех файлов -> повторные сборки идентичны между собой
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-1794506790}"
# Байт-в-байт с планшетным ядром #19 (дополнительно):
# export KBUILD_BUILD_VERSION=19
# export KBUILD_BUILD_TIMESTAMP="Thu Nov 12 21:06:30 MSK 2026"

# Хост-инструменты включены в репо (фикс GCC 10+ yylloc)
chmod +x scripts/dtc/dtc scripts/mod/modpost scripts/basic/fixdep \
  scripts/sortextable scripts/selinux/genheaders/genheaders \
  scripts/selinux/mdp/mdp scripts/conmakehash scripts/kallsyms
find scripts \( -name "*.o" -o -name "*.tab.h" -o -name "*.tab.c" -o -name "*.lex.c" \) \
  -exec touch {} \; 2>/dev/null

# Конфигурация
make ARCH=arm picasso_a501_71_defconfig
make ARCH=arm olddefconfig

# Сборка
make ARCH=arm CROSS_COMPILE=arm-eabi- -j$(nproc) zImage dtbs

# Склейка DTB (обязательно!)
cat arch/arm/boot/zImage arch/arm/boot/dts/tegra20-picasso.dtb > zImage-final
SZ=$(stat -c%s zImage-final)
echo ""
echo "zImage+DTB: $SZ bytes (limit 4032056)"
if [ $SZ -lt 4032056 ]; then
  echo "OK — use zImage-final"
else
  echo "TOO BIG!"
  exit 1
fi
