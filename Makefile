export THEOS ?= $(THEOS)
TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = WeChat

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MisakaGroupTweak

MisakaGroupTweak_FILES = Tweak.x
MisakaGroupTweak_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-function -Wno-error
MisakaGroupTweak_FRAMEWORKS = UIKit Foundation CoreGraphics

include $(THEOS)/makefiles/tweak.mk
