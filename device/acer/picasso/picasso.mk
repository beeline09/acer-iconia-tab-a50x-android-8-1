$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base.mk)
$(call inherit-product, device/samsung/p4-common/p4-common.mk)
$(call inherit-product, device/acer/picasso/device.mk)
$(call inherit-product-if-exists, vendor/acer/picasso/picasso-vendor.mk)

PRODUCT_NAME := picasso
PRODUCT_BRAND := Acer
PRODUCT_DEVICE := picasso
PRODUCT_MODEL := Iconia Tab A500
PRODUCT_MANUFACTURER := Acer

# Android 8.1 Go (low_ram): 1 ГБ RAM Tegra 2 — урезаем везде, где платформа умеет
PRODUCT_PROPERTY_OVERRIDES += \
    ro.config.low_ram=true \
    ro.lmk.critical_upgrade=true \
    ro.lmk.upgrade_pressure=40 \
    ro.lmk.downgrade_pressure=60 \
    persist.sys.use_16bpp_alpha=1
