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
#include <CFNetwork/CFNetwork.h>
#include <CFNetwork/CFProxySupport.h>
#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFStream.h>
#import  <Security/Security.h>
#import  <Security/SecCertificate.h>
#import  <Foundation/NSJSONSerialization.h>
#import  <MobileCoreServices/MobileCoreServices.h>
#import  <QuartzCore/QuartzCore.h>
#import  <sqlite3.h>
#include "iSpy.common.h"
#include "iSpy.instance.h"
#include "iSpy.class.h"
#include "hooks_C_system_calls.h"
#include "hooks_CoreFoundation.h"
#include "HTTPKit/HTTP.h"
#import  "GRMustache/include/GRMustache.h"
#include "iSpy.msgSend.whitelist.h"

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


//
// The FILE pointers are used to deliver logs to the browser. 
// Defined in iSpy.web.xm
//
extern FILE *logReadFP[MAX_LOG+1];




/*************************************************************
 *** This is where you should put your own Theos tweaks.   ***
 *** This shit is important. Put them inside "%bf_group"   ***
 *** right here between these enormous comment sections.   ***
 *************************************************************/

%group bf_group // Don't change this %group unless you know what you're doing: your hooks won't load.
				// Don't close this %group with a %end, either - it comes later in the code.

/*
// An example of simple hooked method:
%hook FooBarBozClassXYZZY // An example...
- (id)someMethodOrOther {
	%log;
	return %orig;
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
	// call the original method first
	//%orig;

	NSLog(@"app: %@", [UIApplication sharedApplication]);
	
	// Only ever run this function once. We should probably use GCD for this.
	static bool hasRunOnce = false;
	if(hasRunOnce)
		return;
	hasRunOnce = true;

	// create a UIView object to hold the overlay
	UIView* view = [[UIView alloc] initWithFrame: CGRectMake(10,30,250,34)];
	
	// get the current window
	UIWindow* window = [UIApplication sharedApplication].keyWindow;
	if (!window) 
		window = [[UIApplication sharedApplication].windows objectAtIndex:0];
	
	// give the overlay a black background and rounded corners
	[view setBackgroundColor: [UIColor blackColor]];
	view.layer.cornerRadius = 10;
	view.layer.masksToBounds = YES;
	[view setContentMode:UIViewContentModeCenter];

	// Load th Bishop Fox logo into a UIImageView
	UIImageView *img = [[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:@"/var/www/iSpy/static/images/bf-orange-alpha.png"]];
	[img setContentMode:UIViewContentModeLeft];
	
	// give everything a nice BF orange border
	[[view layer] setBorderColor:[UIColor orangeColor].CGColor];
	[[view layer] setBorderWidth:2];
	
	// add the BF logo UIImageView to the left side of the overlay
	[view addSubview: img];

	// Add a "loading x%" label. 
	CGRect labelFrame = CGRectMake(52,1,250,28);
	UILabel *label = [[UILabel alloc] initWithFrame: labelFrame];
	[label setText: @"iSpy loading..."];
	[label setTextColor: [UIColor whiteColor]];
	[label setBackgroundColor: [UIColor blackColor]];
	
	// add the label to the view
	[view addSubview: label];

	// add the view to the window. This makes it visible
	[[[window subviews] objectAtIndex:0] addSubview:view];

	// Now we loop, writing the label @globalStatusStr (which is an exported global NSString), before sleeping and repeating.
	// @globalStatusStr can be set from anywhere, which makes it nice and easy to have each of the startup routines update
	// the GUI with a status update.
	// We dispatch this with GCD and send it to a background thread.
	// Note: we have to run the UI update code on the main thread for the UI to actually update/change.
	dispatch_queue_t bf_loading = dispatch_get_global_queue(0, 0); // default priority thread
	dispatch_async(bf_loading, ^{
		[label performSelectorOnMainThread:@selector(setText:) withObject:@"Showtime!" waitUntilDone:YES];
		sleep(3); // show the Showtime message...

		// clean up
		[view performSelectorOnMainThread:@selector(setHidden:) withObject:[NSNumber numberWithBool:true] waitUntilDone:YES];
		[view release];
	});
}


/***********************************************************************************
*** Do not add any %hook...%end sections after this, it will only end in tears. ***
***********************************************************************************/


%hook UIApplication

-(void) init {
	// Register for the "UIApplicationDidBecomeActiveNotification" notification.
	// Use it to trigger our GUI overlay.
	[[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
       	showGUIPopOver();
	}];
	return %orig;
}

// This is neat - it hooks all user input events and can be used to log them :)
-(void) sendEvent:(UIEvent*)event
{
    //NSLog(@"Area51:%@",event);
    NSSet *touches = [event allTouches];
    UITouch *touch = [touches anyObject];
    CALayer *touchedLayer = [touch view].layer;
    NSLog(@"Event: %@ // %@ // %@",NSStringFromClass([[touch view] class]), touchedLayer, [touch view]);

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
	bf_logwrite(LOG_GENERAL, "[iSpy] turning on objc_msgSend() logging to %s", BF_LOGFILE_MSGSEND);
	bf_enable_msgSend();
	bf_logwrite(LOG_GENERAL, "[iSpy] Turning on _stret, too");
	bf_enable_msgSend_stret();
	bf_logwrite(LOG_GENERAL, "[iSpy] Done.");
}

// Switch off logging. Calls to objc_msgSend will not be logged after this.
// You can call bf_enable_msgSend_logging() again to re-enable logging.
void bf_disable_msgSend_logging() {
	bf_logwrite(LOG_GENERAL, "[iSpy] turning off objc_msgSend() logging to %s", BF_LOGFILE_MSGSEND);
	bf_disable_msgSend();
	bf_disable_msgSend_stret();
}


// It's safe to call this repeatedly, unlike the original MSHookFunction().
void bf_MSHookFunction(void *func, void *repl, void **orig) {
	if(func != repl)
		MSHookFunction(func, repl, orig);
}

void bf_unHookFunction(void *func, void *repl, void *orig) {
	void *dummy;

	if(func == repl)
		MSHookFunction((void *)func, (void *)orig, (void **)&dummy);
}

/*
 hijack_on()

 This replaces standard C functions with our hijacked versions.
 It's called by this the iSpy constructor (see "%ctor", below).

 Reads the prefs file to determine which functions to actually hook.
 */
void hijack_on(NSMutableDictionary *plist) {
	BOOL enableAll = [[plist objectForKey:@"hijack_all_the_things"] boolValue];

	/* Std C Hooks */
	if ([[plist objectForKey:@"hijack_CFHTTPMessageCreateRequest"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: CFHTTPMessageCreateRequest() ");
		bf_MSHookFunction((void *) CFHTTPMessageCreateRequest, (void *) bf_CFHTTPMessageCreateRequest,
				(void **) &orig_CFHTTPMessageCreateRequest);
	}else {
		bf_unHookFunction((void *) CFHTTPMessageCreateRequest, (void *) bf_CFHTTPMessageCreateRequest,
				(void **) &orig_CFHTTPMessageCreateRequest);
	}

	if ([[plist objectForKey:@"hijack_CFNetworkCopySystemProxySettings"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: CFNetworkCopySystemProxySettings() ");
		bf_MSHookFunction((void *) CFNetworkCopySystemProxySettings, (void *) bf_CFNetworkCopySystemProxySettings,
				(void **) &orig_CFNetworkCopySystemProxySettings);
	}else {
		bf_unHookFunction((void *) CFNetworkCopySystemProxySettings, (void *) bf_CFNetworkCopySystemProxySettings,
				(void **) &orig_CFNetworkCopySystemProxySettings);
	}

	if ([[plist objectForKey:@"hijack_CFReadStreamCreateWithBytesNoCopy"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: CFReadStreamCreateWithBytesNoCopy() ");
		bf_MSHookFunction((void *) CFReadStreamCreateWithBytesNoCopy, (void *) bf_CFReadStreamCreateWithBytesNoCopy,
				(void **) &orig_CFReadStreamCreateWithBytesNoCopy);
	}else {
		bf_unHookFunction((void *) CFReadStreamCreateWithBytesNoCopy, (void *) bf_CFReadStreamCreateWithBytesNoCopy,
				(void **) &orig_CFReadStreamCreateWithBytesNoCopy);
	}

	if ([[plist objectForKey:@"hijack_CFReadStreamOpen"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: CFReadStreamOpen() ");
		bf_MSHookFunction((void *) CFReadStreamOpen, (void *) bf_CFReadStreamOpen,
				(void **) &orig_CFReadStreamOpen);
	}else {
		bf_unHookFunction((void *) CFReadStreamOpen, (void *) bf_CFReadStreamOpen,
				(void **) &orig_CFReadStreamOpen);
	}

	if ([[plist objectForKey:@"hijack_CFReadStreamRead"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: CFReadStreamRead() ");
		bf_MSHookFunction((void *) CFReadStreamRead, (void *) bf_CFReadStreamRead,
				(void **) &orig_CFReadStreamRead);
	}else {
		bf_unHookFunction((void *) CFReadStreamRead, (void *) bf_CFReadStreamRead,
				(void **) &orig_CFReadStreamRead);
	}

	if ([[plist objectForKey:@"hijack_CFReadStreamSetProperty"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: CFReadStreamSetProperty() ");
		bf_MSHookFunction((void *) CFReadStreamSetProperty, (void *) bf_CFReadStreamSetProperty,
				(void **) &orig_CFReadStreamSetProperty);
	}else {
		bf_unHookFunction((void *) CFReadStreamSetProperty, (void *) bf_CFReadStreamSetProperty,
				(void **) &orig_CFReadStreamSetProperty);
	}

	if ([[plist objectForKey:@"hijack_CFStreamCreatePairWithPeerSocketSignature"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: CFStreamCreatePairWithPeerSocketSignature() ");
		bf_MSHookFunction((void *) CFStreamCreatePairWithPeerSocketSignature, (void *) bf_CFStreamCreatePairWithPeerSocketSignature,
				(void **) &orig_CFStreamCreatePairWithPeerSocketSignature);
	}else {
		bf_unHookFunction((void *) CFStreamCreatePairWithPeerSocketSignature, (void *) bf_CFStreamCreatePairWithPeerSocketSignature,
				(void **) &orig_CFStreamCreatePairWithPeerSocketSignature);
	}

	if ([[plist objectForKey:@"hijack_CFStreamCreatePairWithSocket"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: CFStreamCreatePairWithSocket() ");
		bf_MSHookFunction((void *) CFStreamCreatePairWithSocket, (void *) bf_CFStreamCreatePairWithSocket,
				(void **) &orig_CFStreamCreatePairWithSocket);
	}else {
		bf_unHookFunction((void *) CFStreamCreatePairWithSocket, (void *) bf_CFStreamCreatePairWithSocket,
				(void **) &orig_CFStreamCreatePairWithSocket);
	}

	if ([[plist objectForKey:@"hijack_CFStreamCreatePairWithSocketToHost"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: CFStreamCreatePairWithSocketToHost() ");
		bf_MSHookFunction((void *) CFStreamCreatePairWithSocketToHost, (void *) bf_CFStreamCreatePairWithSocketToHost,
				(void **) &orig_CFStreamCreatePairWithSocketToHost);
	}else {
		bf_unHookFunction((void *) CFStreamCreatePairWithSocketToHost, (void *) bf_CFStreamCreatePairWithSocketToHost,
				(void **) &orig_CFStreamCreatePairWithSocketToHost);
	}

	if ([[plist objectForKey:@"hijack_CFURLCreateWithString"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: CFURLCreateWithString() ");
		bf_MSHookFunction((void *) CFURLCreateWithString, (void *) bf_CFURLCreateWithString,
				(void **) &orig_CFURLCreateWithString);
	}else {
		bf_unHookFunction((void *) CFURLCreateWithString, (void *) bf_CFURLCreateWithString,
				(void **) &orig_CFURLCreateWithString);
	}

	if ([[plist objectForKey:@"hijack_CFWriteStreamOpen"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: CFWriteStreamOpen() ");
		bf_MSHookFunction((void *) CFWriteStreamOpen, (void *) bf_CFWriteStreamOpen,
				(void **) &orig_CFWriteStreamOpen);
	}else {
		bf_unHookFunction((void *) CFWriteStreamOpen, (void *) bf_CFWriteStreamOpen,
				(void **) &orig_CFWriteStreamOpen);
	}

	if ([[plist objectForKey:@"hijack_CFWriteStreamSetProperty"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: CFWriteStreamSetProperty() ");
		bf_MSHookFunction((void *) CFWriteStreamSetProperty, (void *) bf_CFWriteStreamSetProperty,
				(void **) &orig_CFWriteStreamSetProperty);
	}else {
		bf_unHookFunction((void *) CFWriteStreamSetProperty, (void *) bf_CFWriteStreamSetProperty,
				(void **) &orig_CFWriteStreamSetProperty);
	}

	if ([[plist objectForKey:@"hijack_CFWriteStreamWrite"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: CFWriteStreamWrite() ");
		bf_MSHookFunction((void *) CFWriteStreamWrite, (void *) bf_CFWriteStreamWrite,
				(void **) &orig_CFWriteStreamWrite);
	}else {
		bf_unHookFunction((void *) CFWriteStreamWrite, (void *) bf_CFWriteStreamWrite,
				(void **) &orig_CFWriteStreamWrite);
	}

	if ([[plist objectForKey:@"hijack_SecCertificateCreateWithData"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: SecCertificateCreateWithData() ");
		bf_MSHookFunction((void *) SecCertificateCreateWithData, (void *) bf_SecCertificateCreateWithData,
				(void **) &orig_SecCertificateCreateWithData);
	}else {
		bf_unHookFunction((void *) SecCertificateCreateWithData, (void *) bf_SecCertificateCreateWithData,
				(void **) &orig_SecCertificateCreateWithData);
	}

	if ([[plist objectForKey:@"hijack_sysctl"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: sysctl() ");
		bf_MSHookFunction((void *) sysctl, (void *) bf_sysctl,
				(void **) &orig_sysctl);
	}else {
		bf_unHookFunction((void *) sysctl, (void *) bf_sysctl,
				(void **) &orig_sysctl);
	}

	if ([[plist objectForKey:@"hijack_accept"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: accept() ");
		bf_MSHookFunction((void *) accept, (void *) bf_accept,
				(void **) &orig_accept);
	}else {
		bf_unHookFunction((void *) accept, (void *) bf_accept,
				(void **) &orig_accept);
	}

	if ([[plist objectForKey:@"hijack_access"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: access() ");
		bf_MSHookFunction((void *) access, (void *) bf_access,
				(void **) &orig_access);
	}else {
		bf_unHookFunction((void *) access, (void *) bf_access,
				(void **) &orig_access);
	}

	if ([[plist objectForKey:@"hijack_acct"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: acct() ");
		bf_MSHookFunction((void *) acct, (void *) bf_acct,
				(void **) &orig_acct);
	}else {
		bf_unHookFunction((void *) acct, (void *) bf_acct,
				(void **) &orig_acct);
	}

	if ([[plist objectForKey:@"hijack_adjtime"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: adjtime() ");
		bf_MSHookFunction((void *) adjtime, (void *) bf_adjtime,
				(void **) &orig_adjtime);
	}else {
		bf_unHookFunction((void *) adjtime, (void *) bf_adjtime,
				(void **) &orig_adjtime);
	}

	if ([[plist objectForKey:@"hijack_bind"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: bind() ");
		bf_MSHookFunction((void *) bind, (void *) bf_bind,
				(void **) &orig_bind);
	}else {
		bf_unHookFunction((void *) bind, (void *) bf_bind,
				(void **) &orig_bind);
	}

	if ([[plist objectForKey:@"hijack_chdir"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: chdir() ");
		bf_MSHookFunction((void *) chdir, (void *) bf_chdir,
				(void **) &orig_chdir);
	}else {
		bf_unHookFunction((void *) chdir, (void *) bf_chdir,
				(void **) &orig_chdir);
	}

	if ([[plist objectForKey:@"hijack_chflags"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: chflags() ");
		bf_MSHookFunction((void *) chflags, (void *) bf_chflags,
				(void **) &orig_chflags);
	}else {
		bf_unHookFunction((void *) chflags, (void *) bf_chflags,
				(void **) &orig_chflags);
	}

	if ([[plist objectForKey:@"hijack_chmod"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: chmod() ");
		bf_MSHookFunction((void *) chmod, (void *) bf_chmod,
				(void **) &orig_chmod);
	}else {
		bf_unHookFunction((void *) chmod, (void *) bf_chmod,
				(void **) &orig_chmod);
	}

	if ([[plist objectForKey:@"hijack_chown"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: chown() ");
		bf_MSHookFunction((void *) chown, (void *) bf_chown,
				(void **) &orig_chown);
	}else {
		bf_unHookFunction((void *) chown, (void *) bf_chown,
				(void **) &orig_chown);
	}

	if ([[plist objectForKey:@"hijack_chroot"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: chroot() ");
		bf_MSHookFunction((void *) chroot, (void *) bf_chroot,
				(void **) &orig_chroot);
	}else {
		bf_unHookFunction((void *) chroot, (void *) bf_chroot,
				(void **) &orig_chroot);
	}

	if ([[plist objectForKey:@"hijack_close"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: close() ");
		bf_MSHookFunction((void *) close, (void *) bf_close,
				(void **) &orig_close);
	}else {
		bf_unHookFunction((void *) close, (void *) bf_close,
				(void **) &orig_close);
	}

	if ([[plist objectForKey:@"hijack_dup"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: dup() ");
		bf_MSHookFunction((void *) dup, (void *) bf_dup,
				(void **) &orig_dup);
	}else {
		bf_unHookFunction((void *) dup, (void *) bf_dup,
				(void **) &orig_dup);
	}

	if ([[plist objectForKey:@"hijack_dup2"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: dup2() ");
		bf_MSHookFunction((void *) dup2, (void *) bf_dup2,
				(void **) &orig_dup2);
	}else {
		bf_unHookFunction((void *) dup2, (void *) bf_dup2,
				(void **) &orig_dup2);
	}

	if ([[plist objectForKey:@"hijack_execve"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: execve() ");
		bf_MSHookFunction((void *) execve, (void *) bf_execve,
				(void **) &orig_execve);
	}else {
		bf_unHookFunction((void *) execve, (void *) bf_execve,
				(void **) &orig_execve);
	}

	if ([[plist objectForKey:@"hijack_exit"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: exit() ");
		bf_MSHookFunction((void *) exit, (void *) bf_exit,
				(void **) &orig_exit);
	}else {
		bf_unHookFunction((void *) exit, (void *) bf_exit,
				(void **) &orig_exit);
	}

	if ([[plist objectForKey:@"hijack_fchdir"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: fchdir() ");
		bf_MSHookFunction((void *) fchdir, (void *) bf_fchdir,
				(void **) &orig_fchdir);
	}else {
		bf_unHookFunction((void *) fchdir, (void *) bf_fchdir,
				(void **) &orig_fchdir);
	}

	if ([[plist objectForKey:@"hijack_fchflags"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: fchflags() ");
		bf_MSHookFunction((void *) fchflags, (void *) bf_fchflags,
				(void **) &orig_fchflags);
	}else {
		bf_unHookFunction((void *) fchflags, (void *) bf_fchflags,
				(void **) &orig_fchflags);
	}

	if ([[plist objectForKey:@"hijack_fchmod"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: fchmod() ");
		bf_MSHookFunction((void *) fchmod, (void *) bf_fchmod,
				(void **) &orig_fchmod);
	}else {
		bf_unHookFunction((void *) fchmod, (void *) bf_fchmod,
				(void **) &orig_fchmod);
	}

	if ([[plist objectForKey:@"hijack_fchown"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: fchown() ");
		bf_MSHookFunction((void *) fchown, (void *) bf_fchown,
				(void **) &orig_fchown);
	}else {
		bf_unHookFunction((void *) fchown, (void *) bf_fchown,
				(void **) &orig_fchown);
	}

	if ([[plist objectForKey:@"hijack_fcntl"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: fcntl() ");
		bf_MSHookFunction((void *) fcntl, (void *) bf_fcntl,
				(void **) &orig_fcntl);
	}else {
		bf_unHookFunction((void *) fcntl, (void *) bf_fcntl,
				(void **) &orig_fcntl);
	}

	if ([[plist objectForKey:@"hijack_flock"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: flock() ");
		bf_MSHookFunction((void *) flock, (void *) bf_flock,
				(void **) &orig_flock);
	}else {
		bf_unHookFunction((void *) flock, (void *) bf_flock,
				(void **) &orig_flock);
	}

	if ([[plist objectForKey:@"hijack_fork"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: fork() ");
		bf_MSHookFunction((void *) fork, (void *) bf_fork,
				(void **) &orig_fork);
	}else {
		bf_unHookFunction((void *) fork, (void *) bf_fork,
				(void **) &orig_fork);
	}

	if ([[plist objectForKey:@"hijack_fpathconf"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: fpathconf() ");
		bf_MSHookFunction((void *) fpathconf, (void *) bf_fpathconf,
				(void **) &orig_fpathconf);
	}else {
		bf_unHookFunction((void *) fpathconf, (void *) bf_fpathconf,
				(void **) &orig_fpathconf);
	}

	if ([[plist objectForKey:@"hijack_fstat"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: fstat() ");
		bf_MSHookFunction((void *) fstat, (void *) bf_fstat,
				(void **) &orig_fstat);
	}else {
		bf_unHookFunction((void *) fstat, (void *) bf_fstat,
				(void **) &orig_fstat);
	}

	if ([[plist objectForKey:@"hijack_fstatfs"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: fstatfs() ");
		bf_MSHookFunction((void *) fstatfs, (void *) bf_fstatfs,
				(void **) &orig_fstatfs);
	}else {
		bf_unHookFunction((void *) fstatfs, (void *) bf_fstatfs,
				(void **) &orig_fstatfs);
	}

	if ([[plist objectForKey:@"hijack_fsync"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: fsync() ");
		bf_MSHookFunction((void *) fsync, (void *) bf_fsync,
				(void **) &orig_fsync);
	}else {
		bf_unHookFunction((void *) fsync, (void *) bf_fsync,
				(void **) &orig_fsync);
	}

	if ([[plist objectForKey:@"hijack_ftruncate"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: ftruncate() ");
		bf_MSHookFunction((void *) ftruncate, (void *) bf_ftruncate,
				(void **) &orig_ftruncate);
	}else {
		bf_unHookFunction((void *) ftruncate, (void *) bf_ftruncate,
				(void **) &orig_ftruncate);
	}

	if ([[plist objectForKey:@"hijack_futimes"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: futimes() ");
		bf_MSHookFunction((void *) futimes, (void *) bf_futimes,
				(void **) &orig_futimes);
	}else {
		bf_unHookFunction((void *) futimes, (void *) bf_futimes,
				(void **) &orig_futimes);
	}

	if ([[plist objectForKey:@"hijack_getdtablesize"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: getdtablesize() ");
		bf_MSHookFunction((void *) getdtablesize, (void *) bf_getdtablesize,
				(void **) &orig_getdtablesize);
	}else {
		bf_unHookFunction((void *) getdtablesize, (void *) bf_getdtablesize,
				(void **) &orig_getdtablesize);
	}

	if ([[plist objectForKey:@"hijack_getegid"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: getegid() ");
		bf_MSHookFunction((void *) getegid, (void *) bf_getegid,
				(void **) &orig_getegid);
	}else {
		bf_unHookFunction((void *) getegid, (void *) bf_getegid,
				(void **) &orig_getegid);
	}

	if ([[plist objectForKey:@"hijack_geteuid"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: geteuid() ");
		bf_MSHookFunction((void *) geteuid, (void *) bf_geteuid,
				(void **) &orig_geteuid);
	}else {
		bf_unHookFunction((void *) geteuid, (void *) bf_geteuid,
				(void **) &orig_geteuid);
	}

	if ([[plist objectForKey:@"hijack_getfh"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: getfh() ");
		bf_MSHookFunction((void *) getfh, (void *) bf_getfh,
				(void **) &orig_getfh);
	}else {
		bf_unHookFunction((void *) getfh, (void *) bf_getfh,
				(void **) &orig_getfh);
	}

	if ([[plist objectForKey:@"hijack_getfsstat"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: getfsstat() ");
		bf_MSHookFunction((void *) getfsstat, (void *) bf_getfsstat,
				(void **) &orig_getfsstat);
	}else {
		bf_unHookFunction((void *) getfsstat, (void *) bf_getfsstat,
				(void **) &orig_getfsstat);
	}

	if ([[plist objectForKey:@"hijack_getgid"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: getgid() ");
		bf_MSHookFunction((void *) getgid, (void *) bf_getgid,
				(void **) &orig_getgid);
	}else {
		bf_unHookFunction((void *) getgid, (void *) bf_getgid,
				(void **) &orig_getgid);
	}

	if ([[plist objectForKey:@"hijack_getgroups"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: getgroups() ");
		bf_MSHookFunction((void *) getgroups, (void *) bf_getgroups,
				(void **) &orig_getgroups);
	}else {
		bf_unHookFunction((void *) getgroups, (void *) bf_getgroups,
				(void **) &orig_getgroups);
	}

	if ([[plist objectForKey:@"hijack_gethostuuid"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: gethostuuid() ");
		bf_MSHookFunction((void *) gethostuuid, (void *) bf_gethostuuid,
				(void **) &orig_gethostuuid);
	}else {
		bf_unHookFunction((void *) gethostuuid, (void *) bf_gethostuuid,
				(void **) &orig_gethostuuid);
	}

	if ([[plist objectForKey:@"hijack_getitimer"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: getitimer() ");
		bf_MSHookFunction((void *) getitimer, (void *) bf_getitimer,
				(void **) &orig_getitimer);
	}else {
		bf_unHookFunction((void *) getitimer, (void *) bf_getitimer,
				(void **) &orig_getitimer);
	}

	if ([[plist objectForKey:@"hijack_getlogin"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: getlogin() ");
		bf_MSHookFunction((void *) getlogin, (void *) bf_getlogin,
				(void **) &orig_getlogin);
	}else {
		bf_unHookFunction((void *) getlogin, (void *) bf_getlogin,
				(void **) &orig_getlogin);
	}

	if ([[plist objectForKey:@"hijack_getpeername"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: getpeername() ");
		bf_MSHookFunction((void *) getpeername, (void *) bf_getpeername,
				(void **) &orig_getpeername);
	}else {
		bf_unHookFunction((void *) getpeername, (void *) bf_getpeername,
				(void **) &orig_getpeername);
	}

	if ([[plist objectForKey:@"hijack_getpgid"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: getpgid() ");
		bf_MSHookFunction((void *) getpgid, (void *) bf_getpgid,
				(void **) &orig_getpgid);
	}else {
		bf_unHookFunction((void *) getpgid, (void *) bf_getpgid,
				(void **) &orig_getpgid);
	}

	if ([[plist objectForKey:@"hijack_getpgrp"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: getpgrp() ");
		bf_MSHookFunction((void *) getpgrp, (void *) bf_getpgrp,
				(void **) &orig_getpgrp);
	}else {
		bf_unHookFunction((void *) getpgrp, (void *) bf_getpgrp,
				(void **) &orig_getpgrp);
	}
/*
	if ([[plist objectForKey:@"hijack_getpid"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: getpid() ");
		bf_MSHookFunction((void *) getpid, (void *) bf_getpid,
				(void **) &orig_getpid);
	}else {
	bf_unHookFunction((void *) getpid, (void *) bf_getpid,
				(void **) &orig_getpid);
	}
*/
	if ([[plist objectForKey:@"hijack_getppid"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: getppid() ");
		bf_MSHookFunction((void *) getppid, (void *) bf_getppid,
				(void **) &orig_getppid);
	}else {
		bf_unHookFunction((void *) getppid, (void *) bf_getppid,
				(void **) &orig_getppid);
	}

	if ([[plist objectForKey:@"hijack_getpriority"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: getpriority() ");
		bf_MSHookFunction((void *) getpriority, (void *) bf_getpriority,
				(void **) &orig_getpriority);
	}else {
		bf_unHookFunction((void *) getpriority, (void *) bf_getpriority,
				(void **) &orig_getpriority);
	}
/*
	if ([[plist objectForKey:@"hijack_getrlimit"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: getrlimit() ");
		bf_MSHookFunction((void *) getrlimit, (void *) bf_getrlimit,
				(void **) &orig_getrlimit);
	}else {
	bf_unHookFunction((void *) getrlimit, (void *) bf_getrlimit,
				(void **) &orig_getrlimit);
	}
*/
	if ([[plist objectForKey:@"hijack_getrusage"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: getrusage() ");
		bf_MSHookFunction((void *) getrusage, (void *) bf_getrusage,
				(void **) &orig_getrusage);
	}else {
		bf_unHookFunction((void *) getrusage, (void *) bf_getrusage,
				(void **) &orig_getrusage);
	}

	if ([[plist objectForKey:@"hijack_getsockname"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: getsockname() ");
		bf_MSHookFunction((void *) getsockname, (void *) bf_getsockname,
				(void **) &orig_getsockname);
	}else {
		bf_unHookFunction((void *) getsockname, (void *) bf_getsockname,
				(void **) &orig_getsockname);
	}

	if ([[plist objectForKey:@"hijack_getsockopt"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: getsockopt() ");
		bf_MSHookFunction((void *) getsockopt, (void *) bf_getsockopt,
				(void **) &orig_getsockopt);
	}else {
		bf_unHookFunction((void *) getsockopt, (void *) bf_getsockopt,
				(void **) &orig_getsockopt);
	}

	if ([[plist objectForKey:@"hijack_gettimeofday"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: gettimeofday() ");
		bf_MSHookFunction((void *) gettimeofday, (void *) bf_gettimeofday,
				(void **) &orig_gettimeofday);
	}else {
		bf_unHookFunction((void *) gettimeofday, (void *) bf_gettimeofday,
				(void **) &orig_gettimeofday);
	}

	if ([[plist objectForKey:@"hijack_getuid"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: getuid() ");
		bf_MSHookFunction((void *) getuid, (void *) bf_getuid,
				(void **) &orig_getuid);
	}else {
		bf_unHookFunction((void *) getuid, (void *) bf_getuid,
				(void **) &orig_getuid);
	}

	if ([[plist objectForKey:@"hijack_ioctl"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: ioctl() ");
		bf_MSHookFunction((void *) ioctl, (void *) bf_ioctl,
				(void **) &orig_ioctl);
	}else {
		bf_unHookFunction((void *) ioctl, (void *) bf_ioctl,
				(void **) &orig_ioctl);
	}

	if ([[plist objectForKey:@"hijack_kill"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: kill() ");
		bf_MSHookFunction((void *) kill, (void *) bf_kill,
				(void **) &orig_kill);
	}else {
		bf_unHookFunction((void *) kill, (void *) bf_kill,
				(void **) &orig_kill);
	}

	if ([[plist objectForKey:@"hijack_link"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: link() ");
		bf_MSHookFunction((void *) link, (void *) bf_link,
				(void **) &orig_link);
	}else {
		bf_unHookFunction((void *) link, (void *) bf_link,
				(void **) &orig_link);
	}

	if ([[plist objectForKey:@"hijack_listen"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: listen() ");
		bf_MSHookFunction((void *) listen, (void *) bf_listen,
				(void **) &orig_listen);
	}else {
		bf_unHookFunction((void *) listen, (void *) bf_listen,
				(void **) &orig_listen);
	}

	if ([[plist objectForKey:@"hijack_lseek"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: lseek() ");
		bf_MSHookFunction((void *) lseek, (void *) bf_lseek,
				(void **) &orig_lseek);
	}else {
		bf_unHookFunction((void *) lseek, (void *) bf_lseek,
				(void **) &orig_lseek);
	}

	if ([[plist objectForKey:@"hijack_lstat"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: lstat() ");
		bf_MSHookFunction((void *) lstat, (void *) bf_lstat,
				(void **) &orig_lstat);
	}else {
		bf_unHookFunction((void *) lstat, (void *) bf_lstat,
				(void **) &orig_lstat);
	}

	if ([[plist objectForKey:@"hijack_madvise"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: madvise() ");
		bf_MSHookFunction((void *) madvise, (void *) bf_madvise,
				(void **) &orig_madvise);
	}else {
		bf_unHookFunction((void *) madvise, (void *) bf_madvise,
				(void **) &orig_madvise);
	}

	if ([[plist objectForKey:@"hijack_memcmp"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: memcmp() ");
		bf_MSHookFunction((void *) memcmp, (void *) bf_memcmp,
				(void **) &orig_memcmp);
	}else {
		bf_unHookFunction((void *) memcmp, (void *) bf_memcmp,
				(void **) &orig_memcmp);
	}

	if ([[plist objectForKey:@"hijack_mincore"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: mincore() ");
		bf_MSHookFunction((void *) mincore, (void *) bf_mincore,
				(void **) &orig_mincore);
	}else {
		bf_unHookFunction((void *) mincore, (void *) bf_mincore,
				(void **) &orig_mincore);
	}

	if ([[plist objectForKey:@"hijack_mkdir"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: mkdir() ");
		bf_MSHookFunction((void *) mkdir, (void *) bf_mkdir,
				(void **) &orig_mkdir);
	}else {
		bf_unHookFunction((void *) mkdir, (void *) bf_mkdir,
				(void **) &orig_mkdir);
	}

	if ([[plist objectForKey:@"hijack_mkfifo"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: mkfifo() ");
		bf_MSHookFunction((void *) mkfifo, (void *) bf_mkfifo,
				(void **) &orig_mkfifo);
	}else {
		bf_unHookFunction((void *) mkfifo, (void *) bf_mkfifo,
				(void **) &orig_mkfifo);
	}

	if ([[plist objectForKey:@"hijack_mknod"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: mknod() ");
		bf_MSHookFunction((void *) mknod, (void *) bf_mknod,
				(void **) &orig_mknod);
	}else {
		bf_unHookFunction((void *) mknod, (void *) bf_mknod,
				(void **) &orig_mknod);
	}

	if ([[plist objectForKey:@"hijack_mlock"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: mlock() ");
		bf_MSHookFunction((void *) mlock, (void *) bf_mlock,
				(void **) &orig_mlock);
	}else {
		bf_unHookFunction((void *) mlock, (void *) bf_mlock,
				(void **) &orig_mlock);
	}

	if ([[plist objectForKey:@"hijack_mmap"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: mmap() ");
		bf_MSHookFunction((void *) mmap, (void *) bf_mmap,
				(void **) &orig_mmap);
	}else {
		bf_unHookFunction((void *) mmap, (void *) bf_mmap,
				(void **) &orig_mmap);
	}

	if ([[plist objectForKey:@"hijack_mount"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: mount() ");
		bf_MSHookFunction((void *) mount, (void *) bf_mount,
				(void **) &orig_mount);
	}else {
		bf_unHookFunction((void *) mount, (void *) bf_mount,
				(void **) &orig_mount);
	}

	if ([[plist objectForKey:@"hijack_mprotect"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: mprotect() ");
		bf_MSHookFunction((void *) mprotect, (void *) bf_mprotect,
				(void **) &orig_mprotect);
	}else {
		bf_unHookFunction((void *) mprotect, (void *) bf_mprotect,
				(void **) &orig_mprotect);
	}

	if ([[plist objectForKey:@"hijack_msync"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: msync() ");
		bf_MSHookFunction((void *) msync, (void *) bf_msync,
				(void **) &orig_msync);
	}else {
		bf_unHookFunction((void *) msync, (void *) bf_msync,
				(void **) &orig_msync);
	}

	if ([[plist objectForKey:@"hijack_munlock"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: munlock() ");
		bf_MSHookFunction((void *) munlock, (void *) bf_munlock,
				(void **) &orig_munlock);
	}else {
		bf_unHookFunction((void *) munlock, (void *) bf_munlock,
				(void **) &orig_munlock);
	}

	if ([[plist objectForKey:@"hijack_munmap"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: munmap() ");
		bf_MSHookFunction((void *) munmap, (void *) bf_munmap,
				(void **) &orig_munmap);
	}else {
		bf_unHookFunction((void *) munmap, (void *) bf_munmap,
				(void **) &orig_munmap);
	}

	if ([[plist objectForKey:@"hijack_nfssvc"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: nfssvc() ");
		bf_MSHookFunction((void *) nfssvc, (void *) bf_nfssvc,
				(void **) &orig_nfssvc);
	}else {
		bf_unHookFunction((void *) nfssvc, (void *) bf_nfssvc,
				(void **) &orig_nfssvc);
	}

	if ([[plist objectForKey:@"hijack_open"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: open() ");
		bf_MSHookFunction((void *) open, (void *) bf_open,
				(void **) &orig_open);
	}else {
		bf_unHookFunction((void *) open, (void *) bf_open,
				(void **) &orig_open);
	}

	if ([[plist objectForKey:@"hijack_pathconf"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: pathconf() ");
		bf_MSHookFunction((void *) pathconf, (void *) bf_pathconf,
				(void **) &orig_pathconf);
	}else {
		bf_unHookFunction((void *) pathconf, (void *) bf_pathconf,
				(void **) &orig_pathconf);
	}

	if ([[plist objectForKey:@"hijack_pipe"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: pipe() ");
		bf_MSHookFunction((void *) pipe, (void *) bf_pipe,
				(void **) &orig_pipe);
	}else {
		bf_unHookFunction((void *) pipe, (void *) bf_pipe,
				(void **) &orig_pipe);
	}

	if ([[plist objectForKey:@"hijack_pread"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: pread() ");
		bf_MSHookFunction((void *) pread, (void *) bf_pread,
				(void **) &orig_pread);
	}else {
		bf_unHookFunction((void *) pread, (void *) bf_pread,
				(void **) &orig_pread);
	}

/*    if ([[plist objectForKey:@"hijack_ptrace"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: ptrace() ");
		bf_MSHookFunction((void *) ptrace, (void *) bf_ptrace,
				(void **) &orig_ptrace);
	}else {
		bf_unHookFunction((void *) ptrace, (void *) bf_ptrace,
				(void **) &orig_ptrace);
	}
*/
	if ([[plist objectForKey:@"hijack_pwrite"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: pwrite() ");
		bf_MSHookFunction((void *) pwrite, (void *) bf_pwrite,
				(void **) &orig_pwrite);
	}else {
		bf_unHookFunction((void *) pwrite, (void *) bf_pwrite,
				(void **) &orig_pwrite);
	}

	if ([[plist objectForKey:@"hijack_read"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: read() ");
		bf_MSHookFunction((void *) read, (void *) bf_read,
				(void **) &orig_read);
	}else {
		bf_unHookFunction((void *) read, (void *) bf_read,
				(void **) &orig_read);
	}

	if ([[plist objectForKey:@"hijack_readlink"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: readlink() ");
		bf_MSHookFunction((void *) readlink, (void *) bf_readlink,
				(void **) &orig_readlink);
	}else {
		bf_unHookFunction((void *) readlink, (void *) bf_readlink,
				(void **) &orig_readlink);
	}

	if ([[plist objectForKey:@"hijack_readv"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: readv() ");
		bf_MSHookFunction((void *) readv, (void *) bf_readv,
				(void **) &orig_readv);
	}else {
		bf_unHookFunction((void *) readv, (void *) bf_readv,
				(void **) &orig_readv);
	}

	if ([[plist objectForKey:@"hijack_reboot"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: reboot() ");
		bf_MSHookFunction((void *) reboot, (void *) bf_reboot,
				(void **) &orig_reboot);
	}else {
		bf_unHookFunction((void *) reboot, (void *) bf_reboot,
				(void **) &orig_reboot);
	}

	if ([[plist objectForKey:@"hijack_recv"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: recv() ");
		bf_MSHookFunction((void *) recv, (void *) bf_recv,
				(void **) &orig_recv);
	}else {
		bf_unHookFunction((void *) recv, (void *) bf_recv,
				(void **) &orig_recv);
	}

	if ([[plist objectForKey:@"hijack_recvmsg"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: recvmsg() ");
		bf_MSHookFunction((void *) recvmsg, (void *) bf_recvmsg,
				(void **) &orig_recvmsg);
	}else {
		bf_unHookFunction((void *) recvmsg, (void *) bf_recvmsg,
				(void **) &orig_recvmsg);
	}

	if ([[plist objectForKey:@"hijack_rename"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: rename() ");
		bf_MSHookFunction((void *) rename, (void *) bf_rename,
				(void **) &orig_rename);
	}else {
		bf_unHookFunction((void *) rename, (void *) bf_rename,
				(void **) &orig_rename);
	}

	if ([[plist objectForKey:@"hijack_revoke"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: revoke() ");
		bf_MSHookFunction((void *) revoke, (void *) bf_revoke,
				(void **) &orig_revoke);
	}else {
		bf_unHookFunction((void *) revoke, (void *) bf_revoke,
				(void **) &orig_revoke);
	}

	if ([[plist objectForKey:@"hijack_rmdir"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: rmdir() ");
		bf_MSHookFunction((void *) rmdir, (void *) bf_rmdir,
				(void **) &orig_rmdir);
	}else {
		bf_unHookFunction((void *) rmdir, (void *) bf_rmdir,
				(void **) &orig_rmdir);
	}

	if ([[plist objectForKey:@"hijack_select"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: select() ");
		bf_MSHookFunction((void *) select, (void *) bf_select,
				(void **) &orig_select);
	}else {
		bf_unHookFunction((void *) select, (void *) bf_select,
				(void **) &orig_select);
	}

	if ([[plist objectForKey:@"hijack_sendmsg"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: sendmsg() ");
		bf_MSHookFunction((void *) sendmsg, (void *) bf_sendmsg,
				(void **) &orig_sendmsg);
	}else {
		bf_unHookFunction((void *) sendmsg, (void *) bf_sendmsg,
				(void **) &orig_sendmsg);
	}

	if ([[plist objectForKey:@"hijack_sendto"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: sendto() ");
		bf_MSHookFunction((void *) sendto, (void *) bf_sendto,
				(void **) &orig_sendto);
	}else {
		bf_unHookFunction((void *) sendto, (void *) bf_sendto,
				(void **) &orig_sendto);
	}

	if ([[plist objectForKey:@"hijack_setegid"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: setegid() ");
		bf_MSHookFunction((void *) setegid, (void *) bf_setegid,
				(void **) &orig_setegid);
	}else {
		bf_unHookFunction((void *) setegid, (void *) bf_setegid,
				(void **) &orig_setegid);
	}

	if ([[plist objectForKey:@"hijack_seteuid"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: seteuid() ");
		bf_MSHookFunction((void *) seteuid, (void *) bf_seteuid,
				(void **) &orig_seteuid);
	}else {
		bf_unHookFunction((void *) seteuid, (void *) bf_seteuid,
				(void **) &orig_seteuid);
	}

	if ([[plist objectForKey:@"hijack_setgid"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: setgid() ");
		bf_MSHookFunction((void *) setgid, (void *) bf_setgid,
				(void **) &orig_setgid);
	}else {
		bf_unHookFunction((void *) setgid, (void *) bf_setgid,
				(void **) &orig_setgid);
	}

	if ([[plist objectForKey:@"hijack_setgroups"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: setgroups() ");
		bf_MSHookFunction((void *) setgroups, (void *) bf_setgroups,
				(void **) &orig_setgroups);
	}else {
		bf_unHookFunction((void *) setgroups, (void *) bf_setgroups,
				(void **) &orig_setgroups);
	}

	if ([[plist objectForKey:@"hijack_setitimer"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: setitimer() ");
		bf_MSHookFunction((void *) setitimer, (void *) bf_setitimer,
				(void **) &orig_setitimer);
	}else {
		bf_unHookFunction((void *) setitimer, (void *) bf_setitimer,
				(void **) &orig_setitimer);
	}

	if ([[plist objectForKey:@"hijack_setlogin"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: setlogin() ");
		bf_MSHookFunction((void *) setlogin, (void *) bf_setlogin,
				(void **) &orig_setlogin);
	}else {
		bf_unHookFunction((void *) setlogin, (void *) bf_setlogin,
				(void **) &orig_setlogin);
	}

	if ([[plist objectForKey:@"hijack_setpgid"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: setpgid() ");
		bf_MSHookFunction((void *) setpgid, (void *) bf_setpgid,
				(void **) &orig_setpgid);
	}else {
		bf_unHookFunction((void *) setpgid, (void *) bf_setpgid,
				(void **) &orig_setpgid);
	}

	if ([[plist objectForKey:@"hijack_setpriority"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: setpriority() ");
		bf_MSHookFunction((void *) setpriority, (void *) bf_setpriority,
				(void **) &orig_setpriority);
	}else {
		bf_unHookFunction((void *) setpriority, (void *) bf_setpriority,
				(void **) &orig_setpriority);
	}

	if ([[plist objectForKey:@"hijack_setregid"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: setregid() ");
		bf_MSHookFunction((void *) setregid, (void *) bf_setregid,
				(void **) &orig_setregid);
	}else {
		bf_unHookFunction((void *) setregid, (void *) bf_setregid,
				(void **) &orig_setregid);
	}

	if ([[plist objectForKey:@"hijack_setreuid"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: setreuid() ");
		bf_MSHookFunction((void *) setreuid, (void *) bf_setreuid,
				(void **) &orig_setreuid);
	}else {
		bf_unHookFunction((void *) setreuid, (void *) bf_setreuid,
				(void **) &orig_setreuid);
	}

	if ([[plist objectForKey:@"hijack_setrlimit"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: setrlimit() ");
		bf_MSHookFunction((void *) setrlimit, (void *) bf_setrlimit,
				(void **) &orig_setrlimit);
	}else {
		bf_unHookFunction((void *) setrlimit, (void *) bf_setrlimit,
				(void **) &orig_setrlimit);
	}
/*
	if ([[plist objectForKey:@"hijack_setsid"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: setsid() ");
		bf_MSHookFunction((void *) setsid, (void *) bf_setsid,
				(void **) &orig_setsid);
	}else {
	bf_unHookFunction((void *) setsid, (void *) bf_setsid,
				(void **) &orig_setsid);
	}
*/
	if ([[plist objectForKey:@"hijack_setsockopt"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: setsockopt() ");
		bf_MSHookFunction((void *) setsockopt, (void *) bf_setsockopt,
				(void **) &orig_setsockopt);
	}else {
		bf_unHookFunction((void *) setsockopt, (void *) bf_setsockopt,
				(void **) &orig_setsockopt);
	}

	if ([[plist objectForKey:@"hijack_settimeofday"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: settimeofday() ");
		bf_MSHookFunction((void *) settimeofday, (void *) bf_settimeofday,
				(void **) &orig_settimeofday);
	}else {
		bf_unHookFunction((void *) settimeofday, (void *) bf_settimeofday,
				(void **) &orig_settimeofday);
	}

	if ([[plist objectForKey:@"hijack_setuid"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: setuid() ");
		bf_MSHookFunction((void *) setuid, (void *) bf_setuid,
				(void **) &orig_setuid);
	}else {
		bf_unHookFunction((void *) setuid, (void *) bf_setuid,
				(void **) &orig_setuid);
	}

	if ([[plist objectForKey:@"hijack_shutdown"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: shutdown() ");
		bf_MSHookFunction((void *) shutdown, (void *) bf_shutdown,
				(void **) &orig_shutdown);
	}else {
		bf_unHookFunction((void *) shutdown, (void *) bf_shutdown,
				(void **) &orig_shutdown);
	}

	if ([[plist objectForKey:@"hijack_sigaction"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: sigaction() ");
		bf_MSHookFunction((void *) sigaction, (void *) bf_sigaction,
				(void **) &orig_sigaction);
	}else {
		bf_unHookFunction((void *) sigaction, (void *) bf_sigaction,
				(void **) &orig_sigaction);
	}

	if ([[plist objectForKey:@"hijack_sigpending"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: sigpending() ");
		bf_MSHookFunction((void *) sigpending, (void *) bf_sigpending,
				(void **) &orig_sigpending);
	}else {
		bf_unHookFunction((void *) sigpending, (void *) bf_sigpending,
				(void **) &orig_sigpending);
	}

	if ([[plist objectForKey:@"hijack_sigprocmask"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: sigprocmask() ");
		bf_MSHookFunction((void *) sigprocmask, (void *) bf_sigprocmask,
				(void **) &orig_sigprocmask);
	}else {
		bf_unHookFunction((void *) sigprocmask, (void *) bf_sigprocmask,
				(void **) &orig_sigprocmask);
	}

	if ([[plist objectForKey:@"hijack_sigsuspend"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: sigsuspend() ");
		bf_MSHookFunction((void *) sigsuspend, (void *) bf_sigsuspend,
				(void **) &orig_sigsuspend);
	}else {
		bf_unHookFunction((void *) sigsuspend, (void *) bf_sigsuspend,
				(void **) &orig_sigsuspend);
	}

	if ([[plist objectForKey:@"hijack_socket"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: socket() ");
		bf_MSHookFunction((void *) socket, (void *) bf_socket,
				(void **) &orig_socket);
	}else {
		bf_unHookFunction((void *) socket, (void *) bf_socket,
				(void **) &orig_socket);
	}

	if ([[plist objectForKey:@"hijack_socketpair"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: socketpair() ");
		bf_MSHookFunction((void *) socketpair, (void *) bf_socketpair,
				(void **) &orig_socketpair);
	}else {
		bf_unHookFunction((void *) socketpair, (void *) bf_socketpair,
				(void **) &orig_socketpair);
	}

	if ([[plist objectForKey:@"hijack_stat"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: stat() ");
		bf_MSHookFunction((void *) stat, (void *) bf_stat,
				(void **) &orig_stat);
	}else {
		bf_unHookFunction((void *) stat, (void *) bf_stat,
				(void **) &orig_stat);
	}

	if ([[plist objectForKey:@"hijack_statfs"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: statfs() ");
		bf_MSHookFunction((void *) statfs, (void *) bf_statfs,
				(void **) &orig_statfs);
	}else {
		bf_unHookFunction((void *) statfs, (void *) bf_statfs,
				(void **) &orig_statfs);
	}

	if ([[plist objectForKey:@"hijack_strcmp"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: strcmp(). If you experience crashes try turning this off. It can *really* slow down your app!");
		bf_MSHookFunction((void *) strcmp, (void *) bf_strcmp,
				(void **) &orig_strcmp);
	}else {
		bf_unHookFunction((void *) strcmp, (void *) bf_strcmp,
				(void **) &orig_strcmp);
	}

/*    if ([[plist objectForKey:@"hijack_strncmp"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: strncmp() ");
		bf_MSHookFunction((void *) strncmp, (void *) bf_strncmp,
				(void **) &orig_strncmp);
	}else {
	bf_unHookFunction((void *) strncmp, (void *) bf_strncmp,
				(void **) &orig_strncmp);
	}
*/
	if ([[plist objectForKey:@"hijack_swapon"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: swapon() ");
		bf_MSHookFunction((void *) swapon, (void *) bf_swapon,
				(void **) &orig_swapon);
	}else {
		bf_unHookFunction((void *) swapon, (void *) bf_swapon,
				(void **) &orig_swapon);
	}

	if ([[plist objectForKey:@"hijack_symlink"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: symlink() ");
		bf_MSHookFunction((void *) symlink, (void *) bf_symlink,
				(void **) &orig_symlink);
	}else {
		bf_unHookFunction((void *) symlink, (void *) bf_symlink,
				(void **) &orig_symlink);
	}

	if ([[plist objectForKey:@"hijack_sync"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: sync() ");
		bf_MSHookFunction((void *) sync, (void *) bf_sync,
				(void **) &orig_sync);
	}else {
		bf_unHookFunction((void *) sync, (void *) bf_sync,
				(void **) &orig_sync);
	}

	if ([[plist objectForKey:@"hijack_truncate"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: truncate() ");
		bf_MSHookFunction((void *) truncate, (void *) bf_truncate,
				(void **) &orig_truncate);
	}else {
		bf_unHookFunction((void *) truncate, (void *) bf_truncate,
				(void **) &orig_truncate);
	}

	if ([[plist objectForKey:@"hijack_umask"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: umask() ");
		bf_MSHookFunction((void *) umask, (void *) bf_umask,
				(void **) &orig_umask);
	}else {
		bf_unHookFunction((void *) umask, (void *) bf_umask,
				(void **) &orig_umask);
	}

	if ([[plist objectForKey:@"hijack_undelete"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: undelete() ");
		bf_MSHookFunction((void *) undelete, (void *) bf_undelete,
				(void **) &orig_undelete);
	}else {
		bf_unHookFunction((void *) undelete, (void *) bf_undelete,
				(void **) &orig_undelete);
	}

	if ([[plist objectForKey:@"hijack_unlink"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: unlink() ");
		bf_MSHookFunction((void *) unlink, (void *) bf_unlink,
				(void **) &orig_unlink);
	}else {
		bf_unHookFunction((void *) unlink, (void *) bf_unlink,
				(void **) &orig_unlink);
	}

	if ([[plist objectForKey:@"hijack_unmount"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: unmount() ");
		bf_MSHookFunction((void *) unmount, (void *) bf_unmount,
				(void **) &orig_unmount);
	}else {
		bf_unHookFunction((void *) unmount, (void *) bf_unmount,
				(void **) &orig_unmount);
	}

	if ([[plist objectForKey:@"hijack_utimes"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: utimes() ");
		bf_MSHookFunction((void *) utimes, (void *) bf_utimes,
				(void **) &orig_utimes);
	}else {
		bf_unHookFunction((void *) utimes, (void *) bf_utimes,
				(void **) &orig_utimes);
	}

	if ([[plist objectForKey:@"hijack_vfork"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: vfork() ");
		bf_MSHookFunction((void *) vfork, (void *) bf_vfork,
				(void **) &orig_vfork);
	}else {
		bf_unHookFunction((void *) vfork, (void *) bf_vfork,
				(void **) &orig_vfork);
	}

	if ([[plist objectForKey:@"hijack_wait4"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: wait4() ");
		bf_MSHookFunction((void *) wait4, (void *) bf_wait4,
				(void **) &orig_wait4);
	}else {
		bf_unHookFunction((void *) wait4, (void *) bf_wait4,
				(void **) &orig_wait4);
	}

	if ([[plist objectForKey:@"hijack_waitid"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: waitid() ");
		bf_MSHookFunction((void *) waitid, (void *) bf_waitid,
				(void **) &orig_waitid);
	}else {
		bf_unHookFunction((void *) waitid, (void *) bf_waitid,
				(void **) &orig_waitid);
	}

/*
	if ([[plist objectForKey:@"hijack_write"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: write() ");
		bf_MSHookFunction((void *) write, (void *) bf_write,
				(void **) &orig_write);
	}else {
	bf_unHookFunction((void *) write, (void *) bf_write,
				(void **) &orig_write);
	}
*/
	if ([[plist objectForKey:@"hijack_writev"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: writev() ");
		bf_MSHookFunction((void *) writev, (void *) bf_writev,
				(void **) &orig_writev);
	}else {
		bf_unHookFunction((void *) writev, (void *) bf_writev,
				(void **) &orig_writev);
	}


	/* User Input Hooks */
	if ([[plist objectForKey:@"hijack_dyld_image_count"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: _dyld_image_count() ");
		bf_MSHookFunction((void *) _dyld_image_count, (void *) bf_dyld_image_count,
				(void **) &orig_dyld_image_count);
	}else {
		bf_unHookFunction((void *) _dyld_image_count, (void *) bf_dyld_image_count,
				(void **) &orig_dyld_image_count);
	}
	if ([[plist objectForKey:@"hijack_dyld_get_image_name"] boolValue] || enableAll) {
		bf_logwrite(LOG_GENERAL, "[iSpy] hijack function: _dyld_get_image_name() ");
		bf_MSHookFunction((void *) _dyld_get_image_name,
				(void *) bf_dyld_get_image_name, (void **) &orig_dyld_get_image_name);
	} else {
		bf_unHookFunction((void *) _dyld_get_image_name,
				(void *) bf_dyld_get_image_name, (void **) &orig_dyld_get_image_name);
	}

	bf_logwrite(LOG_GENERAL, "[iSpy] hijack_on: Successfully placed hooks!");
}

%end // end of UIApplication class extension.



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
	This code is from TrustMe: https://github.com/intrepidusgroup/trustme?source=cc
	Define the new SecTrustEvaluate function
 */
OSStatus new_SecTrustEvaluate(SecTrustRef trust, SecTrustResultType *result) {
	bf_logwrite(LOG_GENERAL, "[iSpy] trustme: Intercepting SecTrustEvaluate() call");
	*result = kSecTrustResultProceed;
	return errSecSuccess;
}

/*
	This code is from TrustMe: https://github.com/intrepidusgroup/trustme?source=cc
	Function signature for original SecTrustEvaluate
 */
static OSStatus (*original_SecTrustEvaluate)(SecTrustRef trust,
		SecTrustResultType *result);

// These are useful functions that we can use as overrides with MSHookMessageEx and bf_MSHookFunction.
EXPORT int return_false() {
	return 0;
}

EXPORT int return_true() {
	return 1;
}


/*   
 ********************************************
 *** Dynamic loader constructor function. *** 
 *** THIS IS THE iSpy ENTRY POINT     ***
 ********************************************
 
 This function will run the when the iSpy.dylib is loaded by the target app.
 It will run BEFORE *ANY* code in the target app.
 It runs BEFORE any of your "%hook ... %end" hooks.
 
 We use it to hijack C function calls. Extend as necessary.
 */
%ctor {
	NSLog(@"iSpy: entry point.");

	iSpy *mySpy = [iSpy sharedInstance];

	// Setup SQLite threading so that the SQLite library is 100% responsible for thread safety.
	// This must be the first thing we do, otherwise SQLite will already have been initialized and 
	// this call with silently fail.
	int configresult = sqlite3_config(SQLITE_CONFIG_SERIALIZED);
	
	// Load preferences. Abort if prefs file not found.
	NSLog(@"iSpy: initializing prefs for %@", [mySpy bundleId]);
	NSMutableDictionary* plist = [[NSMutableDictionary alloc] initWithContentsOfFile:@PREFERENCEFILE];
	if (!plist) {
		NSLog(@"[iSpy] NOTICE: iSpy is disabled in the iDevice's settings panel, not injecting iSpy. Also, prefs file not found.");
		return;
	}

	// Check to see if iSpy is enabled globally
	if ( ! [[plist objectForKey:@"settings_GlobalOnOff"] boolValue]) {
		NSLog(@"[iSpy] NOTICE: iSpy is disabled in the iDevice's settings panel, not injecting iSpy.");
		return;
	}

	// Check to see if iSpy is enabled for this specific application
	NSMutableDictionary* appPlist = [[NSMutableDictionary alloc] initWithContentsOfFile:@APP_PREFERENCEFILE];
	if (!appPlist) {
		NSLog(@"[iSpy] NOTICE: This application (%@) is not enabled in the iSpy settings panel. Not injecting iSpy.", [mySpy bundleId]);
		return;
	}
	
	NSString *appKey = [NSString stringWithFormat:@"targets_%@", [mySpy bundleId]];
	if ( ! [[appPlist objectForKey:appKey] boolValue]) {
		NSLog(@"[iSpy] NOTICE: This application (%@) is not enabled in the iSpy settings panel. Not injecting iSpy.", [mySpy bundleId]);
		return;
	}
	
	NSLog(@"iSpy: checking for running iSpy...");
	// Test to see if iSpy is already loaded in another running app. Abandon ship if so.
	/*NSError* error = nil;
	NSURL *bfURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%d/ping", WEBSERVER_PORT]];
	NSString* result = [NSString stringWithContentsOfURL:bfURL encoding:NSASCIIStringEncoding error:&error];
	if( result ) {
		NSLog(@"[iSpy] ERROR: Already running in another app!");
		return;
	}
*/

	// Initialize the BF log writing system
	NSLog(@"[iSpy] This app (%@) is enabled for iSpy. To change this, disable it in the iSpy preferences panel.", [mySpy bundleId]);
	NSLog(@"[iSpy] Showtime!");
	NSLog(@"[iSpy] Initializing logwriter.");
	bf_init_logwriter();

	NSLog(@"[iSpy] Done! Logging will continue in /tmp/bf_general.log");
	bf_logwrite(LOG_GENERAL, "================================================================");
	bf_logwrite(LOG_GENERAL, "iSpy starting for application %s", [[mySpy bundleId] UTF8String]);
	bf_logwrite(LOG_GENERAL, "================================================================");
	bf_logwrite(LOG_GENERAL, "[iSpy] Logging initialized!");
	bf_logwrite(LOG_GENERAL, "[iSpy] sqlite_config() returned %d (success=0)", configresult);

	// Ok, this needs some explanation.
	// There seems to be some weird intermittent crash that occurs when hijack_on() collides with
	// something that uses/hooks syscalls; I suspect other MobileSubstrate .dylibs. By pausing for a second
	// here, we give other libs time to load and, since installing this sleep(1), I've never seen a
	// startup crash. This could probably do with extra investigation.
	sleep(1); // testing
	
	// Hook all the things necessary for strace-style logging
	hijack_on(plist);
	
	// Replace MSMessageHookEx with the iSpy variant if configured to do so
	if ([[plist objectForKey:@"settings_ReplaceMSubstrate"] boolValue]) {
		bf_logwrite(LOG_GENERAL, "[iSpy] Anti-anti-swizzling: Replacing bf_MSHookFunctionEx() with cache-poisoning variant.");
		bf_init_substrate_replacement(); 
	}

	// If configured in the prefs panel on iOS, enable objc_msgSend logging at app startup.
	// Call bf_disable_msgSend_logging() or [[iSpy sharedInstance] msgSend_disableLogging] or /api/whateveritis to turn it off.
	// Or turn it off in the prefs panel. Or the web GUI.
	if ([[plist objectForKey:@"settings_MsgSendLogging"] boolValue]) {
		bf_logwrite(LOG_GENERAL, "[iSpy] msgsend: Enabling msgSend logging now! Check " BF_LOGFILE_MSGSEND " on your device.");
		bf_enable_msgSend_logging(); 
	} else {
		bf_logwrite(LOG_GENERAL, "[iSpy] msgsend: Message logging disabled.");
	}

	// SSL pinning bypass?
	if ([[plist objectForKey:@"settings_TrustMeBypass"] boolValue]) {
		bf_logwrite(LOG_GENERAL, "[iSpy] trustme: SSL Certificate Pinning Bypass - ENABLED");
		bf_MSHookFunction((void *)SecTrustEvaluate, (void *)new_SecTrustEvaluate, (void **)&original_SecTrustEvaluate);
	} else {
		bf_logwrite(LOG_GENERAL, "[iSpy] trustme: SSL Certificate Pinning Bypass - DISABLED");
	}

	// open up the log files for read access by iSpy web clients
	logReadFP[LOG_STRACE] = fopen(BF_LOGFILE_STRACE, "r");
	logReadFP[LOG_GENERAL] = fopen(BF_LOGFILE_GENERAL, "r");
	logReadFP[LOG_HTTP] = fopen(BF_LOGFILE_HTTP, "r");
	logReadFP[LOG_MSGSEND] = fopen(BF_LOGFILE_MSGSEND, "r");
	logReadFP[LOG_TCPIP] = fopen(BF_LOGFILE_TCPIP, "r");

	// Load the objc_msgSend logging interface. This does NOT start logging objc_msgSend calls!
	// The log is controlled with bf_enable_msgSend_logging() and bf_disable_msgSend_logging(),
	// which are accessible via the /api/ calls, or via cycript using [[iSpy sharedInstance] msgSend_enableLogging] 
	// and [[iSpy sharedInstance] msgSend_disableLogging]. You can also use the web GUI on/off button.
	bf_logwrite(LOG_GENERAL, "[iSpy] Initializing objc_msgSend logging system");
	bf_init_msgSend_logging();

	// Start the iSpy web server
	%init(pre_init_group);
	[[mySpy webServer] startWebServices];

	// Enable instance tracking if configured to do so
	bf_logwrite(LOG_GENERAL, "[iSpy] Initializing the instance tracker");
	bf_init_instance_tracker();
	if ([[plist objectForKey:@"settings_InstanceTracking"] boolValue]) {
		bf_logwrite(LOG_GENERAL, "[iSpy] Instance tracking is enabled in preferences. Starting up with tracker enabled.");
		bf_enable_instance_tracker();
	} else {
		bf_logwrite(LOG_GENERAL, "[iSpy] Instance tracking is disabled in preferences. Starting without.");
	}

	// Load our own custom Theos hooks.            
	%init(bf_group);   

	// Lastly, initialize objc_msgSend logging whitelist
	bf_objc_msgSend_whitelist_startup();

	[plist release];
	[appPlist release];
	bf_logwrite(LOG_GENERAL, "[iSpy] Setup complete, passing control to the target app.");
}


