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

//
// In this file, all the __log__() functions are #ifdef'd out unless you add:
//      #define DO_SUPER_DEBUG_MODE 1
// to iSpy.msgSend.common.h. Don't do this unless you're debugging iSpy - it's super slow.
//

// hard-coded for now while we're 32-bit only.
#define PAGE_SIZE 4096
#define MALLOC_BUFFER_SIZE PAGE_SIZE * 4     // 4 pages of memory
#define MINIBUF_SIZE 256

FILE *superLogFP = NULL;
pthread_once_t key_once = PTHREAD_ONCE_INIT;
pthread_key_t stack_keys[ISPY_MAX_RECURSION], curr_stack_key;


// These functions are called before and after the objc_msgSend call, respectively.
extern "C" USED inline void interesting_call_preflight_check(struct interestingCall *call) {
    //ispy_log_debug(LOG_GENERAL, "preflight %p / %p / %p", call, call->className, call->methodName);

    // If this call is merely on the whitelist, we ignore it.
    if((unsigned int)call == WHITELIST_PRESENT || !call) 
        return;

    // Ok, the call is considered interesting. Do interesting pre-flight things.
    ispy_log_debug(LOG_GENERAL, "Hit interesting method: [%s %s]. ", call->className, call->methodName);
    if(call->type == INTERESTING_BREAKPOINT) {
        breakpoint_wait_until_release(call);
    }
}

extern "C" inline void interesting_call_postflight_check(struct objc_callState *callState, struct interestingCall *call) {
    
    // If this call is merely on the whitelist, we ignore it.
    if((unsigned int)call == WHITELIST_PRESENT || !call) 
        return;

    // Ok, the call is considered interesting. Do interesting post-flight things.
    // In this example, we add a description of this interesting event to our JSON-formatted log data, which will 
    // eventually end up in the iSpy UI via a websocket push.
    ispy_log_debug(LOG_GENERAL, "Hit interesting method: [%s %s]", call->className, call->methodName);

    char *interestingJSON = (char *)malloc(MALLOC_BUFFER_SIZE);
    snprintf(interestingJSON, MALLOC_BUFFER_SIZE, "%s,\"interesting\":{\"description\":\"%s\", \"classification\":\"%s\", \"risk\":\"%s\"}", 
        callState->json,
        call->description,
        call->classification,
        call->risk);
    
    char *oldJSON = callState->json;
    callState->json = interestingJSON;
    free(oldJSON);
}

extern "C" void breakpoint_wait_until_release(struct interestingCall *call) {
    iSpy *myspy;
    BreakpointMap_t *breakpoints;
    
    myspy = (iSpy *)orig_objc_msgSend(objc_getClass("iSpy"), @selector(sharedInstance));
    ispy_log_debug(LOG_GENERAL, "myspy @ %p %p", myspy->breakpoints);
    breakpoints = myspy->breakpoints;
    (*breakpoints)[(unsigned int)call] = (unsigned int)call;

    // now we wait
    ispy_log_debug(LOG_GENERAL, "Breakpoint hit during call to [%s %s]. Waiting for release...", call->className, call->methodName);
    while((*breakpoints)[(unsigned int)call] == (unsigned int)call)
        sleep(1); // hehe

    ispy_log_debug(LOG_GENERAL, "Breakpoint released for call to [%s %s]. Continuing!", call->className, call->methodName);

    // be safe
    if((*breakpoints)[(unsigned int)call] == (unsigned int)call)
        (*breakpoints).erase((unsigned int)call);
}

void breakpoint_release_breakpoint(const char *className, const char *methodName) {
    struct interestingCall *call;
    iSpy *myspy = (iSpy *)orig_objc_msgSend(objc_getClass("iSpy"), @selector(sharedInstance));

    for(BreakpointMap_t::iterator bp = myspy->breakpoints->begin(); bp != myspy->breakpoints->end(); ++bp) {
        if(!bp->first)
            continue;

        call = (struct interestingCall *)bp->first;
        
        if(call && call->className && strcmp(call->className, className) == 0) {
            if(call->methodName && strcmp(call->methodName, methodName) == 0) {
                BreakpointMap_t *map = myspy->breakpoints;
                map->erase((unsigned int)call);
            }
        }
    }
}

// Sometimes we NEED to know if a pointer is mapped into addressible space, otherwise we
// may dereference something that's a pointer to unmapped space, which will go boom.
// This uses mincore(2) to ask the XNU kernel if a pointer is within an app-mapped page.
extern "C" USED inline int is_valid_pointer(void *ptr) {
    char vec;
    int ret;
    ret = mincore(ptr, PAGE_SIZE, &vec);
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

extern "C" USED inline void *saveBuffer(void *buffer) {
    __log__("saveBuffer\n");
    increment_depth();
    pthread_setspecific(stack_keys[get_depth()], buffer);
    return buffer;
}

extern "C" USED inline void *loadBuffer() {
    __log__("loadBuffer\n");
    void *buffer;
    buffer = pthread_getspecific(stack_keys[get_depth()]);
    return buffer;
}

extern "C" USED inline void cleanUp() {
    __log__("cleanUp\n");
    decrement_depth();
}

extern "C" USED inline void *show_retval(struct objc_callState *callState, void *returnValue, struct interestingCall *call) {
    __log__("======= _show_retval entry ======\n");

    char *newJSON = NULL;

    if(!callState || !call) {
        __log__("Abandoning show_retval\n");
        return (void *)callState;
    }
    
    // Now check to see if anything else interesting should be done with this call, post-flight.
    // We've already triggered a pre-flight check for interesting calls, but now is out chance 
    // to do a post-flight check/response, too.
    __log__("Calling postflight");
    interesting_call_postflight_check(callState, call);

    // if this method returns a non-void, we report it
    if(callState->returnType && callState->returnType[0] != 'v') {
        __log__("Building JSON containing return value\n");
        char *returnValueJSON = parameter_to_JSON(callState->returnType, returnValue);
        __log__("And we're back. Malloc...\n");
        newJSON = (char *)malloc(MALLOC_BUFFER_SIZE);
        __log__("Sprintf\n");
        snprintf(newJSON, MALLOC_BUFFER_SIZE, "%s],\"returnValue\":{%s,\"objectAddr\":\"%p\"}}\n", 
            callState->json,
            returnValueJSON, 
            returnValue
        );
        __log__("newJSON\n");
        __log__(newJSON);
        //newJSON = (char *)realloc(newJSON, strlen(newJSON) + 1);
        __log__("free()\n");
        free(returnValueJSON);
    } 
    // otherwise we don't bother.
    else {
        __log__("No return value, not adding JSON.\n");
        newJSON = (char *)malloc(MALLOC_BUFFER_SIZE);                  
        snprintf(newJSON, MALLOC_BUFFER_SIZE, "%s]}\n", callState->json);   // used here.
    }
    
    __log__("This is the JSON:\n");
    __log__(newJSON);
    __log__("\n");
    __log__("Websocket\n");
    // Squirt this call data over to the listening web socket
    bf_websocket_write(newJSON);
    
    __log__("free() x3\n");
    free(newJSON);
    free(callState->returnType);
    free(callState->json);
    
    __log__("======= _show_retval exit ======\n");
    
    return (void *)callState; // will be free'd by the asm code
}

/*
    returns something that looks like this:

        "type":"int", "value":"31337"
*/
extern "C" USED inline char *parameter_to_JSON(char *typeCode, void *paramVal) {
    char *json;
    Class fooClass;

    __log__("Entering parameter_to_JSON\n");    
    if(!typeCode || !is_valid_pointer((void *)typeCode)) {
        __log__("Abandoning parameter_to_JSON\n");
        return (char *)"";
    }

    // lololol
    unsigned long v = (unsigned long)paramVal;
    double d = (double)v;

    json = (char *)malloc(MALLOC_BUFFER_SIZE);

    __log__("Typecode: '");
    __log__(typeCode);
    __log__("'\n");

    switch(*typeCode) {
        case 'c': // char
            snprintf(json, MALLOC_BUFFER_SIZE, "\"type\":\"char\",\"value\":\"0x%x (%d) ('%c')\"", (unsigned int)paramVal, (int)paramVal, (paramVal)?(int)paramVal:' '); 
            break;
        case 'i': // int
            snprintf(json, MALLOC_BUFFER_SIZE, "\"type\":\"int\",\"value\":\"0x%x (%d)\"", (int)paramVal, (int)paramVal); 
            break;
        case 's': // short
            snprintf(json, MALLOC_BUFFER_SIZE, "\"type\":\"short\",\"value\":\"0x%x (%d)\"", (int)paramVal, (int)paramVal); 
            break;
        case 'l': // long
            snprintf(json, MALLOC_BUFFER_SIZE, "\"type\":\"long\",\"value\":\"0x%lx (%ld)\"", (long)paramVal, (long)paramVal); 
            break;
        case 'q': // long long
            snprintf(json, MALLOC_BUFFER_SIZE, "\"type\":\"long long\",\"value\":\"%llx (%lld)\"", (long long)paramVal, (long long)paramVal); 
            break;
        case 'C': // char
            snprintf(json, MALLOC_BUFFER_SIZE, "\"type\":\"char\",\"value\":\"0x%x (%u) ('%c')\"", (unsigned int)paramVal, (unsigned int)paramVal, (unsigned int)paramVal); 
            break;
        case 'I': // int
            snprintf(json, MALLOC_BUFFER_SIZE, "\"type\":\"int\",\"value\":\"0x%x (%u)\"", (unsigned int)paramVal, (unsigned int)paramVal); 
            break;
        case 'S': // short
            snprintf(json, MALLOC_BUFFER_SIZE, "\"type\":\"short\",\"value\":\"0x%x (%u)\"", (unsigned int)paramVal, (unsigned int)paramVal); 
            break;
        case 'L': // long
            snprintf(json, MALLOC_BUFFER_SIZE, "\"type\":\"long\",\"value\":\"0x%lx (%lu)\"", (unsigned long)paramVal, (unsigned long)paramVal); 
            break;
        case 'Q': // long long
            snprintf(json, MALLOC_BUFFER_SIZE, "\"type\":\"long long\",\"value\":\"%llx (%llu)\"", (unsigned long long)paramVal, (unsigned long long)paramVal); 
            break;
        case 'f': // float
            snprintf(json, MALLOC_BUFFER_SIZE, "\"type\":\"float\",\"value\":\"%f\"", (float)d); 
            break;
        case 'd': // double                      
            snprintf(json, MALLOC_BUFFER_SIZE, "\"type\":\"double\",\"value\":\"%f\"", (double)d); 
            break;
        case 'B': // BOOL
            snprintf(json, MALLOC_BUFFER_SIZE, "\"type\":\"BOOL\",\"value\":\"%s\"", ((int)paramVal)?"true":"false");
            break;
        case 'v': // void
            snprintf(json, MALLOC_BUFFER_SIZE, "\"type\":\"void\",\"ptr\":\"%p\"", paramVal);
            break;
        case '*': // char *
            snprintf(json, MALLOC_BUFFER_SIZE, "\"type\":\"char *\",\"value\":\"%s\",\"ptr\":\"%p\" ", (char *)paramVal, paramVal);
            break;
        case '{': // struct
            snprintf(json, MALLOC_BUFFER_SIZE, "\"type\":\"struct\",\"ptr\":\"%p\"", paramVal);
            break;
        case ':': // selector
            snprintf(json, MALLOC_BUFFER_SIZE, "\"type\":\"SEL\",\"value\":\"@selector(%s)\"", (paramVal)?"Selector FIXME":"nil");
            break;
        case '@': // object
            __log__("obj @\n");
            if(is_valid_pointer(paramVal)) {
                __log__("Valid pointer\n");
                fooClass = object_getClass((id)paramVal);
                if(class_respondsToSelector(fooClass, @selector(description))) {
                    __log__("Has description...");
                    NSString *desc = orig_objc_msgSend((id)paramVal, @selector(description));
                    NSString *realDesc = orig_objc_msgSend((id)desc, @selector(stringByReplacingOccurrencesOfString:withString:), @"\"", @"\\\"");
                    snprintf(json, MALLOC_BUFFER_SIZE, "\"type\":\"%s\",\"value\":\"%s\"", object_getClassName(fooClass), (char *)orig_objc_msgSend(realDesc, @selector(UTF8String)));
                } else {
                    __log__("No description available");
                    snprintf(json, MALLOC_BUFFER_SIZE, "\"type\":\"%s\",\"value\":\"%s\"", object_getClassName(fooClass), "@BARF. No [object description] method. This is probably a bug.");
                }
            } else {
                __log__("Duff pointer");
                strcpy(json, "\"type\":\"<Invalid memory address>\",\"value\":\"N/A\"");
            }
            break;
        case '#': // class
            __log__("class #\n");
            if(is_valid_pointer(paramVal)) {
                if(class_respondsToSelector((Class)paramVal, @selector(description))) {
                    NSString *desc = orig_objc_msgSend((id)paramVal, @selector(description));
                    NSString *realDesc = orig_objc_msgSend((id)desc, @selector(stringByReplacingOccurrencesOfString:withString:), @"\"", @"&#34;");
                    snprintf(json, MALLOC_BUFFER_SIZE, "\"type\":\"%s\",\"value\":\"%s\"", class_getName((Class)paramVal), (char *)orig_objc_msgSend(realDesc, @selector(UTF8String)));
                } else {
                    snprintf(json, MALLOC_BUFFER_SIZE, "\"type\":\"%s\",\"value\":\"%s\"", class_getName((Class)paramVal), "#BARF. No description. This is probably a bug.");
                }
            } else {
                strcpy(json, "\"type\":\"<Invalid memory address>\",\"value\":\"N/A\"");
            }
            break;
        default:
            snprintf(json, MALLOC_BUFFER_SIZE, "\"type\":\"UNKNOWN TYPE. Code: %s\",\"value\":\"%p\"", typeCode, paramVal);
            break;     
    }
    __log__("returning from parameter_to_JSON\n");
    return json; // caller must free()
}

extern "C" USED inline void *print_args_v(id self, SEL _cmd, std::va_list va) {
    char *json;
    struct objc_callState *callState = NULL;

    __log__("\n\n<======== print_args_v entry ========>\n");
    
    if(self && _cmd) {
        char *className, *methodName, *methodPtr, *argPtr;
        Method method = nil;
        int numArgs, k, realNumArgs;
        BOOL isInstanceMethod = true;
        char argName[MINIBUF_SIZE];
        Class c;

        // needed for all the things
        c = self->isa; 
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
        __log__("malloc/sprintf\n");
        json = (char *)malloc(MALLOC_BUFFER_SIZE);
        snprintf(json, MALLOC_BUFFER_SIZE, "{\"messageType\":\"obj_msgSend\",\"depth\":%d,\"thread\":%u,\"objectAddr\":\"%p\",\"class\":\"%s\",\"method\":\"%s\",\"isInstanceMethod\":%d,\"returnTypeCode\":\"%s\",\"numArgs\":%d,\"args\":[", get_depth(), (unsigned int)pthread_self(), self, className, methodName, isInstanceMethod, callState->returnType, realNumArgs);

        // use this to iterate over argument names
        methodPtr = methodName;
        __log__("Hitting loop...\n");
            
        // cycle through the paramter list for this method.
        // start at k=2 so that we omit Cls and SEL, the first 2 args of every function/method
        for(k=2; k < numArgs; k++) {
            char argTypeBuffer[MINIBUF_SIZE]; // safe and reasonable limit on var name length
            int argNum = k - 2;

            // non-destructive strtok() replacement
            argPtr = argName;
            while(*methodPtr != ':' && *methodPtr != '\0')
                *(argPtr++) = *(methodPtr++);
            *argPtr = (char)0;
            
            // get the type code for the argument
            __log__("argType\n");
            method_getArgumentType(method, k, argTypeBuffer, MINIBUF_SIZE);

            // if it's a pointer then we actually want the next byte.
            char *typeCode = (argTypeBuffer[0] == '^') ? &argTypeBuffer[1] : argTypeBuffer;

            // arg data
            void *paramVal = va_arg(va, void *);
            
            __log__("Parsing param -> JSON\n");
            char *paramValueJSON = parameter_to_JSON(typeCode, paramVal);

            // start the JSON for this argument
            snprintf(json, MALLOC_BUFFER_SIZE, "%s{\"name\":\"%s\",\"typeCode\":\"%s\",\"addr\":\"%p\",%s%s", json, argName, argTypeBuffer, paramVal, paramValueJSON, (argNum == realNumArgs-1) ? "}" : "},");
            free(paramValueJSON);
            
            __log__("Looping...\n");                               
        }
        __log__("Loop finished.\n");
    } else {
        __log__("======= print_args_v exit NULLLLL =====\n");
        return NULL;
    }

    callState->json = json;

#ifdef DO_SUPER_DEBUG_MODE
    char foo[MALLOC_BUFFER_SIZE];
    snprintf(foo, MALLOC_BUFFER_SIZE, "print_args_ outro %p // %p // %p\n", callState, callState->json, callState->returnType);
    __log__(foo);
    __log__("======= print_args_v exit =====\n");
#endif

    return (void *)callState; // caller must free this and its internal pointers, but only after we're completely done (ie. after we've logged the return value)
}

