#!/usr/bin/env python3
"""CWM update-zip для picasso (старое TegraOwners CWM!).

КРИТИЧНЫЕ требования рекавери (проверено на устройстве 13.11.2026):
  - python-zipfile, general-purpose flags = 0x0 (без data-descriptor — иначе abort)
  - БЕЗ подписи (CERT.RSA заставляет CWM проверять test-keys и валит установку)
  - ОБЯЗАТЕЛЕН META-INF/com/google/android/update-binary (edify ELF: tools/update-binary)
  - updater-script: fixperms распаковывается в /tmp ПЕРЕД run_program
  - порядок записей: update-binary, boot.img, fixperms, updater-script, затем system/**

boot.img берётся ГОТОВЫЙ из out/target/product/picasso/boot.img
(build-all.sh подкладывает наш zImage-final в out до make — boot собирается с ним).
Использование: make-full-zip.py <aosp-root> <out.zip>
"""
import hashlib
import os
import sys
import zipfile

AOSP, OUT = sys.argv[1], sys.argv[2]
SRC = os.path.dirname(os.path.abspath(__file__))
SYS = os.path.join(AOSP, "out/target/product/picasso/system")
BOOT = os.path.join(AOSP, "out/target/product/picasso/boot.img")

assert os.path.isfile(BOOT), "нет boot.img в out (сборка не завершилась?)"
assert os.path.isdir(SYS), "нет system/ в out"


def add_file(z, path, arc, mode=0o644, data=None):
    zi = zipfile.ZipInfo(arc, date_time=(2009, 1, 1, 0, 0, 0))
    zi.compress_type = zipfile.ZIP_DEFLATED
    zi.external_attr = mode << 16
    if data is None:
        with open(path, "rb") as f:
            data = f.read()
    z.writestr(zi, data)


def add_tree(z, src_dir, arc_root):
    n = 0
    for root, dirs, files in os.walk(src_dir, followlinks=False):
        dirs.sort()
        for name in sorted(os.listdir(root)):
            full = os.path.join(root, name)
            rel = os.path.relpath(full, src_dir)
            if rel.startswith(".."):
                continue
            arc = arc_root + "/" + rel
            if os.path.islink(full):
                zi = zipfile.ZipInfo(arc, date_time=(2009, 1, 1, 0, 0, 0))
                zi.compress_type = zipfile.ZIP_DEFLATED
                zi.external_attr = 0o120777 << 16
                z.writestr(zi, os.readlink(full))
            elif os.path.isfile(full):
                add_file(z, full, arc)
                n += 1
    return n


z = zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED)
add_file(z, os.path.join(SRC, "update-binary"),
         "META-INF/com/google/android/update-binary", 0o755)
add_file(z, BOOT, "boot.img", 0o755)
add_file(z, os.path.join(SRC, "fixperms/fixperms.sh"), "fixperms/fixperms.sh", 0o755)
add_file(z, os.path.join(SRC, "META-INF/com/google/android/updater-script"),
         "META-INF/com/google/android/updater-script")
n = add_tree(z, SYS, "system")
z.close()
print(f"files: {n} size: {os.path.getsize(OUT)} md5: "
      f"{hashlib.md5(open(OUT,'rb').read()).hexdigest()}")
