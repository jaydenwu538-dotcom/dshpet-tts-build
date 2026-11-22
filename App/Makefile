ARCHS := arm64
TARGET := iphone:clang:16.5:15.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = DSHPet

# Shared/ 由构建脚本从 ../DSHPet 拷入（桌宠本体源码，与 tweak 共用一份逻辑）
DSHPet_FILES = $(wildcard *.m) $(wildcard Shared/*.m)
DSHPet_FRAMEWORKS = UIKit AVFoundation QuartzCore CoreMedia
DSHPet_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -I$(THEOS_PROJECT_DIR)/Shared
DSHPet_CODESIGN_FLAGS = -Sentitlements.plist
DSHPet_INSTALL_PATH = /Applications

include $(THEOS_MAKE_PATH)/application.mk
