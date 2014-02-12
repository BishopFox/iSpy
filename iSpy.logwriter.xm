/*
    iSpy - Bishop Fox iOS hooking framework.

    Crappy logging framework. More complex version TBD.

 */

#include <stack>
#include <fcntl.h>
#include <stdio.h>
#include <dlfcn.h>
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
#include <objc/objc.h>
#include <ifaddrs.h>
#include <time.h>
#include <arpa/inet.h>
#include <mach-o/dyld.h>
#include <netinet/in.h>
#import  <Security/Security.h>
#import  <Security/SecCertificate.h>
#include <CFNetwork/CFNetwork.h>
#include <CFNetwork/CFProxySupport.h>
#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFStream.h>
#import <Foundation/NSJSONSerialization.h>
#include "iSpy.common.h"
#include "hooks_C_system_calls.h"

#define ACTUALLY_WRITE_LOGS 

// If we use any hooked calls within the log writer, we must use the original (unhooked) versions.
// Simply declare them extern and copy from hook_C_system_calls.xm
// MAKE ABSOLUTELY SURE that orig_funcname = funcname in hook_C_system_calls.xm
// See the following functions in hook_C_system_calls.xm for examples.
extern int (*orig_gettimeofday)(struct timeval *tp, void *tzp);
extern size_t (*orig_write)(int fd, const void * cbuf, user_size_t nbyte);

static pthread_mutex_t mutex_log_writer = PTHREAD_MUTEX_INITIALIZER;
static int logFile[MAX_LOG+1];
static BOOL logIsEnabled[MAX_LOG+1];

EXPORT void bf_clear_log(int facility) {
	if(facility < 0 || facility > MAX_LOG)
		return;

	close(logFile[facility]);
	switch(facility) {
		case LOG_STRACE:
			logFile[LOG_STRACE] = open(BF_LOGFILE_STRACE, O_RDWR | O_TRUNC  | O_CREAT); // yay error checking
			break;
		case LOG_MSGSEND:
			logFile[LOG_MSGSEND] = open(BF_LOGFILE_MSGSEND, O_RDWR | O_TRUNC  | O_CREAT);
			break;
		case LOG_GENERAL:
			logFile[LOG_GENERAL] = open(BF_LOGFILE_GENERAL, O_RDWR | O_TRUNC  | O_CREAT);
			break;
		case LOG_HTTP:
			logFile[LOG_HTTP] = open(BF_LOGFILE_HTTP, O_RDWR | O_TRUNC  | O_CREAT);
			break;
		case LOG_TCPIP:
			logFile[LOG_TCPIP] = open(BF_LOGFILE_TCPIP, O_RDWR | O_TRUNC  | O_CREAT);
			break;
	}
}

EXPORT void bf_set_log_state(bool state, int facility) {
	if(facility < 0 || facility > MAX_LOG)
		return;
	logIsEnabled[facility] = state;
}

EXPORT int bf_get_log_fd(int facility) {
	return logFile[facility];
}

EXPORT bool bf_get_log_state(int facility) {
	if(facility < 0 || facility > MAX_LOG)
			return 0; // we should probably handle this better...
	return logIsEnabled[facility];
}

EXPORT void bf_logwrite(int facility, const char *msg, ...) {
	va_list argp;
	char *buf, *buf2, *p;
	int len;
	struct timeval tv;
	
	if(facility < 0 || facility > MAX_LOG || logIsEnabled[facility] == 0)
		return;

	pthread_mutex_lock(&mutex_log_writer);        // we lock to avoid corrupt logs from multiple threads

	orig_gettimeofday(&tv, NULL);	// we use the original syscall so that we don't get a race when hooking this syscall
  	time_t ticks = tv.tv_sec;

	va_start(argp, msg);
	vasprintf(&buf, msg, argp);
	va_end(argp);
	len = strlen(buf) + 3 + strlen(ctime(&ticks)); 
	buf2=(char *)malloc(len);
	snprintf(buf2, len, "%s %s\n", ctime(&ticks), buf);
	
	// this is so dumb that we need to do this. Stupid ctime() puts a newline at the end of its string :-(
	p=buf2;
	while(*p && *p != '\n')
		p++;
	if(*p == '\n')
		*p=':';

	orig_write(logFile[facility], buf2, len-1);	// use original syscall

	free(buf);
	free(buf2);

	pthread_mutex_unlock(&mutex_log_writer); // and we unlock 
}

EXPORT void bf_logwrite_msgSend(int facility, const char *msg, ...) {
	va_list argp;
	char *buf;
	int len;
	
	if(facility < 0 || facility > MAX_LOG || logIsEnabled[facility] == 0)
		return;

	pthread_mutex_lock(&mutex_log_writer);        // we lock to avoid corrupt logs from multiple threads

	va_start(argp, msg);
	vasprintf(&buf, msg, argp);
	va_end(argp);
	len = strlen(buf); 
	
	orig_write(logFile[facility], buf, len);	// use original syscall

	pthread_mutex_unlock(&mutex_log_writer); // and we unlock 
}

EXPORT void bf_init_logwriter() {
	int i;

	for(i=0;i<=MAX_LOG;i++)
    	logIsEnabled[i]=1;
    logFile[LOG_STRACE]		= open(BF_LOGFILE_STRACE,	O_RDWR | O_TRUNC  | O_CREAT); // yay error checking
    logFile[LOG_MSGSEND]	= open(BF_LOGFILE_MSGSEND,	O_RDWR | O_TRUNC  | O_CREAT); // yay error checking
    logFile[LOG_GENERAL]	= open(BF_LOGFILE_GENERAL,	O_RDWR | O_TRUNC  | O_CREAT); // yay error checking
    logFile[LOG_HTTP]		= open(BF_LOGFILE_HTTP,		O_RDWR | O_TRUNC  | O_CREAT); // yay error checking
    logFile[LOG_TCPIP]		= open(BF_LOGFILE_TCPIP,	O_RDWR | O_TRUNC  | O_CREAT); // yay error checking
    for(i=0;i<=MAX_LOG;i++)
    	fchmod(logFile[i], 0666); // we are teh secure
}

