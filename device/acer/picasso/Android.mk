#
# Copyright (C) 2011 The Android Open-Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# WARNING: Everything listed here will be built on ALL platforms,
# including x86, the emulator, and the SDK.  Modules must be uniquely
# named (liblights.tuna), and must build everywhere, or limit themselves
# to only building on ARM if they include assembly. Individual makefiles
# are responsible for having their own logic, for fine-grained control.

LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_PRODUCT),p4wifi)

include $(CLEAR_VARS)
include $(call all-makefiles-under,$(LOCAL_PATH))

endif

ifeq ($(TARGET_DEVICE),picasso)
# PICASSO: graphics root cause - the EGL loader opened egl/libGLESv2_tegra.so
# while the EGL interposer opened glv2tegra.so: two images of one driver
# (different inodes), the GL hooks of one stayed empty. The loader names are
# therefore symlinks to the single driver files.
PICASSO_EGL_LINKS := \
    $(TARGET_OUT)/lib/egl/libGLESv1_CM_tegra.so \
    $(TARGET_OUT)/lib/egl/libGLESv2_tegra.so
$(TARGET_OUT)/lib/egl/libGLESv1_CM_tegra.so:
	@mkdir -p $(dir $@)
	$(hide) rm -f $@ && ln -sf /system/lib/glv1tegra.so $@
$(TARGET_OUT)/lib/egl/libGLESv2_tegra.so:
	@mkdir -p $(dir $@)
	$(hide) rm -f $@ && ln -sf /system/lib/glv2tegra.so $@
ALL_DEFAULT_INSTALLED_MODULES += $(PICASSO_EGL_LINKS)
endif
