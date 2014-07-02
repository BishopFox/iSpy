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


static const unsigned int DEBUG   = 0;
static const unsigned int INFO    = 1;
static const unsigned int WARNING = 2;
static const unsigned int ERROR   = 3;
static const unsigned int FATAL   = 4;
static const char* STR_LEVELS[] = ["[DEBUG]", "[INFO]", "[WARNING]", "[ERROR]", "[FATAL]"];

static const unsigned int LOG_STRACE   = 0;
static const unsigned int LOG_MSGSEND  = 1;
static const unsigned int LOG_GENERAL  = 2;
static const unsigned int LOG_HTTP     = 3;
static const unsigned int LOG_TCPIP    = 4;
static const unsigned int LOG_GLOBAL   = 5;
static const unsigned int MAX_LOG      = LOG_GLOBAL;	// this must be equal to the last number in the list of LOG_* numbers, above.
static const char* FACILITY_FILES[] = ["strace.log", "msgsend.log", "general.log" "http.log", "tcpip.log", "global.log"];

static const char *LOG_SUBDIRECTORY = "/logs/";

// If we use any hooked calls within the log writer, we must use the original (unhooked) versions.
// Simply declare them extern and copy from hook_C_system_calls.xm
// MAKE ABSOLUTELY SURE that orig_funcname = funcname in hook_C_system_calls.xm
// See the following functions in hook_C_system_calls.xm for examples.
extern int (*orig_gettimeofday)(struct timeval *tp, void *tzp);
extern size_t (*orig_write)(int fd, const void *cbuf, user_size_t nbyte);

static int logFiles[MAX_LOG + 1];


void (^log_write)(int) = ^(int facility, int level, const char *msg, va_list args) {

    char *buf, *buf2, *p;
    unsigned int len;
    struct timeval tv;

    orig_gettimeofday(&tv, NULL);    // we use the original syscall so that we don't get a race when hooking this syscall
    time_t ticks = tv.tv_sec;

    va_start(args, msg);
    vasprintf(&buf, msg, args);
    va_end(args);
    len = strlen(buf) + 3 + strlen(ctime(&ticks));
    buf2 = (char *) malloc(len);
    snprintf(buf2, len, "%s %s\n", ctime(&ticks), buf);

    // this is so dumb that we need to do this. Stupid ctime() puts a newline at the end of its string :-(
    p = buf2;
    while(*p && *p != '\n')
        p++;
    if(*p == '\n')
        *p=':';

    switch(facility) {
        case LOG:
    }
    orig_write(logFiles[facility], buf2, len-1);    // use original syscall

    free(buf);
    free(buf2);
}

/*
 * iSpyDirectory is where we setup shop - must have a trailing '/'
 */
EXPORT void ispy_init_logwriter(const char *iSpyDirectory) {

    NSLog(@"[iSpy][Logging] iSpyDirectory = %s", iSpyDirectory);

    /* First we build the log directory, which will contain all of our log files */
    unsigned int logDirectoryLength = strlen(iSpyDirectory) + strlen(LOG_SUBDIRECTORY);
    char *logDirectory = malloc(logDirectoryLength + 1);
    strncpy(logDirectory, iSpyDirectory, strlen(iSpyDirectory));
    strncat(logDirectory, FACILITY_FILES[index], strlen(FACILITY_FILES[index]));
    logDirectory[logDirectoryLength + 1] = '\0';

    NSLog(@"[iSpy][Logging] logDirectory = %s", logDirectory);

    /* Next we create each log file, and store the FD in an array */
    for(unsigned int index = 0; index < MAX_LOG; ++index) {
        unsigned int filePathLength = strlen(logDirectory) + strlen(FACILITY_FILES[index]);
        char *filePath = (char *) malloc(filePathLength + 1);
        strncpy(filePath, logDirectory, strlen(logDirectory));
        strncat(filePath, FACILITY_FILES[index], strlen(FACILITY_FILES[index]));
        filePath[filePathLength + 1] = '\0';
        logFiles[facility] = open(filePath, O_WRONLY | O_CREAT);

        NSLog(@"[iSpy][Logging] Create file -> %s", filePath);

    }
}

/* Non-blocking logging calls */
EXPORT void ispy_log_debug(unsigned int facility, const char *msg, ...) {
    va_list args;

}

EXPORT void ispy_log_info(unsigned int facility, const char *msg, ...) {
    va_list args;

}

EXPORT void ispy_log_warning(unsigned int facility, const char *msg, ...) {
    va_list args;

}

EXPORT void ispy_log_error(unsigned int facility, const char *msg, ...) {
    va_list args;

}

EXPORT void ispy_log_fatal(unsigned int facility, const char *msg, ...) {
    va_list args;

}
