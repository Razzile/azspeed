include theos/makefiles/common.mk

TWEAK_NAME = AZSpeed
AZSpeed_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
