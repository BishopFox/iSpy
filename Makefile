GO_EASY_ON_ME=1
__THEOS_TARGET_ARG_1 = clang

include theos/makefiles/common.mk

CFLAGS+=  -mno-thumb -O0 -fno-exceptions -fno-rtti -fno-common -ffast-math -fno-threadsafe-statics -Wno-deprecated-objc-isa-usage -Wno-deprecated-declarations -Wno-address-of-temporary
LDFLAGS+= -framework CFNetwork -framework Security -framework CoreGraphics -lsqlite3 -lxml2 libs/CocoaHTTPServer.a -F. -framework Cycript -framework JavaScriptCore


TWEAK_NAME = iSpy
iSpy_FILES = \
	Tweak.xm \
	iSpy.logwriter.xm \
	iSpy.substrate.xm \
	iSpy.msgSend.xm \
	iSpy.msgSend_stret.xm \
	hooks_C_system_calls.xm \
	hooks_CoreFoundation.xm \
	iSpy.instance.xm \
	iSpy.class.xm \
	iSpy.web.xm \
	typestring.xm \
	iSpy.msgSend.whitelist.xm \
	iSpy.msgSend.common.xm \
	iSpy.rpc.xm \
	iSpyServer/iSpyHTTPServer.xm \
	iSpyServer/iSpyHTTPConnection.xm \
	iSpyServer/iSpyWebSocket.xm \
	iSpyServer/shellWebSocket.xm \
	iSpyServer/iSpyStaticFileResponse.xm


iSpy_FRAMEWORKS = UIKit MobileCoreServices

include $(THEOS_MAKE_PATH)/tweak.mk

