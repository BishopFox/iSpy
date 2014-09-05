iSpy Assessment Framework
=========================

Current Release
----------------
The current release is a **developer preview**; code is subject to change, and *will be* unstable. However, we appreciate code contributions, feature requests, and bug reports. We currently do not have binary releases, stay tuned!


To build
--------
You will need an OSX machine with Xcode 5.

	git clone https://github.com/BishopFox/iSpy --recursive
	make
	make package

If you get the error:

	/Applications/Xcode.app/Contents/Developer/usr/bin/make package requires dpkg-deb.
	make: *** [internal-package-check] Error 1

it means you need to install the Debian package manager. I use Brew, so it was just a
case of running "brew install dpkg" to get up and running.

To install
----------
The easiest way to get all of the iOS dependancies (applist, prefloader) is to simply install Veency from Cydia.


SCP the com.bishopfox.iSpy<version-number>.deb file onto your iDevice.
SSH onto your iDevice and change into the directory containing the .deb.
Then:

	dpkg -i com.bishopfox.iSpy*.deb

Todo: replace this with an auto installer.
Note: you can edit install.sh to suit your needs.

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

Using iSpy
----------
Launch one of your target apps.
Point your desktop browser at http://yourdevice:31337/
Have fun :)

Check the device logs for details, if multiple instances of iSpy are run the port number may differ slightly.

Cycript Integration
-------------------
This is a gaping security hole, so if you want it you have to enable it by hand.

	Yens-iPad:/tmp root# su - mobile
	Yens-iPad:~ mobile$ mkdir .ssh
	Yens-iPad:~ mobile$ cd .ssh
	Yens-iPad:~/.ssh mobile$ ssh-keygen
	
	Generating public/private rsa key pair.
	Enter file in which to save the key (/var/mobile/.ssh/id_rsa):
	Enter passphrase (empty for no passphrase):
	Enter same passphrase again:
	Your identification has been saved in /var/mobile/.ssh/id_rsa.
	Your public key has been saved in /var/mobile/.ssh/id_rsa.pub.
	The key fingerprint is:
	d8:0f:ed:b0:fc:4e:20:43:96:16:0b:9f:58:03:91:5d mobile@Yens-iPad
	The key's randomart image is:
	+--[ RSA 2048]----+
	|    +=+.E        |
	|    .=.*         |
	|    . O          |
	|     + o .       |
	|      + S .      |
	|       + B       |
	|        o +      |
	|         o       |
	|         .o      |
	+-----------------+

	Yens-iPad:~/.ssh mobile$ cat id_rsa.pub >> authorized_keys

After that it'll work.
