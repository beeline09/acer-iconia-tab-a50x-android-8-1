# Copyright (C) 2012 The Android Open Source Project
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

LOCAL_PATH:= $(call my-dir)
# HAL module implemenation, not prelinked and stored in
# hw/<COPYPIX_HARDWARE_MODULE_ID>.<ro.product.board>.so

include $(CLEAR_VARS)
LOCAL_PRELINK_MODULE := false
LOCAL_MODULE_PATH := $(TARGET_OUT_SHARED_LIBRARIES)/hw
LOCAL_SHARED_LIBRARIES := \
	liblog \
	libcutils \
	libhardware \
	libhardware_legacy \
	libutils \
	libdl \
	libEGL

LOCAL_CFLAGS += -Werror -Wall

LOCAL_SRC_FILES := hwc_tegra2.cpp

ifeq ($(BOARD_TEGRA2_HWC_SET_RT_IOPRIO),true)
	LOCAL_CFLAGS += -DSET_RT_IOPRIO
endif

# Workaround for buggy Samsung Tegra 2 hwcomposer
ifeq ($(BOARD_HAVE_SAMSUNG_T20_HWCOMPOSER),true)
	LOCAL_CFLAGS += -DSAMSUNG_T20_HWCOMPOSER
endif

LOCAL_C_INCLUDES += $(LOCAL_PATH)
LOCAL_CPP_INCLUDES += $(LOCAL_PATH)

LOCAL_MODULE := hwcomposer.tegra
LOCAL_MODULE_TAGS := optional
include $(BUILD_SHARED_LIBRARY)

# ptrace crash-catcher (debug tool for graphics bring-up)
include $(CLEAR_VARS)
LOCAL_MODULE := ptrace_dump
LOCAL_SRC_FILES := ptrace_dump.c
include $(BUILD_EXECUTABLE)

# NULL-safe string guards for NVIDIA blobs (debug bring-up)
include $(CLEAR_VARS)
LOCAL_MODULE := libnullguard
LOCAL_SRC_FILES := nullguard.c
LOCAL_LDLIBS := -ldl
include $(BUILD_SHARED_LIBRARY)

include $(CLEAR_VARS)
LOCAL_MODULE := ptrace_sys
LOCAL_SRC_FILES := ptrace_sys.c
include $(BUILD_EXECUTABLE)

include $(CLEAR_VARS)
LOCAL_MODULE := fbdemo
LOCAL_SRC_FILES := fbdemo.c
LOCAL_LDLIBS := -lm
include $(BUILD_EXECUTABLE)

# изолированный тест tegra gralloc (bring-up)
include $(CLEAR_VARS)
LOCAL_MODULE := grtest
LOCAL_SRC_FILES := grtest.c
LOCAL_SHARED_LIBRARIES := liblog libhardware libcutils
include $(BUILD_EXECUTABLE)

# fb_post дедлок-тест
include $(CLEAR_VARS)
LOCAL_MODULE := grtest2
LOCAL_SRC_FILES := grtest2.c
LOCAL_SHARED_LIBRARIES := liblog libhardware libcutils
include $(BUILD_EXECUTABLE)

# допрос EGL/GLES драйвера
include $(CLEAR_VARS)
LOCAL_MODULE := gltest
LOCAL_SRC_FILES := gltest.c
LOCAL_SHARED_LIBRARIES := libEGL libGLESv2 liblog
include $(BUILD_EXECUTABLE)

# тест дедупа dlopen по soname
include $(CLEAR_VARS)
LOCAL_MODULE := dltest
LOCAL_SRC_FILES := dltest.c
LOCAL_SHARED_LIBRARIES := libdl liblog
include $(BUILD_EXECUTABLE)

include 
LOCAL_MODULE := dltest2
LOCAL_SRC_FILES := dltest2.c
LOCAL_SHARED_LIBRARIES := libdl
include 

# двухрежимный допрос EGL (A: мета-слой, B: прямой tegra)
include $(CLEAR_VARS)
LOCAL_MODULE := gltest2b
LOCAL_SRC_FILES := gltest2.c
LOCAL_C_INCLUDES += bionic/libc/private
LOCAL_SHARED_LIBRARIES := libEGL libGLESv2 libdl liblog
include $(BUILD_EXECUTABLE)

# файловые capabilities (init 7.1.2 не умеет 'capabilities' в service)
include $(CLEAR_VARS)
LOCAL_MODULE := setfcaps
LOCAL_SRC_FILES := setfcaps.c
LOCAL_STATIC_LIBRARIES := libc
LOCAL_FORCE_STATIC_EXECUTABLE := true
include $(BUILD_EXECUTABLE)
