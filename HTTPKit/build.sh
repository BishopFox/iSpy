#!/bin/sh

SDK=$(ls -1d /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iP* | tail -n1)
echo $SDK

# remove object files to build nice n clean
echo '[+] Removing old object files'
rm *.o *.a

# compile the Objective-C stuff
echo '[+] Compiling Objective-C files'
clang -c *.m  -arch armv7 -isysroot $SDK -Wno-arc-bridge-casts-disallowed-in-nonarc -Wno-trigraphs

# compile the C stuff
echo '[+] Compiling C files'
clang -c *.c -I ../OpenSSL-for-iPhone/include -Wvisibility -arch armv7 -isysroot $SDK

# See Makefile.* in the parent directory.
echo '[+] Creating HTTPKit.a archive'
ar -r HTTPKit.a *.o >/dev/null 2>&1

if [ -d ../libs ]; then
	echo '[+] Copying HTTPKit.a into ../libs/'
	cp HTTPKit.a ../libs/
fi
echo '[+] The HTTPKit libraries were copied into into ../libs/ directory. My work is done.'
