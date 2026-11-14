# Android 8.1 Oreo (Go edition) for Acer Iconia Tab A500/A501

Custom ROM based on AOSP `android-8.1.0_r81` for Acer Iconia Tab A500/A501
(codename **picasso**, NVIDIA Tegra 2 T250, dual Cortex-A9, 1 GB RAM, no NEON).

Kernel 3.8.13.28 (shared with the [7.1.2 port](https://github.com/beeline09/acer-iconia-tab-a50x-android-7-1-2)).

## Features

- Android 8.1.0 with Go edition optimizations (`ro.config.low_ram=true`, `MALLOC_SVELTE`)
- Working graphics: custom `FramebufferNativeWindow` + LineageOS HWC1 SurfaceFlinger
- Tegra 2 GLES2 context with GLES1 compatibility layer (bootanimation, SurfaceFlinger)
- `LD_SHIM_LIBS` linker support for legacy NVIDIA/Broadcom blobs
- Non-PIE executable support in bionic linker (for ICS-era binaries)
- DNS hosts cache in bionic (faster resolution on slow networks)
- No-NEON `strcmp`/`memchr` implementations (Tegra 2 lacks NEON)
- Bootanimation with theme support (`/data/system/theme/bootanimation.zip`)
- TCG preload in Zygote (libjaunt for GPU carveout management)
- 206 CA certificates (updated root store)

## Not yet working

| Feature | Status | Notes |
|---|---|---|
| Wi-Fi | Partial | `wifi_set_mode` stub; needs HIDL shim over bcmdhd for full 8.1 stack |
| Bluetooth | Partial | HCI layer rewritten in 8.1; BCM4329 stray-byte workaround pending |
| Camera | Disabled | `camera.tegra` HAL module excluded (can be re-enabled) |
| GPS | Disabled | `gpsd.te` removed (can be re-enabled) |
| Telephony/STK | Stock AOSP | Samsung STK backport not yet ported |

## Repository contents

| Path | Description |
|---|---|
| `kernel/acer/picasso/` | Linux 3.8.13.28 kernel source + `build.sh` |
| `device/acer/picasso/` | Device tree (AndroidProducts, BoardConfig, init.rc, fstab, keylayouts) |
| `device/samsung/p4-common/` | Common device tree (sepolicy, shims, audio, bootanimation) |
| `patches/` | Platform patches (full git-binary diffs vs pristine `android-8.1.0_r81`) |
| `packages/apps/Browser/` | Legacy AOSP Browser (fixed for 8.1: `android.util.Base64`) |
| `vendor/decatf/` | Open-source vendor components (WebView, Launcher3, busybox, addon.d) |
| `hardware/broadcom/` | Broadcom Wi-Fi/Bluetooth drivers (bcmdhd) |
| `tools/` | Build tools (make-full-zip.py, update-binary, neon_check, fixperms) |
| `setup-81.sh` | Prepares a clean AOSP tree (applies patches, copies device/vendor) |
| `build-all-81.sh` | Full build pipeline (kernel → setup → make → CWM zip) |
| `extract-blobs.sh` | Extracts proprietary NVIDIA/Broadcom blobs from a running device |
| `DECISIONS.md` | Technical decision log (per-file rationale for all patches) |

## Building

### Prerequisites

- Ubuntu 20.04/22.04 (or WSL2), ~250 GB disk, 16+ GB RAM
- JDK 8 (`~/jdk8-old` or similar)
- `lib32z1` package (`sudo apt install lib32z1`)
- `ccache` (recommended)

### Steps

```bash
# 1. Sync AOSP (use -j4, Google returns 429 on higher)
mkdir -p ~/aosp && cd ~/aosp
repo init -u https://android.googlesource.com/platform/manifest -b android-8.1.0_r81
repo sync -j4 --no-clone-bundle

# 2. Clone this repository
git clone https://github.com/beeline09/acer-iconia-tab-a50x-android-8-1.git
cd acer-iconia-tab-a50x-android-8-1

# 3. Extract blobs (from a running device with root, or copy from 7.1.2 repo)
./extract-blobs.sh

# 4. Build everything
./build-all-81.sh ~/aosp    # → picasso-81-a50x-full.zip
```

### Extracting blobs

If you have a device running the 7.1.2 ROM with root (adb root or Magisk):

```bash
adb root
./extract-blobs.sh
```

Blobs are NOT included in this repository (NVIDIA/Broadcom proprietary).

## Platform patches

Seven patch files in `patches/`, applied by `setup-81.sh` to a clean `android-8.1.0_r81` tree:

| Patch | Projects | Key changes |
|---|---|---|
| `patches-bionic.patch` | bionic | No-NEON strcmp (all 10 ARM variants → cortex-a15), hosts_cache, `LD_SHIM_LIBS` + non-PIE + textrel in linker, `_PATH_BSHELL2` |
| `patches-build.patch` | build/make | `armv7-a.mk`: vfpv3-d16 + cortex-a9 (no NEON), kernel cmdline without buildvariant |
| `patches-frameworks-base.patch` | frameworks/base | Bootanimation (GLES2 + gles1_compat + decode-on-the-fly + theme), Zygote TCG preload, EGL workaround `WORKAROUND_BUG_10194508` |
| `patches-frameworks-native.patch` | frameworks/native | LineageOS HWC1 SurfaceFlinger, `FramebufferNativeWindow` in libui, `ro.sf.hwrotation` support |
| `patches-system-core.patch` | system/core | Tegra reboot sequence (Wi-Fi module unload + CPU governor), `init.d` permissions, null-safety fix in cryptfs |
| `patches-system-sepolicy.patch` | system/sepolicy | Theme overlay types, `interfacer` domain, `crash_dump`/`tombstoned` (replacing `debuggerd`) |
| `patches-wifi.patch` | frameworks/opt/net/wifi | `setMode` JNI stub (full HIDL shim pending) |

For detailed per-file rationale, see `DECISIONS.md`.

## Host environment notes (Ubuntu 22.04 / WSL2)

1. **Jack compiler**: `SERVER_HOST` must remain `localhost` in `~/.jack-settings`
   (TLS certificate CN mismatch on 127.0.0.1). All files in `~/.jack-server` need
   `chmod 600`. In WSL2, the Jack server only survives under a systemd user unit.
2. **Python 2.7 prebuilt** (32-bit, missing zlib): `build-all-81.sh` automatically
   installs wrapper scripts pointing to system `python2.7`.
3. **Android.mk**: inline comments inside continuation lists (`\`) cause
   "missing separator" errors — keep comments outside.
4. **Public API changes**: run `make update-api` after modifying any public API,
   otherwise `apicheck` fails the build.
5. `repo sync -j4` only (429 rate limits from Google on higher parallelism).

## CWM installation zip

The output zip (`picasso-81-a50x-full.zip`) is compatible with the old
TegraOwners CWM recovery:

- Python zipfile, general-purpose flags = 0x0 (no data-descriptor)
- Unsigned (CERT.RSA causes CWM verification failure)
- `update-binary` (edify ELF) as the first entry
- Install path on device: `/sdcard/0/Download/`

## Device partitions

| Partition | Size | Purpose |
|---|---|---|
| `mmcblk0p2` | 8 MB | boot (kernel + ramdisk) |
| `mmcblk0p3` | 600 MB | system |
| `mmcblk0p7` | 10 MB | boot2 (second slot for testing) |
| `mmcblk0p8` | ~57 GB | data |

Bootmenu (Skrilax V8) remembers the last selected slot — switch back to slot 1
manually after testing.

## Why Android 8.1 is the ceiling for Tegra 2

- **No NEON**: Chromium/WebView permanently stuck at v54; platform Rust (Android 12+)
  hardcodes NEON for armv7 — cannot compile
- **HWC1**: NVIDIA blobs are HWC1-only; the HWC1 adapter path is dead from Android 9+
- **1 GB RAM**: Go edition targets 512 MB–1 GB; even Go on 10+ struggles
- Android 9 is theoretically possible but HWC1 adapter issues make it impractical

## Related repositories

- [acer-iconia-tab-a50x-android-7-1-2](https://github.com/beeline09/acer-iconia-tab-a50x-android-7-1-2) — Android 7.1.2 (kernel + system, shared kernel source)
- [magisk-picasso-noNEON](https://github.com/beeline09/magisk-picasso-noNEON) — Magisk v31.1 built without NEON

## License

Apache 2.0 (AOSP). Proprietary blobs are not included — use `extract-blobs.sh`.
