TARGET := iphone:clang:16.5:15.0
ARCHS := arm64 arm64e

THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DSHPet

INSTALL_TARGET_PROCESSES = SpringBoard

DSHPet_FILES = Tweak.xm \
	DSHPet/DSHPetCommon.m \
	DSHPet/DSHPetPlayer.m \
	DSHPet/DSHPetPhysics.m \
	DSHPet/DSHPetPetView.m \
	DSHPet/DSHPetAnimator.m \
	DSHPet/DSHPetMenu.m \
	DSHPet/DSHPetWindow.m \
	DSHPet/DSHPetManager.m \
	DSHPet/DSHPetAnimTable.m \
	DSHPet/DSHPetToggle.m \
	DSHPet/DSHPetChat.m \
	DSHPet/DSHPetChatBubble.m \
	DSHPet/DSHPetSpeechBubble.m \
	DSHPet/DSHPetVoice.m

DSHPet_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
DSHPet_FRAMEWORKS = UIKit AVFoundation QuartzCore CoreMedia

include $(THEOS_MAKE_PATH)/tweak.mk

TOOL_NAME = dshpet-respring
dshpet-respring_FILES = Respring/main.m
dshpet-respring_FRAMEWORKS = Foundation
dshpet-respring_INSTALL_PATH = /usr/bin

include $(THEOS_MAKE_PATH)/tool.mk

after-install::
	install.exec "killall -9 SpringBoard || true"
