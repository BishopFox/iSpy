/*
 * iSpy - Bishop Fox iOS hacking/hooking/sandboxing framework.
 */

#include <stack>
#include <fcntl.h>
#include <stdio.h>
#include <stdarg.h>
#include <unistd.h>
#include <string.h>
#include <dirent.h>
#include <stdbool.h>
#include <pthread.h>
#include <sys/stat.h>
#include <sys/param.h>
#include <sys/mount.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/sysctl.h>
#include <sys/mman.h>
#include <sys/uio.h>
#include <objc/objc.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/nlist.h>
#include <netinet/in.h>
#include <semaphore.h>
#include <stdlib.h>
#include <spawn.h>
#include <CFNetwork/CFNetwork.h>
#include <CFNetwork/CFProxySupport.h>
#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFStream.h>
#import  <Security/Security.h>
#import  <Security/SecCertificate.h>
#import  <Foundation/NSJSONSerialization.h>
#import  <MobileCoreServices/MobileCoreServices.h>
#import  <QuartzCore/QuartzCore.h>
#import <CoreData/CoreData.h>
#include "iSpy.common.h"
#include "iSpy.instance.h"
#include "iSpy.class.h"
#include "hooks_C_system_calls.h"
#include "hooks_CoreFoundation.h"
#include "iSpy.msgSend.whitelist.h"
#import "Cycript.framework/headers/cycript.h"

// This will become a linked list of pointers to instantiated classes
//id (*orig_class_createInstance)(Class cls, size_t extraBytes);
//id (*orig_object_dispose)(id obj);

//
// Pointers to original C runtime funcs. We can hook all the things.
//
extern DIR * (*orig_opendir)(const char *dirname);
extern struct dirent *(*orig_readdir)(DIR *dirp);
extern int (*orig_readdir_r)(DIR *dirp, struct dirent *entry, struct dirent **result);
extern ssize_t (*orig_recvfrom)(int socket, void *buffer, size_t length, int flags, struct sockaddr *address, socklen_t *address_len);
extern ssize_t (*orig_recv)(int socket, void *buffer, size_t length, int flags);
extern int (*orig_ioctl)(int fildes, unsigned long request, ...);
extern int (*orig_open)(const char *fname, int oflag, ...);
extern int (*orig_close)(int f);
extern int (*orig_fstat)(int fildes, struct stat *buf);
extern int (*orig_lstat)(const char *path, struct stat *buf);
extern int (*orig_stat)(const char *path, struct stat *buf);
extern int (*orig_access)(const char *path, int amode);
extern int (*orig_fork)(void);
extern int (*orig_statfs)(const char *path, struct statfs *buf);
extern int (*orig_fstatfs)(int fd, struct statfs *buf);
extern uint32_t (*orig_dyld_image_count)(void);
extern char *(*orig_dyld_get_image_name)(uint32_t id);
extern int (*orig_connect)(int socket, const struct sockaddr *address, socklen_t address_len);
extern int (*orig_bind)(int socket, const struct sockaddr *address, socklen_t address_len);
extern int (*orig_accept)(int socket, struct sockaddr *address, socklen_t *address_len);
extern int (*orig_memcmp)(const void *s1, const void *s2, size_t n);
extern int (*orig_strcmp)(const char *s1, const char *s2);
extern int (*orig_strncmp)(const char *s1, const char *s2, int n);
extern int (*orig_sysctl)(int *name, u_int namelen, void *old, size_t *oldlenp, void *_new, size_t newlen);
extern int (*orig_acct)(char *path);
extern int (*orig_adjtime)(struct timeval *delta, struct timeval *olddelta);
extern int (*orig_chdir)(const char * path);
extern int (*orig_chflags)(char *path, int flags);
extern int (*orig_chmod)(const char * path, int mode);
extern int (*orig_chown)(const char * path, int uid, int gid);
extern int (*orig_chroot)(const char * path);
extern int (*orig_csops)(pid_t pid, uint32_t ops, const char * useraddr, user_size_t usersize);
extern int (*orig_csops_audittoken)(pid_t pid, uint32_t ops, const char * useraddr, user_size_t usersize, const char * uaudittoken);
extern int (*orig_dup)(u_int fd);
extern int (*orig_dup2)(u_int from, u_int to);
extern int (*orig_execve)(char *fname, char **argp, char **envp);
extern int (*orig_fchdir)(int fd);
extern int (*orig_fchflags)(int fd, int flags);
extern int (*orig_fchmod)(int fd, int mode);
extern int (*orig_fchown)(int fd, int uid, int gid);
extern int (*orig_fcntl)(int fd, int cmd, long arg);
extern int (*orig_fdatasync)(int fd);
extern int (*orig_flock)(int fd, int how);
extern int (*orig_fpathconf)(int fd, int name);
extern int (*orig_fsync)(int fd);
extern int (*orig_ftruncate)(int fd, off_t length);
extern int (*orig_futimes)(int fd, struct timeval *tptr);
extern int (*orig_getdtablesize)(void);
extern int (*orig_getegid)(void);
extern int (*orig_geteuid)(void);
extern int (*orig_getfh)(char *fname, fhandle_t *fhp);
extern int (*orig_getfsstat)(const char * buf, int bufsize, int flags);
extern int (*orig_getgid)(void);
extern int (*orig_getgroups)(u_int gidsetsize, gid_t *gidset);
extern int (*orig_gethostuuid)(unsigned char *uuid_buf, const struct timespec *timeoutp);
extern int (*orig_getitimer)(u_int which, struct itimerval *itv);
extern int (*orig_getlogin)(char *namebuf, u_int namelen);
extern int (*orig_getpeername)(int fdes, caddr_t asa, socklen_t *alen);
extern int (*orig_getpgid)(pid_t pid);
extern int (*orig_getpgrp)(void);
extern pid_t (*orig_getpid)(void);
extern int (*orig_getppid)(void);
extern int (*orig_getpriority)(int which, id_t who);
extern int (*orig_getrlimit)(u_int which, struct rlimit *rlp);
extern int (*orig_getrusage)(int who, struct rusage *rusage);
extern int (*orig_getsockname)(int fdes, caddr_t asa, socklen_t *alen);
extern int (*orig_getsockopt)(int s, int level, int name, caddr_t val, socklen_t *avalsize);
extern int (*orig_gettimeofday)(struct timeval *tp, struct timezone *tzp);
extern int (*orig_getuid)(void);
extern int (*orig_kill)(int pid, int signum, int posix);
extern int (*orig_link)(const char * path, const char * link);
extern int (*orig_listen)(int s, int backlog);
extern int (*orig_madvise)(caddr_t addr, size_t len, int behav);
extern int (*orig_mincore)(const char * addr, user_size_t len, const char * vec);
extern int (*orig_mkdir)(const char * path, int mode);
extern int (*orig_mkfifo)(const char * path, int mode);
extern int (*orig_mknod)(const char * path, int mode, int dev);
extern int (*orig_mlock)(caddr_t addr, size_t len);
extern int (*orig_mount)(char *type, char *path, int flags, caddr_t data);
extern int (*orig_mprotect)(caddr_t addr, size_t len, int prot);
extern int (*orig_msync)(caddr_t addr, size_t len, int flags);
extern int (*orig_munlock)(caddr_t addr, size_t len);
extern int (*orig_munmap)(caddr_t addr, size_t len);
extern int (*orig_nfssvc)(int flag, caddr_t argp);
extern int (*orig_pathconf)(char *path, int name);
extern int (*orig_pipe)(void);
extern int (*orig_ptrace)(int req, pid_t pid, caddr_t addr, int data);
extern int (*orig_readlink)(char *path, char *buf, int count);
extern int (*orig_reboot)(int opt, char *command);
extern int (*orig_recvmsg)(int s, struct msghdr *msg, int flags);
extern int (*orig_rename)(char *from, char *to);
extern int (*orig_revoke)(char *path);
extern int (*orig_rmdir)(char *path);
extern int (*orig_select)(int nd, u_int32_t *in, u_int32_t *ou, u_int32_t *ex, struct timeval *tv);
extern int (*orig_sendmsg)(int s, caddr_t msg, int flags);
extern int (*orig_sendto)(int s, caddr_t buf, size_t len, int flags, caddr_t to, socklen_t tolen);
extern int (*orig_setegid)(gid_t egid);
extern int (*orig_seteuid)(uid_t euid);
extern int (*orig_setgid)(gid_t gid);
extern int (*orig_setgroups)(u_int gidsetsize, gid_t *gidset);
extern int (*orig_setitimer)(u_int which, struct itimerval *itv, struct itimerval *oitv);
extern int (*orig_setlogin)(char *namebuf);
extern int (*orig_setpgid)(int pid, int pgid);
extern int (*orig_setpriority)(int which, id_t who, int prio);
extern int (*orig_setregid)(gid_t rgid, gid_t egid);
extern int (*orig_setreuid)(uid_t ruid, uid_t euid);
extern int (*orig_setrlimit)(u_int which, struct rlimit *rlp);
extern int (*orig_setsid)(void);
extern int (*orig_setsockopt)(int s, int level, int name, caddr_t val, socklen_t valsize);
extern int (*orig_settimeofday)(struct timeval *tv, struct timezone *tzp);
extern int (*orig_setuid)(uid_t uid);
extern int (*orig_shutdown)(int s, int how);
extern int (*orig_sigaction)(int signum, struct __sigaction *nsa, struct sigaction *osa);
extern int (*orig_sigpending)(struct sigvec *osv);
extern int (*orig_sigprocmask)(int how, const char * mask, const char * omask);
extern int (*orig_sigsuspend)(sigset_t mask);
extern int (*orig_socket)(int domain, int type, int protocol);
extern int (*orig_socketpair)(int domain, int type, int protocol, int *rsv);
extern int (*orig_swapon)(void);
extern int (*orig_symlink)(char *path, char *link);
extern int (*orig_sync)(void);
extern int (*orig_truncate)(char *path, off_t length);
extern int (*orig_umask)(int newmask);
extern int (*orig_undelete)(const char * path);
extern int (*orig_unlink)(const char * path);
extern int (*orig_unmount)(const char * path, int flags);
extern int (*orig_utimes)(char *path, struct timeval *tptr);
extern int (*orig_vfork)(void);
extern int (*orig_wait4)(int pid, const char * status, int options, const char * rusage);
extern int (*orig_waitid)(idtype_t idtype, id_t id, siginfo_t *infop, int options);
extern off_t (*orig_lseek)(int fd, off_t offset, int whence);
extern void * (*orig_mmap)(caddr_t addr, size_t len, int prot, int flags, int fd, off_t pos);
extern user_ssize_t (*orig_pread)(int fd, const char * buf, user_size_t nbyte, off_t offset);
extern user_ssize_t (*orig_pwrite)(int fd, const char * buf, user_size_t nbyte, off_t offset);
extern user_ssize_t (*orig_read)(int fd, const char * cbuf, user_size_t nbyte);
extern user_ssize_t (*orig_readv)(int fd, struct iovec *iovp, u_int iovcnt);
extern user_ssize_t (*orig_write)(int fd, const char * cbuf, user_size_t nbyte);
extern user_ssize_t (*orig_writev)(int fd, struct iovec *iovp, u_int iovcnt);
extern void (*orig_exit)(int rval);

extern bool (*orig_dlopen_preflight)(const char* path);
extern int (*orig_system)(const char *command);

//
// Pointers to original CoreFoundation functions
//
extern Boolean (*orig_CFWriteStreamSetProperty)(CFWriteStreamRef stream, CFStringRef propertyName, CFTypeRef propertyValue);
extern Boolean (*orig_CFReadStreamSetProperty)(CFReadStreamRef stream, CFStringRef propertyName, CFTypeRef propertyValue);
extern CFIndex (*orig_CFReadStreamRead)(CFReadStreamRef stream, UInt8 *buffer, CFIndex bufferLength);
extern CFURLRef (*orig_CFURLCreateWithString)(CFAllocatorRef allocator, CFStringRef URLString, CFURLRef baseURL);
extern Boolean (*orig_CFReadStreamOpen)(CFReadStreamRef stream);
extern Boolean (*orig_CFWriteStreamOpen)(CFWriteStreamRef stream);
extern CFIndex (*orig_CFWriteStreamWrite)(CFWriteStreamRef stream, const UInt8 *buffer, CFIndex bufferLength);
extern CFHTTPMessageRef (*orig_CFHTTPMessageCreateRequest)(CFAllocatorRef alloc, CFStringRef requestMethod, CFURLRef url, CFStringRef httpVersion);
extern void (*orig_CFStreamCreatePairWithSocketToHost)(CFAllocatorRef alloc, CFStringRef host, UInt32 port, CFReadStreamRef *readStream, CFWriteStreamRef *writeStream);
extern void (*orig_CFStreamCreatePairWithPeerSocketSignature)(CFAllocatorRef alloc, const CFSocketSignature *signature, CFReadStreamRef *readStream, CFWriteStreamRef *writeStream);
extern void (*orig_CFStreamCreatePairWithSocket)(CFAllocatorRef alloc, CFSocketNativeHandle sock, CFReadStreamRef *readStream, CFWriteStreamRef *writeStream);
extern CFReadStreamRef (*orig_CFReadStreamCreateWithBytesNoCopy)(CFAllocatorRef alloc, const UInt8 *bytes, CFIndex length, CFAllocatorRef bytesDeallocator);
extern CFReadStreamRef (*orig_CFReadStreamCreateForHTTPRequest)(CFAllocatorRef alloc, CFHTTPMessageRef request);
extern CFDictionaryRef (*orig_CFNetworkCopySystemProxySettings)(void);
extern SecCertificateRef (*orig_SecCertificateCreateWithData)(CFAllocatorRef allocator, CFDataRef data);
extern int (*orig_dup)(u_int fd);
void heh();
void launch_cycript();

/*************************************************************
 *** This is where you should put your own Theos tweaks.   ***
 *** This shit is important. Put them inside "%bf_group"   ***
 *** right here between these enormous comment sections.   ***
 *************************************************************/

%group bf_group // Don't change this %group name unless you know what you're doing: your hooks won't load.
				// Don't close this %group with a %end, either - it comes later in the code.

/* SOME EXAMPLES OF USEFUL HOOKS /*
/*
%hook UIDevice
-(NSString *) systemVersion {
	return @"7.1";
}
%end

%hook NSMutableURLRequest
-(void) setHTTPBody:(NSData *) data {
	NSString *logEntry = [NSString stringWithUTF8String:(char *)[data bytes]];
	NSLog(@"%s", [logEntry UTF8String]);
	ispy_log_debug(LOG_HTTP, "%s", [logEntry UTF8String]);
	%orig;
}
%end
*/


/********************************************
 *** End of area for putting your tweaks. ***
 ********************************************/





/*
 Hook the running application by extending the UIApplication class. Change if necessary.
 This is a sensible default. This MUST come before the C runtime hooking code.
 */


/*
 This makes a nice BF-branded popover appear for a few seconds and the app loads.
 We hook showGUIPopOver in the UIWindow class (but only once) to do all this. There are loads of other ways.
 */
void showGUIPopOver() {
	// Only ever run this function once.
	static BOOL once = NO;
	
	if(!once) {
		once = YES;

		// create a UIView object to hold the overlay
		UIView* view = [[UIView alloc] initWithFrame: CGRectMake(10,30,250,34)];

		// get the current window
		UIWindow* window = [UIApplication sharedApplication].keyWindow;
		if (!window) {
			window = [[UIApplication sharedApplication].windows objectAtIndex:0];
		}

		UIView *mainView = [[window subviews] objectAtIndex:0];
		float width = mainView.bounds.size.width;
		NSLog(@"Width: %f", width);

		// give the overlay a black background and rounded corners
		[view setBackgroundColor: [UIColor blackColor]];
		view.layer.cornerRadius = 10;
		view.layer.masksToBounds = YES;
		[view setContentMode:UIViewContentModeCenter];

		// Load th Bishop Fox logo into a UIImageView
		UIImageView *img = [[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:@"/var/www/iSpy/img/bf-orange-alpha.png"]];
		[img setContentMode:UIViewContentModeLeft];

		// give everything a nice BF orange border
		[[view layer] setBorderColor:[UIColor orangeColor].CGColor];
		[[view layer] setBorderWidth:2];

		// Add a "loading x%" label.
		CGRect labelFrame = CGRectMake(52,1,250,28);
		UILabel *label = [[UILabel alloc] initWithFrame: labelFrame];
		[label setText: @"iSpy loaded!"];
		[label setTextColor: [UIColor whiteColor]];
		[label setBackgroundColor: [UIColor blackColor]];

		// add the logo and label to the overlay view
		[view performSelectorOnMainThread:@selector(addSubview:) withObject:img waitUntilDone:YES];
		[view performSelectorOnMainThread:@selector(addSubview:) withObject:label waitUntilDone:YES];

		// add the view to the window. This makes it visible.
		// Note: we have to run the UI update code on the main thread for the UI to actually update/change.
		[[[window subviews] objectAtIndex:0] performSelectorOnMainThread:@selector(addSubview:) withObject:view waitUntilDone:YES];

		// We dispatch this with GCD and send it to a background thread.
		dispatch_queue_t bf_loading = dispatch_get_global_queue(0, 0);

		dispatch_async(bf_loading, ^{
			// show the Showtime message...
			sleep(3);
			// clean up
			[view performSelectorOnMainThread:@selector(setHidden:) withObject:[NSNumber numberWithBool:true] waitUntilDone:YES];
		});
	}
}


/***********************************************************************************
*** Do not add any %hook...%end sections after this, it will only end in tears. ***
***********************************************************************************/


%hook UIApplication

-(id) init {
	NSLog(@"-[UIApplication init] entry");
	self = %orig;

	if(self) {
		// Register for the "UIApplicationDidBecomeActiveNotification" notification.
		// Use it to trigger our GUI overlay.
		[[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
	       	showGUIPopOver();
		}];
	}
	NSLog(@"-[UIApplication init] exit");
	return self;
}

// This is neat - it hooks all user input events and can be used to log them :)
-(void) sendEvent:(UIEvent*)event
{
/*
    NSSet *touches = [event allTouches];
    UITouch *touch = [touches anyObject];
    CALayer *touchedLayer = [touch view].layer;
    NSLog(@"[iSpy] Event: %@ // %@ // %@",NSStringFromClass([[touch view] class]), touchedLayer, [touch view]);
*/
    %orig;
}

// This MUST be called ONCE before turning on objc_msgSend logging.
void bf_init_msgSend_logging() {
	bf_hook_msgSend();
	bf_hook_msgSend_stret();
}

// Turn on logging of calls to objc_msgSend (by default to  BF_LOGFILE "/tmp/iSpy.log".
// You'll get one line per call, like this:
//        -[className methodName:withParam:foo:bar]
void bf_enable_msgSend_logging() {
	ispy_log_debug(LOG_GENERAL, "[iSpy] turning on objc_msgSend() logging");
	bf_enable_msgSend();
	ispy_log_debug(LOG_GENERAL, "[iSpy] Turning on _stret, too");
	bf_enable_msgSend_stret();
	ispy_log_debug(LOG_GENERAL, "[iSpy] Done.");
}

// Switch off logging. Calls to objc_msgSend will not be logged after this.
// You can call bf_enable_msgSend_logging() again to re-enable logging.
void bf_disable_msgSend_logging() {
	ispy_log_debug(LOG_GENERAL, "[iSpy] turning off objc_msgSend() logging");
	bf_disable_msgSend();
	bf_disable_msgSend_stret();
}


// It's safe to call this repeatedly, unlike the original MSHookFunction().
void bf_MSHookFunction(void *func, void *repl, void **orig) {
	if(func != repl) {
		MSHookFunction(func, repl, orig);
	}
}

void bf_unHookFunction(void *func, void *repl, void *orig) {
	void *dummy;

	if(func == repl) {
		MSHookFunction((void *)func, (void *)orig, (void **)&dummy);
	}
}

%end // end of UIApplication class extension.


/* This makes a log of any insecure file writes via NSData */
%hook NSData
-(BOOL) writeToFile:(NSString *)path options:(NSDataWritingOptions)mask error:(NSError **)errorPtr {
	if((mask & NSDataWritingFileProtectionNone) == NSDataWritingFileProtectionNone)
		ispy_log_debug(LOG_REPORT, "[Insecure Data Storage (NSDataWritingFileProtectionNone)] NSData writeToFile:\"%s\" options:0x%08x", [path UTF8String], (unsigned int)mask);
	return %orig;
}

-(BOOL) writeToURL:(NSURL *)aURL options:(NSDataWritingOptions)mask error:(NSError **)errorPtr {
	if((mask & NSDataWritingFileProtectionNone) == NSDataWritingFileProtectionNone)
		ispy_log_debug(LOG_REPORT, "[Insecure Data Storage (NSDataWritingFileProtectionNone)] NSData writeToURL:\"%s\" options:0x%08x", [[aURL path] UTF8String], (unsigned int)mask);
	return %orig;
}
%end


/*
 By hooking UIControl's sendAction* methods we can trace exactly which methods respond
 to interaction with UI elements.

 If you enable this you'll see NSLog entries for each button press, etc.

 Make sure that LOG_UI_INTERACTION is enabled (see above, near the top of the file).
 */
%hook UIControl

- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
	if (LOG_UI_INTERACTION) {
		%log;
	}
	%orig;
}

- (void)sendActionsForControlEvents:(UIControlEvents)controlEvents {
	if (LOG_UI_INTERACTION) {
		%log;
	}
	%orig;
}

%end // UIControl


%end // %group bf_group


%group ssl_pinning_bypasses
/*
	Bypass AFNetworking's SSL Pinning
*/
%hook AFSecurityPolicy
- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust {
	ispy_log_debug(LOG_GENERAL, "[AFNetworking]: Intercepting AFSecurityPolicy::serverTrust");
	return YES;
}

- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust forDomain:(NSString *)domain {
	ispy_log_debug(LOG_GENERAL, "[AFNetworking]: Intercepting AFSecurityPolicy::serverTrust::forDomain");
	return YES;
}
%end


%hook NSUserDefaults
-(BOOL) synchronize {
	ispy_log_debug(LOG_REPORT, "[Insecure NSUserDefaults] NSUserDefaults is being used to store data. Check \"Library/Preferences/*.plist\" for files with cleartext data in them.");
	return %orig;
}
%end


%hook NSDictionary
-(BOOL) writeToFile:(NSString *)path atomically:(BOOL)flag {
	ispy_log_debug(LOG_REPORT, "[Insecure plist storage] NSDictionary writeToFile:\"%s\"", [path UTF8String]);
	return %orig;
}

-(BOOL) writeToURL:(NSURL *)aURL atomically:(BOOL)flag {
	ispy_log_debug(LOG_REPORT, "[Insecure plist storage] NSDictionary writeToURL:\"%s\"", [[aURL path] UTF8String]);
	return %orig;
}
%end


%hook NSPersistentStoreCoordinator
- (NSPersistentStore *)addPersistentStoreWithType:(NSString *)storeType configuration:(NSString *)configuration URL:(NSURL *)storeURL options:(NSDictionary *)options error:(NSError **)error {
	ispy_log_debug(LOG_REPORT, "[Insecure Core Data storage] %s", [[storeURL path] UTF8String]);
	return %orig;	
}
%end

%end // %group bf_group

/***********************************************************************************
 *** Do not add any %hook...%end sections after this, it will only end in tears. ***
 ***                                                                             ***
 *** No, really. The order is important, especially pre_init_group. See %ctor.   ***
 ***********************************************************************************/



%group pre_init_group

/*
	Adds a useful "containsString" method to NSString.
	For example:
		if ( [myString containsString:@"foo"] ) {
			NSLog(@"The string contains foo!");
		}
	Why isn't this part of NSString by default? Jeez.
*/
%hook NSString
%new(B@:)
- (BOOL) containsString: (NSString*) substring {
	NSRange range = [self rangeOfString : substring];
	BOOL found = ( range.location != NSNotFound );
	return found;
}
%end // %hook NSString
%end // %group pre_init_group


/*
	[*] This code is from TrustMe: https://github.com/intrepidusgroup/trustme?source=cc
	[*] This code is subject to the Python v2 lic: https://github.com/intrepidusgroup/trustme/blob/master/LICENSE
	[*] There have been no major changes to the code, other than embedding it into this application.
	Function signature for original SecTrustEvaluate
 */
OSStatus new_SecTrustEvaluate(SecTrustRef trust, SecTrustResultType *result) {
	ispy_log_debug(LOG_GENERAL, "[trustme] Intercepting SecTrustEvaluate() call");
	*result = kSecTrustResultProceed;
	return errSecSuccess;
}

static OSStatus (*original_SecTrustEvaluate)(SecTrustRef trust, SecTrustResultType *result);

// These are useful functions that we can use as overrides with MSHookMessageEx and bf_MSHookFunction.
EXPORT int return_false() {
	return 0;
}

EXPORT int return_true() {
	return 1;
}


/* Detect insecure use of the keychain */
OSStatus (*orig_SecItemAdd)(CFDictionaryRef attributes, CFTypeRef *result);
OSStatus (*orig_SecItemUpdate)(CFDictionaryRef query, CFDictionaryRef attributes);

OSStatus iSpy_SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result) {
	// Add the item to the keychain
	OSStatus retVal = orig_SecItemAdd(attributes, result);

	// Force a security check of the keychain; report findings in "report.log"
	[[iSpy sharedInstance] keyChainItems];
	
	return retVal;
}

OSStatus iSpy_SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributes) {
	// Update the keychain
	OSStatus retVal = orig_SecItemUpdate(query, attributes);
	
	// Force a security check of the keychain; report findings in "report.log"
	[[iSpy sharedInstance] keyChainItems];
	
	return retVal;
}

void hook_keychain() {
	MSHookFunction((void *)SecItemAdd, (void *)iSpy_SecItemAdd, (void **)&orig_SecItemAdd);
	MSHookFunction((void *)SecItemUpdate, (void *)iSpy_SecItemUpdate, (void **)&orig_SecItemUpdate);
}


/********************************************
 *** Dynamic loader constructor function. ***
 ***     THIS IS THE iSpy ENTRY POINT     ***
 ********************************************

 This function will run the when the iSpy.dylib is loaded by the target app.
 It will run BEFORE *ANY* code in the target app.
 It runs BEFORE any of your "%hook ... %end" hooks.

 We use it to hijack C function calls. Extend as necessary.
 */
%ctor {
	NSLog(@"[iSpy] --- >>> Entry point <<< ---");
	NSString *bundleId = [[[NSBundle mainBundle] bundleIdentifier] copy];
	NSMutableDictionary *plist = [[NSMutableDictionary alloc] initWithContentsOfFile:@PREFERENCEFILE];
	NSMutableDictionary *appPlist = [[NSMutableDictionary alloc] initWithContentsOfFile:@APP_PREFERENCEFILE];
	NSString *appKey = [NSString stringWithFormat:@"targets_%@", bundleId];

	if ( ! plist) {

		NSLog(@"[iSpy] NOTICE: iSpy is disabled in the iDevice's settings panel, not injecting iSpy. Also, prefs file not found.");

	} else if ( ! [[plist objectForKey:@"settings_GlobalOnOff"] boolValue]) {

		NSLog(@"[iSpy] NOTICE: iSpy is disabled in the iDevice's settings panel, not injecting iSpy.");

	} else if ( ! appPlist) {

		NSLog(@"[iSpy] NOTICE: This application (%@) is not enabled in the iSpy settings panel (appPlist does not exist).", bundleId);

	} else if ( ! [[appPlist objectForKey:appKey] boolValue]) {

		NSLog(@"[iSpy] NOTICE: This application (%@) is not enabled in the iSpy settings panel; not injecting iSpy.", bundleId);

	} else {

		/* Green light to inject - Init all the things */
		heh();
		NSLog(@"[iSpy] This app (%@) is enabled for iSpy. To change this, disable it in the iSpy preferences panel.", bundleId);
		iSpy *mySpy = [iSpy sharedInstance];
		[mySpy initializeAllTheThings];

		// Initialize the BF log writing system
	    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	    NSString *documentsDirectory = [paths objectAtIndex:0];
	    NSLog(@"[iSpy] Initializing log writer(s) to %@...", documentsDirectory);
		ispy_init_logwriter(documentsDirectory);
		NSLog(@"[iSpy] Logging system is operational, no calls should be made to NSLog hereafter");

		/* After this point you should not be calling NSLog! */
		ispy_log_debug(LOG_GENERAL, "================================================================");
		ispy_log_debug(LOG_GENERAL, "iSpy starting for application %s", [[mySpy bundleId] UTF8String]);
		ispy_log_debug(LOG_GENERAL, "================================================================");
		ispy_log_debug(LOG_GENERAL, "[iSpy] Logging initialized!");

		// pre-init stuff
		%init(pre_init_group);

		// Load the objc_msgSend logging interface. This does NOT start logging objc_msgSend calls!
		// The log is controlled with bf_enable_msgSend_logging() and bf_disable_msgSend_logging(),
		// which are accessible via the /api/ calls, or via cycript using [[iSpy sharedInstance] msgSend_enableLogging]
		// and [[iSpy sharedInstance] msgSend_disableLogging]. You can also use the web GUI on/off button.
		ispy_log_debug(LOG_GENERAL, "[iSpy] Initializing objc_msgSend logging system");

//		dispatch_queue_t initQ = dispatch_queue_create("com.bishopfox.ispy.ctor", DISPATCH_QUEUE_SERIAL);
//		dispatch_sync(initQ, ^{
		NSLog(@"Whitelist stuff");
			whitelist_startup();
			whitelist_add_hardcoded_interesting_calls();
			bf_init_msgSend_logging();
//		});

		// Ok, this needs some explanation.
		// There seems to be some weird intermittent crash that occurs when hijack_on() collides with
		// something that uses/hooks syscalls; I suspect other MobileSubstrate .dylibs. By pausing for a second
		// here, we give other libs time to load and, since installing this sleep(1), I've never seen a
		// startup crash. This could probably do with extra investigation.
		//sleep(1); // testing

		NSLog(@"substrate replacement...");
		// Replace MSMessageHookEx with the iSpy variant if configured to do so
		if ([[plist objectForKey:@"settings_ReplaceMSubstrate"] boolValue]) {
			ispy_log_debug(LOG_GENERAL, "[iSpy] Anti-anti-swizzling: Replacing bf_MSHookFunctionEx() with cache-poisoning variant.");
			bf_init_substrate_replacement();
		}

		NSLog(@"msgSend logging...");
		// If configured in the prefs panel on iOS, enable objc_msgSend logging at app startup.
		// Call bf_disable_msgSend_logging() or [[iSpy sharedInstance] msgSend_disableLogging] or /api/whateveritis to turn it off.
		// Or turn it off in the prefs panel. Or the web GUI.
		if ([[plist objectForKey:@"settings_MsgSendLogging"] boolValue]) {
			ispy_log_debug(LOG_GENERAL, "[iSpy] msgsend: Enabling msgSend logging now!");
			bf_enable_msgSend_logging();
		} else {
			ispy_log_debug(LOG_GENERAL, "[iSpy] msgsend: Message logging disabled.");
		}

		NSLog(@"pinning...");
		// SSL pinning bypass?
		if ([[plist objectForKey:@"settings_SSLPinningBypass"] boolValue]) {
			ispy_log_debug(LOG_GENERAL, "[iSpy] SSL Certificate Pinning Bypass - ENABLED");
			%init(ssl_pinning_bypasses);
			bf_MSHookFunction((void *)SecTrustEvaluate, (void *)new_SecTrustEvaluate, (void **)&original_SecTrustEvaluate);
		} else {
			ispy_log_debug(LOG_GENERAL, "[iSpy] SSL Certificate Pinning Bypass - DISABLED");
		}

		NSLog(@"Instance tracking");
		// Enable instance tracking if configured to do so
		ispy_log_debug(LOG_GENERAL, "[iSpy] Initializing the instance tracker");
		InstanceTracker *tracker = [InstanceTracker sharedInstance];

		if ([[plist objectForKey:@"settings_InstanceTracking"] boolValue]) {
			ispy_log_debug(LOG_GENERAL, "[iSpy] Instance tracking is enabled in preferences. Starting up with tracker enabled.");
			[tracker start];
		} else {
			ispy_log_debug(LOG_GENERAL, "[iSpy] Instance tracking is disabled in preferences. Starting without.");
		}

		NSLog(@"Further init");
		// Load our own custom Theos hooks.
		%init(bf_group);

		// Initialize Cycript
		CYListenServer(12345);

		// Hook keychain functions
		hook_keychain();

		// Run security checks at least once
		// This will force iSpy to log insecure behaviors, such as poor keychain security or missing ASLR.
		[mySpy keyChainItems];
		[mySpy ASLR];

		// Start the iSpy web server
		ispy_log_debug(LOG_GENERAL, "[iSpy] Setup complete, passing control to the target app.");
	}

	NSLog(@"Release everything");
	/* Clean up */
	[bundleId release];
	[plist release];
	[appPlist release];

	return;
}

void heh() {
	NSLog(@" 777777777777777777777777777777777777              ,77777777777777777777777777+ ");
	NSLog(@"  777777777777777777777777777777777777            777777777777777777777777777   ");
	NSLog(@"   777777777777777777777777777777777777:         777777777777777777777777777    ");
	NSLog(@"    +77777777777777777777777777777777777         77777777777777777777777777     ");
	NSLog(@"      7777777777777777777777777777777777         7777777777777777777777777      ");
	NSLog(@"       777777777777777777777777777777777         77777777777777777777777:       ");
	NSLog(@"                              7777777777                                        ");
	NSLog(@"                              7777777777                                        ");
	NSLog(@"                              7777777777                                        ");
	NSLog(@"                              7777777777                                        ");
	NSLog(@"                              7777777777                                        ");
	NSLog(@"                              7777777777                                        ");
	NSLog(@"               777777777777777777777777          777777777777777                ");
	NSLog(@"                ~77777777777777777777            77777777777777                 ");
	NSLog(@"                  77777777777777777=             777777777777+                  ");
	NSLog(@"                   7777777777777777,             77777777777,                   ");
	NSLog(@"                    77777777777777777            7777777777                     ");
	NSLog(@"                     77777777777777777+          777777777                      ");
	NSLog(@"                              7777777777                                        ");
	NSLog(@"                              7777777777                                        ");
	NSLog(@"                              7777777777                                        ");
	NSLog(@"                              7777777777                                        ");
	NSLog(@"                              7777777777                                        ");
	NSLog(@"                              7777777777                                        ");
	NSLog(@"                              7777777777                                        ");
	NSLog(@"                               777777777                                        ");
	NSLog(@"                                I7777777                                        ");
	NSLog(@"                                 ,777777                                        ");
	NSLog(@"                                   77777                                        ");
	NSLog(@"                                    7777                                        ");
	NSLog(@"                                     777                                        ");
	NSLog(@"                                      I7                                        ");
	NSLog(@"                                       :                                        ");
}
