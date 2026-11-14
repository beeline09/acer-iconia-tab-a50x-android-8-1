#!/bin/bash
# Подготовка дерева AOSP android-8.1.0_r81 для picasso (A500/A501) — Oreo 8.1 (Go, low_ram)
# Отличия от 7.1.2-версии (setup.sh):
#   - патчи платформы 8.1 применяются здесь (patches-*.patch против чистого android-8.1.0_r81)
#   - hardware/libhardware_legacy НЕ раскладывается (в 8.1 он в манифесте, pristine;
#     wifi_set_mode сейчас — заглушка в wifi-jni, этап wifi-HIDL отложен)
#   - aosp-gaps НЕ нужны: манифест 8.1 полный (проверено, 590 проектов)
# Запускать ИЗ КОРНЯ ДЕРЕВА AOSP:  /path/to/repo-81/setup-81.sh
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AOSP_ROOT="$(pwd)"

echo "=== picasso-8.1 setup: AOSP=$AOSP_ROOT, repo=$SCRIPT_DIR ==="
[ -d "$AOSP_ROOT/build/make" ] || { echo "FATAL: запустите из корня AOSP 8.1 (build/make)"; exit 1; }

# 1. Ядро: prebuilt (собирается отдельно arm-eabi-4.8, вне AOSP)
rm -rf kernel/acer/picasso
if [ -f "$SCRIPT_DIR/kernel/acer/picasso/zImage-final" ]; then
  cp "$SCRIPT_DIR/kernel/acer/picasso/zImage-final" "$SCRIPT_DIR/device/acer/picasso/kernel"
  echo "  kernel: zImage-final подложен"
else
  echo "  WARN: zImage-final не найден — соберите: kernel build.sh (см. README)"
fi

# 2. hardware: broadcom (bcmdhd) — только он; libhardware_legacy остаётся pristine из манифеста
mkdir -p hardware
rm -rf hardware/broadcom
cp -a "$SCRIPT_DIR/hardware/broadcom" hardware/

# 3. Device trees (наши: picasso + p4-common, обновлены под 8.1: PLAT_PRIVATE sepolicy,
#    TARGET_NO_RECOVERY, jemalloc+SVELTE, camera off, libstagefrighthw+liblog, egl.cfg COPY)
mkdir -p device/acer device/samsung vendor/acer
rm -rf device/acer/picasso device/samsung/p4-common
cp -a "$SCRIPT_DIR/device/acer/picasso" device/acer/
cp -a "$SCRIPT_DIR/device/samsung/p4-common" device/samsung/

# 4. Патчи платформы 8.1: ПОЛНЫЕ git-binary diff (pristine r81 -> рабочее дерево;
#    untracked-файлы включены через add -N). Каталоги с git clean -x ПЕРЕД применением —
#    внутренние .gitignore могут прятать файлы (см. README 7.1.2).
shopt -s nullglob
for patchfile in "$SCRIPT_DIR"/patches/*.patch; do
  base=$(basename "$patchfile" .patch | sed 's/^patches-//')
  echo "--- patch: $base"
  git clean -qfdx -- "$base" 2>/dev/null || true
  if (cd "$AOSP_ROOT" && git apply --binary --check "$patchfile" 2>/dev/null); then
    (cd "$AOSP_ROOT" && git apply --binary "$patchfile")
  elif (cd "$AOSP_ROOT" && git apply --binary --reverse --check "$patchfile" 2>/dev/null); then
    echo "    уже применён — пропуск"
  else
    echo "FATAL: $base не применился (нужно чистое дерево android-8.1.0_r81)"
    exit 1
  fi
done

# 5. webview: AOSP chromium-webview конфликтует с vendor/decatf — убрать
if [ -d external/chromium-webview ]; then
  rm -rf external/chromium-webview
  echo "  chromium-webview: удалён (замена — vendor/decatf/webview)"
fi

# 6. vendor: decatf (webview, Launcher3, busybox, addon.d; overlay без LOS-массивов)
rm -rf vendor/decatf
cp -a "$SCRIPT_DIR/vendor/decatf" vendor/

# 7. Browser: наше приложение (7.1-эра, работает на 8.1)
mkdir -p packages/apps
rm -rf packages/apps/Browser
cp -a "$SCRIPT_DIR/packages/apps/Browser" packages/apps/

# 8. Блобы Acer: проверить (извлекаются extract-blobs.sh с устройства/эталона)
if [ ! -d vendor/acer/picasso/proprietary ]; then
  echo "  ВНИМАНИЕ: нет vendor/acer/picasso/proprietary (блобы) — extract-blobs.sh"
fi

# 9. Проверка
ok=1
[ -f device/acer/picasso/AndroidProducts.mk ] && echo "AndroidProducts.mk OK" || ok=0
[ -f device/samsung/p4-common/p4-common.mk ] && echo "p4-common.mk OK" || ok=0
grep -q TARGET_PREBUILT_KERNEL device/acer/picasso/BoardConfig.mk && echo "PREBUILT_KERNEL OK" || ok=0
grep -q ro.config.low_ram device/acer/picasso/picasso.mk && echo "low_ram(Go) OK" || ok=0
[ $ok = 1 ] && echo "=== SETUP-81 OK ===" || { echo "SETUP_FAILED"; exit 1; }
