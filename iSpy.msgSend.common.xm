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

FILE *superLogFP = NULL;

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

extern void ___log___(const char *jank) {
    fputs(jank, superLogFP);
    fflush(superLogFP);
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

extern "C" USED void show_retval (void *addr) {
}

extern "C" USED void print_args_v(id self, SEL _cmd, std::va_list va) {
    __log__("\n\n<======== Entry ========>\n");
    if(self && _cmd) {
        char *className, *methodName, *methodPtr, *argPtr;
        Method method = nil;
        int numArgs, k, realNumArgs;
        BOOL isInstanceMethod = true;
        Class fooClass;
        char json[2048]; // 2k should be big enough
        char argName[256]; // srlsy
        char buf[1027]; // yup
        Class c;

        // needed for all the things
        c = (Class)object_getClass(self); 
        className = (char *)object_getClassName(self);
        methodName = (char *)sel_getName(_cmd);
        
        // We need to determine if "self" is a meta class or an instance of a class.
        // We can't use Apple's class_isMetaClass() here because it seems to randomly crash just
        // a little too often. Always class_isMetaClass() and always in this piece of code. 
        // Maybe it's shit, maybe it's me. Whatever.
        // Instead we fudge the same functionality, which is nice and stable.
        // 1. Get the name of the object being passed as "self"
        // 2. Get the metaclass of "self" based on its name
        // 3. Compare the metaclass of "self" to "self". If they're the same, it's a metaclass.
        //bool meta = (objc_getMetaClass(className) == object_getClass(self));
        //bool meta = (id)c == self;
        bool meta = (objc_getMetaClass(className) == c);
        
        // get the correct method
        if(!meta) {
            __log__("instance\n");
            method = class_getInstanceMethod(c, (SEL)_cmd);
        } else {
            __log__("class\n");
            method = class_getClassMethod(c, (SEL)_cmd);
            isInstanceMethod = false;
        }
        
        // quick sanity check
        if(!method || !className || !methodName) {
            return;
        }

        // grab the argument count
        __log__("args\n");
        numArgs = method_getNumberOfArguments(method);
        realNumArgs = numArgs - 2;

        // start the JSON block
        __log__("sprintf\n");
        snprintf(json, sizeof(json), "{\"messageType\":\"obj_msgSend\",\"class\":\"%s\",\"method\":\"%s\",\"isInstanceMethod\":%d,\"numArgs\":%d,\"args\":[", className, methodName, isInstanceMethod, realNumArgs);
        __log__(json);

        // use this to iterate over argument names
        methodPtr = methodName;
        __log__("Hitting loop...\n");
            
        // if(0)
        {
            // cycle through the paramter list for this method.
            // start at k=2 so that we omit Cls and SEL, the first 2 args of every function/method
            for(k=2; k < numArgs; k++) {
                char argTypeBuffer[256]; // safe and reasonable limit on var name length
                int argNum = k - 2;

                // non-destructive strtok() replacement
                argPtr = argName;
                while(*methodPtr != ':' && *methodPtr != '\0')
                    *(argPtr++) = *(methodPtr++);
                *argPtr = (char)0;
                
                // get the type code for the argument
                __log__("argType\n");
                method_getArgumentType(method, k, argTypeBuffer, 255);

                // if it's a pointer then we actually want the next byte.
                char *typeCode = (argTypeBuffer[0] == '^') ? &argTypeBuffer[1] : argTypeBuffer;

                // arg data
                void *paramVal = va_arg(va, void *);
                
                // start the JSON for this argument
                snprintf(json, sizeof(json), "%s{\"name\":\"%s\",\"typeCode\":\"%s\",\"addr\":\"%p\",", json, argName, argTypeBuffer, paramVal);

                // lololol
                unsigned long v = (unsigned long)paramVal;
                double d = (double)v;

                __log__("into switch...\n");
                switch(*typeCode) {
                    case 'c': // char
                        snprintf(json, sizeof(json), "%s\"type\":\"char\",\"value\":\"0x%x (%d) ('%c')\"", json, (unsigned int)paramVal, (int)paramVal, (paramVal)?(int)paramVal:' '); 
                        break;
                    case 'i': // int
                        snprintf(json, sizeof(json), "%s\"type\":\"int\",\"value\":0x%x (%d)", json, (int)paramVal, (int)paramVal); 
                        break;
                    case 's': // short
                        snprintf(json, sizeof(json), "%s\"type\":\"short\",\"value\":0x%x (%d)", json, (int)paramVal, (int)paramVal); 
                        break;
                    case 'l': // long
                        snprintf(json, sizeof(json), "%s\"type\":\"long\",\"value\":0x%lx (%ld)", json, (long)paramVal, (long)paramVal); 
                        break;
                    case 'q': // long long
                        snprintf(json, sizeof(json), "%s\"type\":\"long long\",\"value\":%llx (%lld)", json, (long long)paramVal, (long long)paramVal); 
                        break;
                    case 'C': // char
                        snprintf(json, sizeof(json), "%s\"type\":\"char\",\"value\":\"0x%x (%u) ('%c')\"", json, (unsigned int)paramVal, (unsigned int)paramVal, (unsigned int)paramVal); 
                        break;
                    case 'I': // int
                        snprintf(json, sizeof(json), "%s\"type\":\"int\",\"value\":0x%x (%u)", json, (unsigned int)paramVal, (unsigned int)paramVal); 
                        break;
                    case 'S': // short
                        snprintf(json, sizeof(json), "%s\"type\":\"short\",\"value\":0x%x (%u)", json, (unsigned int)paramVal, (unsigned int)paramVal); 
                        break;
                    case 'L': // long
                        snprintf(json, sizeof(json), "%s\"type\":\"long\",\"value\":0x%lx (%lu)", json, (unsigned long)paramVal, (unsigned long)paramVal); 
                        break;
                    case 'Q': // long long
                        snprintf(json, sizeof(json), "%s\"type\":\"long long\",\"value\":%llx (%llu)", json, (unsigned long long)paramVal, (unsigned long long)paramVal); 
                        break;
                    case 'f': // float
                        snprintf(json, sizeof(json), "%s\"type\":\"float\",\"value\":%f", json, (float)d); 
                        break;
                    case 'd': // double                        
                        snprintf(json, sizeof(json), "%s\"type\":\"double\",\"value\":%f", json, (double)d); 
                        break;
                    case 'B': // BOOL
                        snprintf(json, sizeof(json),  "%s\"type\":\"BOOL\",\"value\":%s", json, ((int)paramVal)?"true":"false");
                        break;
                    case 'v': // void
                        snprintf(json, sizeof(json),  "%s\"type\":\"void\",\"ptr\":\"%p\"", json, paramVal);
                        break;
                    case '*': // char *
                        snprintf(json, sizeof(json),  "%s\"type\":\"char *\",\"value\":\"%s\",\"ptr\":\"%p\" ", json, (char *)paramVal, paramVal);
                        break;
                    case '{': // struct
                        snprintf(json, sizeof(json),  "%s\"type\":\"struct\",\"ptr\":\"%p\"", json, paramVal);
                        break;
                    case ':': // selector
                        snprintf(json, sizeof(json),  "%s\"type\":\"SEL\",\"value\":\"@selector(%s)\"", json, (paramVal)?(char *)paramVal:"nil");
                        break;
                    case '@': // object
                        if(is_valid_pointer(paramVal)) {
                            __log__("OBJECT valid pointer. get class...\n");
                            sprintf(buf, "%p\n", paramVal);
                            __log__(buf);
                            fooClass = object_getClass((id)paramVal);
                            __log__("name\n");
                            __log__(class_getName(fooClass));
                            __log__("sprintf\n");
                            snprintf(json, sizeof(json), "%s\"type\":\"%s\",", json, class_getName(fooClass));
                            __log__("value\n");
                            if(class_respondsToSelector(fooClass, @selector(description))) {
                                __log__("desc\n");
                                NSString *desc = orig_objc_msgSend((id)paramVal, @selector(description));
                                __log__("sprintf\n");
                                snprintf(json, sizeof(json), "%s\"value\":\"%s\"", json, (char *)orig_objc_msgSend(desc, @selector(UTF8String)));
                            } else {
                                __log__("no desc\n");
                                snprintf(json, sizeof(json), "%s\"value\":\"%s\"", json, "@BARF. No description. This is probably a bug.");
                            }
                        } else {
                            __log__("invalid pointer\n");
                            snprintf(json, sizeof(json), "%s\"type\":\"<Invalid memory address>\",\"value\":\"N/A\"", json);
                        }
                        break;
                    case '#': // class
                        if(is_valid_pointer(paramVal)) {
                            sprintf(buf, "%p\n", paramVal);
                            __log__("CLASS valid pointer. get class...\n");
                            __log__(buf);
                            __log__("name\n");
                            __log__(class_getName((Class)paramVal));
                            __log__("sprintf\n");
                            snprintf(json, sizeof(json), "%s\"type\":\"%s\",", json, class_getName((Class)paramVal));
                            __log__("value\n");
                            if(class_respondsToSelector((Class)paramVal, @selector(description))) {
                                __log__("desc\n");
                                NSString *desc = orig_objc_msgSend((id)paramVal, @selector(description));
                                __log__("sprintf\n");
                                snprintf(json, sizeof(json), "%s\"value\":\"%s\"", json, (char *)orig_objc_msgSend(desc, @selector(UTF8String)));
                            } else {
                                __log__("no desc\n");
                                snprintf(json, sizeof(json), "%s\"value\":\"%s\"", json, "#BARF. No description. This is probably a bug.");
                            }
                        } else {
                            __log__("invalid pointer\n");
                            snprintf(json, sizeof(json), "%s\"type\":\"<Invalid memory address>\",\"value\":\"N/A\"", json);
                        }
                        break;
                    default:
                        snprintf(json, sizeof(json), "%s\"type\":\"UNKNOWN_FIXME\",\"value\":\"%p\"", json, paramVal);
                        break;     
                }
                if(argNum == realNumArgs-1)
                    strlcat(json, "}", sizeof(json));
                else
                    strlcat(json, "},", sizeof(json));
                __log__("Looping...\n");                               
            }
            __log__("Loop finished.\n");
        } // log args

        // finish the JSON block
        strlcat(json, "]}", sizeof(json));

        // b00m!
        __log__("writing to websocket\n");
        bf_websocket_write(json);
    }

    return;
}

