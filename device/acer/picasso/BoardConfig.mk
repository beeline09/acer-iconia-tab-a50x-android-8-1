# Acer Iconia Tab A500/A501 (picasso)
# (single include)
include device/samsung/p4-common/BoardConfigCommon.mk

TARGET_BOOTLOADER_BOARD_NAME := picasso
TARGET_BOARD_INFO_DEVICE := picasso
TARGET_OTA_ASSERT_DEVICE := picasso,a500

# Kernel (временно prebuilt p4wifi для обкатки конфигурации)
# picasso native kernel
TARGET_PREBUILT_KERNEL := device/acer/picasso/kernel

# Partitions (A500)
BOARD_BOOTIMAGE_PARTITION_SIZE := 8388608
# ВНИМАНИЕ: настоящая recovery-партиция A500 = 5 МБ (5242880), но наш recovery.img ~6.2 МБ.
# Recovery НЕ прошивается: OTA собирается с --no_recovery, на устройстве остаётся TWRP.
# Размер завышен, чтобы прошёл assert при сборке образа-артефакта.
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 8388608
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 629145600
BOARD_USERDATAIMAGE_PARTITION_SIZE := 13950255104
BOARD_CACHEIMAGE_PARTITION_SIZE := 1283457024
BOARD_FLASH_BLOCK_SIZE := 131072
TARGET_USERIMAGES_USE_EXT4 := true

# WiFi Broadcom BCM4329 (firmware paths: see WIFI_DRIVER_FW_PATH_* below)
BOARD_HAVE_BLUETOOTH_BCM := true

TARGET_RECOVERY_FSTAB := device/acer/picasso/rootdir/etc/fstab.picasso
TARGET_PROVIDES_INIT_RC := true

# Override Samsung bcmdhd wifi config from p4-common (A500 uses bcm4329 WEXT)

# Recovery: используем сторонний TWRP (партиция всего 5 МБ, AOSP recovery не влезает)
# TARGET_NO_RECOVERY убран: гасит recovery_fstab и весь OTA-контур build/core/Makefile, нужен для TWRP

# Appliance mode: wall-powered device, battery physically removed.
# Kernel reports a healthy full battery (EC_battery.ec_fake_battery=1 cmdline)
# and the board reboots 10 s after a kernel panic instead of hanging.
# Community builders with a battery installed: set to false.
TARGET_NO_BATTERY_APPLIANCE := true
BOARD_KERNEL_CMDLINE := panic=10
ifeq ($(TARGET_NO_BATTERY_APPLIANCE),true)
BOARD_KERNEL_CMDLINE += EC_battery.ec_fake_battery=1
endif

# File-based OTA zip: flashes on any recovery incl. old TWRP/CWM on A500
BLOCK_BASED_OTA := false

# Do not ship/flash recovery payloads: the device keeps its own TWRP in the
# tiny 5 MB recovery partition. Omits recovery_from_boot.p from system.img,
# install-recovery.sh from the OTA, and recovery from the OTA package itself.
BOARD_OMIT_RECOVERY_FROM_SYSTEM := true

# Wi-Fi: Broadcom BCM4329 via bcmdhd (ported from the CM12.1 picasso kernel).
# Driver is built into the kernel; firmware and nvram come from the device.
BOARD_WLAN_DEVICE := bcmdhd
WPA_SUPPLICANT_VERSION := VER_0_8_X
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_WPA_SUPPLICANT_PRIVATE_LIB := lib_driver_cmd_bcmdhd
BOARD_HOSTAPD_DRIVER := NL80211
BOARD_HOSTAPD_PRIVATE_LIB := lib_driver_cmd_bcmdhd
BOARD_HAVE_SAMSUNG_WIFI := false
BOARD_NO_WIFI_HAL := true
WIFI_DRIVER_FW_PATH_PARAM := "/sys/module/bcmdhd/parameters/firmware_path"
# PICASSO: BCM4329 firmware (4.218.248.44). The p4 paths pointed at BCM4330
# firmware (5.90.100.430): the first wifi_on after boot worked (empty
# firmware_path -> driver default), every later one failed with HT Avail
# timeout once the HAL had written the wrong path.
WIFI_DRIVER_FW_PATH_STA := "/system/vendor/firmware/fw_bcmdhd.bin"
WIFI_DRIVER_FW_PATH_AP := "/system/vendor/firmware/fw_bcmdhd_apsta.bin"
WIFI_DRIVER_FW_PATH_P2P := "/system/vendor/firmware/fw_bcmdhd.bin"

# Tegra2 blobs require dlmalloc (jemalloc causes heap corruption in OMX/EGL blobs)

# timduru-proven 7.1 recipe for ICS tegra blobs
BOARD_EGL_NEEDS_FNW := true
MAX_EGL_CACHE_KEY_SIZE := 4096
MAX_EGL_CACHE_SIZE := 2146304
