#!/bin/bash
# ПОЛНЫЙ конвейер 8.1: ядро -> setup -> Ubuntu-22-фиксы хоста -> AOSP make -> cacerts -> CWM zip
# Запуск: ./build-all-81.sh <корень-AOSP> [выходной-zip]
# Требования: Ubuntu 20.04+/22.04, JDK8, ~250ГБ диска,Jack-заметки в README!
set -o pipefail
exec > >(tee build-all-81.log) 2>&1
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AOSP="${1:?Укажите корень AOSP, например: ./build-all-81.sh ~/aosp}"
OUTZIP="${2:-$SCRIPT_DIR/picasso-81-a50x-full.zip}"

echo "=== [$(date '+%F %T')] BUILD-ALL-81: AOSP=$AOSP ==="

# ---------- ЭТАП 0: хост-фиксы Ubuntu 22 (см. README «Хост-грабли») ----------
echo "--- [0/6] Хост-фиксы: python-обёртки + lib32z1 + jack-конфиг"
PB="$AOSP/prebuilts/python/linux-x86/2.7.5/bin"
# prebuilt python2.7.5 — 32-бит БЕЗ zlib-модуля; ведём на системный python2.7
if [ -x "$PB/python2.7.real32" ] || ! grep -q "usr/bin/python2.7" "$PB/python2.7" 2>/dev/null; then
  [ -f "$PB/python2.7" ] && mv "$PB/python2.7" "$PB/python2.7.real32"
  printf '#!/bin/bash\nexec /usr/bin/python2.7 "$@"\n' > "$PB/python2.7"; chmod +x "$PB/python2.7"
  [ -f "$PB/python2" ] && { mv "$PB/python2" "$PB/python2.real32"; printf '#!/bin/bash\nexec /usr/bin/python2.7 "$@"\n' > "$PB/python2"; chmod +x "$PB/python2"; }
  echo "  python-обёртки установлены"
fi
sudo -n apt-get install -y lib32z1 >/dev/null 2>&1 || echo "  WARN: lib32z1 не установлен (sudo без пароля?)"
# Jack: клиент ходит на localhost (сертификат CN=localhost!) — не менять на 127.0.0.1!
if [ -f ~/.jack-settings ]; then
  sed -i 's/^SERVER_HOST=.*/SERVER_HOST=localhost/' ~/.jack-settings
  find ~/.jack-server -type d -exec chmod 700 {} \; 2>/dev/null
  find ~/.jack-server -type f -exec chmod 600 {} \; 2>/dev/null
  echo "  jack-settings: SERVER_HOST=localhost + права 600"
fi

# ---------- ЭТАП 1: ядро ----------
echo "--- [1/6] Ядро (arm-eabi-4.8 из prebuilts, host-tools фикс включены)"
export PATH="$AOSP/prebuilts/gcc/linux-x86/arm/arm-eabi-4.8/bin:$PATH"
export KBUILD_BUILD_USER=beeline09 KBUILD_BUILD_HOST=picasso
export SOURCE_DATE_EPOCH=1794506790
(
  cd "$SCRIPT_DIR/kernel/acer/picasso" || exit 1
  ./build.sh || { echo FATAL_KERNEL; exit 1; }
) || { echo FATAL_KERNEL; exit 1; }
cp "$SCRIPT_DIR/kernel/acer/picasso/zImage-final" "$SCRIPT_DIR/device/acer/picasso/kernel"
ls -la "$SCRIPT_DIR/device/acer/picasso/kernel"

# ---------- ЭТАП 2: setup ----------
echo "--- [2/6] Setup дерева AOSP"
(cd "$AOSP" && bash "$SCRIPT_DIR/setup-81.sh") || { echo FATAL_SETUP; exit 1; }

# ---------- ЭТАП 3: система ----------
echo "--- [3/6] AOSP make (jdk8 + ccache)"
export JAVA_HOME="${JAVA_HOME:-$HOME/jdk8-old}"
export PATH="$JAVA_HOME/bin:$AOSP/prebuilts/python/linux-x86/2.7.5/bin:$PATH"
export USE_CCACHE=1 CCACHE_DIR="${CCACHE_DIR:-$HOME/ccache}"
(
  cd "$AOSP" || exit 1
  mkdir -p out/target/product/picasso
  cp -f device/acer/picasso/kernel out/target/product/picasso/kernel 2>/dev/null || true
  source build/envsetup.sh || exit 1
  lunch picasso-userdebug || exit 1
  make -j"$(nproc)" || exit 1
) || { echo FATAL_MAKE; exit 1; }
[ -f "$AOSP/out/target/product/picasso/system.img" ] || { echo FATAL_NO_SYSTEMIMG; exit 1; }

# ---------- ЭТАП 4: cacerts (conscrypt затирает PRODUCT_COPY_FILES) ----------
cp -f "$SCRIPT_DIR/device/acer/picasso/cacerts/"* \
      "$AOSP/out/target/product/picasso/system/etc/security/cacerts/" 2>/dev/null || true
echo "  cacerts: $(ls "$AOSP/out/target/product/picasso/system/etc/security/cacerts" | wc -l) файлов"

# ---------- ЭТАП 5: API-тексты (после правок public API) ----------
# (уже закоммичены в патчах; этап оставлен как памятка: make update-api при новых правках)

# ---------- ЭТАП 6: CWM zip ----------
echo "--- [6/6] CWM update-zip (python-zipfile, flags 0x0, update-binary)"
python3 "$SCRIPT_DIR/tools/make-full-zip.py" "$AOSP" "$SCRIPT_DIR/kernel/acer/picasso/zImage-final" "$OUTZIP" \
  || { echo FATAL_ZIP; exit 1; }

echo "=== [$(date '+%F %T')] BUILD-ALL-81 COMPLETE: $OUTZIP ==="
