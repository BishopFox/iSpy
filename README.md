iSpy Assessment Framework
=========================

To build
--------
git submodule update --init   # you should need this only once
make clean
make
make package

If you get the error:

	/Applications/Xcode.app/Contents/Developer/usr/bin/make package requires dpkg-deb.
	make: *** [internal-package-check] Error 1

it means you need to install the Debian package manager. I use Brew, so it was just a
case of running "brew install dpkg" to get up and running.

To install
----------
SCP the com.bishopfox.iSpy<version-number>.deb file onto your iDevice.
SSH onto your iDevice and change into the directory containing the .deb.
Then:

dpkg -i com.bishopfox.iSpy*.deb

Todo: replace this with an auto installer.

To configure
------------
On your iDevice, restart the Prefs app if it's already running.
Scroll down the settings until you find "iSpy".
Enable "Inject iSpy into Apps".
Tap "Select Target Apps".
Choose the app(s) into which you like iSpy to be injected. 
   (you should only run one at a time)

iSpy will automatically inject itself into the selected apps each
time the app is launched.

Got back to the iSpy settings.
You'll probably want to enable "Instance Tracking".
Do NOT enable objc_msgSend logging here. Do it in the web GUI instead.
	(unless you know why you'd want to do such a thing. Warning: performance hit)

Strace-O-Rama
-------------
Most of man(2) and some of man(3) calls can be traced. Just select the ones you'd like.
Also available: a few CoreFoundation functions. More are getting added.

Using iSpy
----------
Launch one of your target apps.
Point your desktop browser at http://yourdevice:31337/
Have fun :)


