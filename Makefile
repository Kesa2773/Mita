export ARCHS = arm64 arm64e

export TARGET = iphone:latest:13.0

INSTALL_TARGET_PROCESSES = SpringBoard

FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Mita

${TWEAK_NAME}_FILES = $(wildcard *.m HUD/*.m)

${TWEAK_NAME}_CFLAGS = -fobjc-arc -I./HUD

${TWEAK_NAME}_FRAMEWORKS = UIKit CoreFoundation CoreGraphics QuartzCore
${TWEAK_NAME}_PRIVATE_FRAMEWORKS = AppSupport

include $(THEOS_MAKE_PATH)/tweak.mk

