#include <substrate.h>
#include <sys/types.h>
#include <dirent.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/param.h>
#include <sys/mount.h>
#include <sys/ioctl.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <mach-o/dyld.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdarg.h>
#include <unistd.h>
#include <string.h>
#include <stdarg.h>
#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFStream.h>
#import <CFNetwork/CFNetwork.h>
#include <pthread.h>
#include <CFNetwork/CFProxySupport.h>
#import <Security/Security.h>
#include <Security/SecCertificate.h>
#include <dlfcn.h>
#include <stdbool.h>
#include <objc/objc.h>
#include "iSpy.common.h"
#include "iSpy.class.h"
#include "iSpy.msgSend.whitelist.h"
#include <stack>
#include <pthread.h>
#include "djbhash.h"
#include <stdlib.h>
#include <sys/types.h>
#include <sys/mman.h>
#include <objc/runtime.h>
#include "iSpy.msgSend.common.h"

#define DO_SUPER_DEBUG_MODE 1

extern "C" USED int is_valid_pointer(void *ptr) {
    //int ret = madvise(ptr, 4096, MADV_WILLNEED);
    char vec;
    int ret;
    ret = mincore(ptr, 4096, &vec);
    if(ret == 0)
        if((vec & 1) == 1)
            return YES;

    return NO;
}


void __log__(const char *jank) {
    if(!DO_SUPER_DEBUG_MODE)
        return;
    FILE *fp = fopen("/tmp/bf.log","a");
    fputs(jank, fp);
    fclose(fp);
}


extern "C" USED const char *get_param_value(id x) {
    char buf[1027];

    if(!x)
        return NULL;

    Class c = object_getClass((id)x);
    if(c == nil) {
        return NULL;
    }
    CFTypeID type = 0;
  
    if((unsigned long) c % __alignof__(Class) != 0) {
            snprintf(buf, 1024, "(id)%p", x);
            return strdup(buf);
    }
   
    if (class_isMetaClass(c)) {
            snprintf(buf, 1024, "(Class)%s", class_getName(c));
            return strdup(buf);
    }
   
    if (class_respondsToSelector(c, @selector(UTF8String)))
            return (char *)x;

    if (class_respondsToSelector(c, @selector(CFGetTypeID)))
            type = CFGetTypeID(x);
   
    if (type == CFStringGetTypeID()) {
            CFStringEncoding enc = CFStringGetFastestEncoding( (CFStringRef)x );
            const char* ptr = CFStringGetCStringPtr( (CFStringRef)x, enc );
            if (ptr != NULL) {
                    snprintf(buf, 1024, "@\"%s\" ", ptr);
                    return strdup(buf);
            }

            CFDataRef data = CFStringCreateExternalRepresentation(NULL, (CFStringRef)x, kCFStringEncodingUTF8, '?');
            if (data != NULL) {
                    CFRelease(data);
                    snprintf(buf, 1024, "@\"%.*s\" ", (int)CFDataGetLength(data), CFDataGetBytePtr(data));
                    return strdup(buf);
            }
    } else if (type == CFBooleanGetTypeID()) {
            snprintf(buf, 1024, "%s", (x) ? "True" : "False");
            return strdup(buf);
    } else if (type == CFNullGetTypeID()) {
            return strdup("NULL");
    } else if (type == CFNumberGetTypeID()) {
            CFNumberType numType = CFNumberGetType((CFNumberRef)x);
            static const char* const numTypeStrings[] = {
                    NULL, "SInt8", "SInt16", "SInt32", "SInt64", "Float32", "Float64",
                    "char", "short", "int", "long", "long long", "float", "double",
                    "CFIndex", "NSInteger", "CGFloat"
            };

            switch (numType) {
                    case kCFNumberSInt8Type:
                    case kCFNumberSInt16Type:
                    case kCFNumberSInt32Type:
                    case kCFNumberCharType:
                    case kCFNumberShortType:
                    case kCFNumberIntType:
                    case kCFNumberLongType:
                    case kCFNumberCFIndexType:
                    case kCFNumberNSIntegerType: {
                            long res;
                            CFNumberGetValue((CFNumberRef)x, kCFNumberLongType, &res);
                            snprintf(buf, 1024, "<CFNumber (%s)%ld> ", numTypeStrings[numType], res);
                            return strdup(buf);
                            break;
                    }
                    case kCFNumberSInt64Type:
                    case kCFNumberLongLongType: {
                            long long res;
                            CFNumberGetValue((CFNumberRef)x, kCFNumberLongLongType, &res);
                            snprintf(buf, 1024, "<CFNumber (%s)%lld> ", numTypeStrings[numType], res);
                            return strdup(buf);
                            break;
                    }      
                    default: {
                            double res;
                            CFNumberGetValue((CFNumberRef)x, kCFNumberDoubleType, &res);
                            snprintf(buf, 1024, "<CFNumber (%s)%lg> ", numTypeStrings[numType], res);
                            return strdup(buf);
                            break;
                    }
            }
            return strdup("nil");
    }
    return "";
}
