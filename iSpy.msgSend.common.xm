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
#include <stdlib.h>
#include <sys/types.h>
#include <sys/mman.h>
#include <objc/runtime.h>
#include "iSpy.msgSend.common.h"

FILE *superLogFP = NULL;
pthread_once_t key_once = PTHREAD_ONCE_INIT;
pthread_key_t stack_keys[ISPY_MAX_RECURSION], curr_stack_key;

// Sometimes we NEED to know if a pointer is mapped into addressible space, otherwise we
// may dereference something that's a pointer to unmapped space, which will go boom.
// This uses mincore(2) to ask the XNU kernel if a pointer is within a mapped page.
// Assumes a page size of 4096 (true on 32-bit iOS).
extern "C" USED int is_valid_pointer(void *ptr) {
    char vec;
    int ret;
    ret = mincore(ptr, 4096, &vec);
    if(ret == 0)
        if((vec & 1) == 1)
            return YES;

    return NO;
}

extern void ___log___(const char *jank) {
    char *buf = (char *)malloc(strlen(jank) + 64);
    sprintf(buf, "[%08x] %s", (unsigned int)pthread_self(), jank);
    fputs(buf, superLogFP);
    free(buf);
    fflush(superLogFP);
}

extern "C" USED inline void increment_depth() {
    int currentDepth = (int)pthread_getspecific(curr_stack_key);
    currentDepth++;
    pthread_setspecific(curr_stack_key, (void *)currentDepth);
}

extern "C" USED inline void decrement_depth() {
    int currentDepth = (int)pthread_getspecific(curr_stack_key);
    currentDepth--;
    pthread_setspecific(curr_stack_key, (void *)currentDepth);
}

extern "C" USED inline int get_depth() {
    return (int)pthread_getspecific(curr_stack_key);
}

extern "C" USED void *saveBuffer(void *buffer) {
    increment_depth();
    pthread_setspecific(stack_keys[get_depth()], buffer);
    return buffer;
}

extern "C" USED void *loadBuffer() {
    __log__("loadBuffer\n");
    void *buffer;
    buffer = pthread_getspecific(stack_keys[get_depth()]);
    return buffer;
}

extern "C" USED void cleanUp() {
    __log__("cleanUp\n");
    decrement_depth();
}

extern "C" USED void *show_retval(void *threadBuffer, void *returnValue) {
    __log__("======= _show_retval entry ======\n");

    struct objc_callState *callState = (struct objc_callState *)threadBuffer;
    char *newJSON = NULL;

    if(!callState)
        return threadBuffer;
    
    // if this method returns a non-void, we report it
    if(callState->returnType && callState->returnType[0] != 'v') {
        char *returnValueJSON = parameter_to_JSON(callState->returnType, returnValue);
        size_t len = (size_t)strlen(callState->json) + strlen(returnValueJSON) + 54;
        newJSON = (char *)malloc(len);
        snprintf(newJSON, len, "%s,\"returnValue\":{%s,\"objectAddr\":\"%p\"}}\n", callState->json, returnValueJSON, returnValue);    
        free(returnValueJSON);
    } 
    // otherwise we don't bother.
    else {
        size_t len = (size_t)strlen(callState->json) + 3;
        newJSON = (char *)malloc(len);
        snprintf(newJSON, len, "%s}\n", callState->json);
    }
    
    // Squirt this call data over to the listening web socket
    bf_websocket_write(newJSON);
    __log__(newJSON);
    
    // Now check to see if anything else interesting should be done with this call.
    // E.g. Should we be checking to see if it's on the "interesting" list?
    // TODO: make an "interesting" list

    free(newJSON);
    free(callState->returnType);
    free(callState->json);
    free(callState);
    __log__("======= _show_retval exit ======\n");
    
    return threadBuffer;
}

/*
    returns something that looks like this:

        "type":"int", "value":"31337"
*/
extern "C" USED char *parameter_to_JSON(char *typeCode, void *paramVal) {
    char json[4096]; // 4096 chosen at random
    Class fooClass;
    
    if(!typeCode || !is_valid_pointer((void *)typeCode))
        return (char *)"";

    // lololol
    unsigned long v = (unsigned long)paramVal;
    double d = (double)v;

    memset(json, 0, 4096);
    __log__("Typecode: ");
    __log__(typeCode);
    __log__("\n");
    switch(*typeCode) {
        case 'c': // char
            snprintf(json, sizeof(json), "%s\"type\":\"char\",\"value\":\"0x%x (%d) ('%c')\"", json, (unsigned int)paramVal, (int)paramVal, (paramVal)?(int)paramVal:' '); 
            break;
        case 'i': // int
            snprintf(json, sizeof(json), "%s\"type\":\"int\",\"value\":\"0x%x (%d)\"", json, (int)paramVal, (int)paramVal); 
            break;
        case 's': // short
            snprintf(json, sizeof(json), "%s\"type\":\"short\",\"value\":\"0x%x (%d)\"", json, (int)paramVal, (int)paramVal); 
            break;
        case 'l': // long
            snprintf(json, sizeof(json), "%s\"type\":\"long\",\"value\":\"0x%lx (%ld)\"", json, (long)paramVal, (long)paramVal); 
            break;
        case 'q': // long long
            snprintf(json, sizeof(json), "%s\"type\":\"long long\",\"value\":\"%llx (%lld)\"", json, (long long)paramVal, (long long)paramVal); 
            break;
        case 'C': // char
            snprintf(json, sizeof(json), "%s\"type\":\"char\",\"value\":\"0x%x (%u) ('%c')\"", json, (unsigned int)paramVal, (unsigned int)paramVal, (unsigned int)paramVal); 
            break;
        case 'I': // int
            snprintf(json, sizeof(json), "%s\"type\":\"int\",\"value\":\"0x%x (%u)\"", json, (unsigned int)paramVal, (unsigned int)paramVal); 
            break;
        case 'S': // short
            snprintf(json, sizeof(json), "%s\"type\":\"short\",\"value\":\"0x%x (%u)\"", json, (unsigned int)paramVal, (unsigned int)paramVal); 
            break;
        case 'L': // long
            snprintf(json, sizeof(json), "%s\"type\":\"long\",\"value\":\"0x%lx (%lu)\"", json, (unsigned long)paramVal, (unsigned long)paramVal); 
            break;
        case 'Q': // long long
            snprintf(json, sizeof(json), "%s\"type\":\"long long\",\"value\":\"%llx (%llu)\"", json, (unsigned long long)paramVal, (unsigned long long)paramVal); 
            break;
        case 'f': // float
            snprintf(json, sizeof(json), "%s\"type\":\"float\",\"value\":\"%f\"", json, (float)d); 
            break;
        case 'd': // double                        
            snprintf(json, sizeof(json), "%s\"type\":\"double\",\"value\":\"%f\"", json, (double)d); 
            break;
        case 'B': // BOOL
            snprintf(json, sizeof(json),  "%s\"type\":\"BOOL\",\"value\":\"%s\"", json, ((int)paramVal)?"true":"false");
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
            snprintf(json, sizeof(json),  "%s\"type\":\"SEL\",\"value\":\"@selector(%s)\"", json, (paramVal)?"Selector FIXME":"nil");
            break;
        case '@': // object
            __log__("obj @\n");
            if(is_valid_pointer(paramVal)) {
                fooClass = object_getClass((id)paramVal);
                snprintf(json, sizeof(json), "%s\"type\":\"%s\",", json, class_getName(fooClass));
                if(class_respondsToSelector(fooClass, @selector(description))) {
                    NSString *desc = orig_objc_msgSend((id)paramVal, @selector(description));
                    NSString *realDesc = orig_objc_msgSend((id)desc, @selector(stringByReplacingOccurrencesOfString:withString:), @"\"", @"&#34;");
                    snprintf(json, sizeof(json), "%s\"value\":\"%s\"", json, (char *)orig_objc_msgSend(realDesc, @selector(UTF8String)));
                } else {
                    snprintf(json, sizeof(json), "%s\"value\":\"%s\"", json, "@BARF. No description. This is probably a bug.");
                }
            } else {
                snprintf(json, sizeof(json), "%s\"type\":\"<Invalid memory address>\",\"value\":\"N/A\"", json);
            }
            break;
        case '#': // class
            __log__("class #\n");
            if(is_valid_pointer(paramVal)) {
                snprintf(json, sizeof(json), "%s\"type\":\"%s\",", json, class_getName((Class)paramVal));
                if(class_respondsToSelector((Class)paramVal, @selector(description))) {
                    NSString *desc = orig_objc_msgSend((id)paramVal, @selector(description));
                    NSString *realDesc = orig_objc_msgSend((id)desc, @selector(stringByReplacingOccurrencesOfString:withString:), @"\"", @"&#34;");
                    snprintf(json, sizeof(json), "%s\"value\":\"%s\"", json, (char *)orig_objc_msgSend(realDesc, @selector(UTF8String)));
                } else {
                    snprintf(json, sizeof(json), "%s\"value\":\"%s\"", json, "#BARF. No description. This is probably a bug.");
                }
            } else {
                snprintf(json, sizeof(json), "%s\"type\":\"<Invalid memory address>\",\"value\":\"N/A\"", json);
            }
            break;
        default:
            snprintf(json, sizeof(json), "%s\"type\":\"UNKNOWN TYPE. Code: %s\",\"value\":\"%p\"", json, typeCode, paramVal);
            break;     
    }
    return strdup(json); // caller must free()
}

extern "C" USED void *print_args_v(id self, SEL _cmd, std::va_list va) {
    char json[4096];  // lololol, roflcopters
    struct objc_callState *callState = NULL;
    __log__("\n\n<======== Print Args Entry ========>\n");
    if(self && _cmd) {
        char *className, *methodName, *methodPtr, *argPtr;
        Method method = nil;
        int numArgs, k, realNumArgs;
        BOOL isInstanceMethod = true;
        char argName[256]; // srlsy
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
            return NULL;
        }

        // grab the argument count
        __log__("args\n");
        numArgs = method_getNumberOfArguments(method);
        realNumArgs = numArgs - 2;

        // setup call state
        callState = (struct objc_callState *)malloc(sizeof(struct objc_callState));
        callState->returnType = method_copyReturnType(method);

        // start the JSON block
        __log__("sprintf\n");
        snprintf(json, sizeof(json), "{\"messageType\":\"obj_msgSend\",\"depth\":%d,\"thread\":%u,\"objectAddr\":\"%p\",\"class\":\"%s\",\"method\":\"%s\",\"isInstanceMethod\":%d,\"returnTypeCode\":\"%s\",\"numArgs\":%d,\"args\":[", get_depth(), (unsigned int)pthread_self(), self, className, methodName, isInstanceMethod, callState->returnType, realNumArgs);

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

                __log__("Parsing param -> JSON\n");
                char *paramValueJSON = parameter_to_JSON(typeCode, paramVal);
                __log__("strlcat\n");
                strlcat(json, paramValueJSON, sizeof(json));
                __log__("free\n");
                free(paramValueJSON);
                
                __log__("more strlcat\n");
                if(argNum == realNumArgs-1)
                    strlcat(json, "}", sizeof(json));
                else
                    strlcat(json, "},", sizeof(json));
                __log__("Looping...\n");                               
            }
            __log__("Loop finished.\n");
        } // log args

        // finish the JSON block, but don't add a trailing "}" - that will be added last by the return value logger in the hooked objc_msgSend.
        strlcat(json, "]", sizeof(json));
    } else {
        __log__("======= print_args_v exit NULLLLL =====\n");
        return NULL;
    }

    char foo[1024];
    callState->json = strdup(json);
    sprintf(foo, "print_args outro %p // %p // %p\n", callState, callState->json, callState->returnType);
    __log__(foo);
    __log__("======= print_args_v exit =====\n");

    return (void *)callState; // caller must free this and its internal pointers, but only after we're completely done (ie. after we've logged the return value)
}

