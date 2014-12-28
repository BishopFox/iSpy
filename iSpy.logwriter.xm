/*
    iSpy - iOS hooking framework.

    Async logging framework.
    Logs are written to <app>/Documents/.ispy/logs/<facility>.log

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
#include <dispatch/dispatch.h>
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
static const unsigned int WTF   = 4;
static const char* LEVELS[] = {"[DEBUG]", "[INFO]", "[WARNING]", "[ERROR]", "[WTF]"};

/*
    >>> These come from iSpy.common.h
    static const unsigned int LOG_STRACE   = 0;
    static const unsigned int LOG_MSGSEND  = 1;
    static const unsigned int LOG_GENERAL  = 2;
    static const unsigned int LOG_HTTP     = 3;
    static const unsigned int LOG_TCPIP    = 4;
*/
static const char* FACILITY_FILES[] = {"strace.log", "msgsend.log", "general.log", "http.log", "tcpip.log", "global.log", "report.log"};
static const int LOG_UMASK = 0644;
static int logFiles[MAX_LOG + 1];
static BOOL logIsInitialized = NO;
static unsigned int minLogLevel = DEBUG;

static dispatch_queue_t logQueue;
static const char *LOG_QUEUE = "com.bishopfox.iSpy.logger";


// If we use any hooked calls within the log writer, we must use the original (unhooked) versions.
// Simply declare them extern and copy from hook_C_system_calls.xm
// MAKE ABSOLUTELY SURE that orig_funcname = funcname in hook_C_system_calls.xm
// See the following functions in hook_C_system_calls.xm for examples.
extern int (*orig_gettimeofday)(struct timeval *tp, void *tzp);
extern size_t (*orig_write)(int fd, const void *cbuf, user_size_t nbyte);

/*
 * This function is dispatched to GCD for execution
 */
static void ispy_log_write(unsigned int facility, unsigned int level, char *msg) {

    if (MAX_LOG < facility) {
        facility = LOG_GENERAL;
    }

    char *line, *p;
    unsigned int lineLength;
    struct timeval tv;

    orig_gettimeofday(&tv, NULL);    // we use the original syscall so that we don't get a race when hooking this syscall
    time_t ticks = tv.tv_sec;

    /* Don't forget the extra chars for formatting! */
    lineLength = strlen(LEVELS[level]) + strlen(msg) + strlen(ctime(&ticks)) + 5;
    line = (char *) malloc(lineLength);

    /* The closing ] is added to the ctime string below */
    snprintf(line, lineLength, "%s [%s %s\n", LEVELS[level], ctime(&ticks), msg);

    // this is so dumb that we need to do this. Stupid ctime() puts a newline at the end of its string :-(
    p = line;
    while(*p && *p != '\n')
        p++;
    if(*p == '\n')
        *p = ']';

    /* Make sure to use the un-hooked write() */
    if(facility == LOG_MSGSEND) {
        flock(logFiles[LOG_MSGSEND], LOCK_EX);
        orig_write(logFiles[facility], line, lineLength - 1);
        flock(logFiles[LOG_MSGSEND], LOCK_UN);
    } else {
        orig_write(logFiles[facility], line, lineLength - 1);
        orig_write(logFiles[LOG_GLOBAL], line, lineLength - 1);
    }

    free(line);

    // ewww. I made this function static because of this call to free().
    // Nobody should be allowed to call ispy_log_write() except functions below.
    free(msg);
}

/*
 * We can use Objc here because we havn't hooked everything yet
 */
EXPORT void ispy_init_logwriter(NSString *documents) {
    if (!logIsInitialized) {

        NSError *error = nil;

        /* Check to see if our ispy directory exists, and create it if not */
        NSString *iSpyDirectory = [documents stringByAppendingPathComponent:@"/.ispy/"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:iSpyDirectory]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:iSpyDirectory
                withIntermediateDirectories:NO
                attributes:nil
                error:&error];
        }
        if (error != nil) {
            NSLog(@"[iSpy][ERROR] %@", error);
        }

        /* Check to see if the <App>/Documents/.ispy/logs/ directory exists, and create it if not */
        NSString *logsDirectory = [iSpyDirectory stringByAppendingPathComponent:@"/logs/"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:logsDirectory]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:logsDirectory
                withIntermediateDirectories:NO
                attributes:nil
                error:&error];
        }
        if (error != nil) {
            NSLog(@"[iSpy][ERROR] %@", error);
        }

        /* Next we create each log file, and store the FD in the static fileLogs array */
        for(unsigned int index = 0; index <= MAX_LOG; ++index) {
            NSString *fileName = [NSString stringWithFormat:@"%s", FACILITY_FILES[index]];
            NSString *filePath = [NSString stringWithFormat:@"%@/%@", logsDirectory, fileName];
            if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                logFiles[index] = open([filePath UTF8String], O_WRONLY | O_APPEND);
            } else {
                logFiles[index] = open([filePath UTF8String], O_WRONLY | O_CREAT, LOG_UMASK);
            }
        }

        /* Initialize GCD serial queue */
        logQueue = dispatch_queue_create(LOG_QUEUE, NULL);
        logIsInitialized = YES;
    }
}

/* Non-blocking logging calls */
EXPORT void ispy_log_debug(unsigned int facility, const char *msg, ...) {
    if (minLogLevel <= DEBUG) {
        char *msgBuffer;
        va_list args;
        va_start(args, msg);
        vasprintf(&msgBuffer, msg, args);
        va_end(args);

        dispatch_async(logQueue, ^{
            ispy_log_write(facility, DEBUG, msgBuffer);
        });
    }
}

EXPORT void ispy_log_info(unsigned int facility, const char *msg, ...) {
    if (minLogLevel <= INFO) {
        char *msgBuffer;
        va_list args;
        va_start(args, msg);
        vasprintf(&msgBuffer, msg, args);
        va_end(args);

        dispatch_async(logQueue, ^{
            ispy_log_write(facility, INFO, msgBuffer);
        });
    }
}

EXPORT void ispy_log_warning(unsigned int facility, const char *msg, ...) {
    if (minLogLevel <= WARNING) {
        char *msgBuffer;
        va_list args;
        va_start(args, msg);
        vasprintf(&msgBuffer, msg, args);
        va_end(args);

        dispatch_async(logQueue, ^{
            ispy_log_write(facility, WARNING, msgBuffer);
        });
    }
}

EXPORT void ispy_log_error(unsigned int facility, const char *msg, ...) {
    if (minLogLevel <= ERROR) {
        char *msgBuffer;
        va_list args;
        va_start(args, msg);
        vasprintf(&msgBuffer, msg, args);
        va_end(args);

        dispatch_async(logQueue, ^{
            ispy_log_write(facility, ERROR, msgBuffer);
        });
    }
}

/* We always log "what a terrible failure" */
EXPORT void ispy_log_wtf(unsigned int facility, const char *msg, ...) {
    char *msgBuffer;
    va_list args;
    va_start(args, msg);
    vasprintf(&msgBuffer, msg, args);
    va_end(args);

    dispatch_async(logQueue, ^{
        ispy_log_write(facility, WTF, msgBuffer);
    });
}
