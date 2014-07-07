/*
    iSpy - Bishop Fox iOS hooking framework.

     objc_msgSend_stret() logging.

     This will hook objc_msgSend and objc_msgSend_stret and replace them with functions
     that log every single method called during execution of the target app.

     * Logs to "/tmp/iSpy.log"
     * Generates a lot of data and incurs significant overhead
     * Will make your app slow as shit
     * Will generate a large log file pretty fast

     How to use:

     * Call bf_init_msgSend_logging() exactly ONCE.
     * This will install the objc_msgSend* hooks in preparation for logging.
     * When you want to switch on logging, call bf_enable_msgSend_logging().
     * When you want to switch off logging, call bf_disable_msgSend_logging().
     * Repeat the enable/disable cycle as necessary.

     NOTE:    All of this functionality is already built into iSpy. For more info,
     search for the iSpy constructor (called "%ctor") later in the code.

     - Enable/Disable in Settings app.
 */
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
#include "iSpy.msgSend.whitelist.h"
#include <stack>
#include <pthread.h>
#include "iSpy.msgSend.common.h"

namespace bf_msgSend_stret {

    static pthread_once_t key_once_stret = PTHREAD_ONCE_INIT;
    static pthread_key_t thr_key_stret;
    static pthread_mutex_t mutex_objc_msgSend_stret = PTHREAD_MUTEX_INITIALIZER;
    USED static long rx_reserve_stret[6] __asm__("_rx_reserve_stret");    // r0, r1, r2, r3, lr, saved.
    USED static long enabled_stret __asm__("_enabled_stret") = 0;
    USED static void *original_objc_msgSend_stret __asm__("_original_objc_msgSend_stret");

    __attribute__((used, weakref("replaced_objc_msgSend_stret"))) static void replaced_objc_msgSend_stret() __asm__("_replaced_objc_msgSend_stret");

    extern "C" int is_this_method_on_whitelist_stret(int *retVal, id Cls, SEL selector) {
        if(Cls && selector)
            return bf_objc_msgSend_whitelist_entry_exists(object_getClassName(Cls), sel_getName(selector));
        else
            return NO;
    }


    extern "C" USED void do_objc_msgSend_stret_mutex_lock() {
        pthread_mutex_lock(&mutex_objc_msgSend_stret);
    }

    extern "C" USED void do_objc_msgSend_stret_mutex_unlock() {
        pthread_mutex_unlock(&mutex_objc_msgSend_stret);
    }

    static std::stack<lr_node>& get_lr_list_stret() {
        std::stack<lr_node>* stack = reinterpret_cast<std::stack<lr_node>*>(pthread_getspecific(thr_key_stret));
        if (stack == NULL) {
            stack = new std::stack<lr_node>;
            int err = pthread_setspecific(thr_key_stret, stack);
            if (err) {
                ispy_log_debug(LOG_GENERAL, "[msgSend_stret] Error: pthread_setspecific() Committing suicide.\n");
                delete stack;
                stack = NULL;
            }
        }
        return *stack;
    }

    extern "C" USED void push_lr_stret (intptr_t lr) {
        lr_node node;
        node.lr = lr;
        memcpy(node.regs, rx_reserve_stret, 6); // save our thread's registers into a thread-specific array
        node.should_filter = true;
        get_lr_list_stret().push(node);
    }

    extern "C" USED  intptr_t pop_lr_stret () { 
        std::stack<lr_node>& lr_list = get_lr_list_stret();
        int retval = lr_list.top().lr;
        lr_list.pop();
        return retval;
    }

    extern "C" USED void print_args_stret(void* retval, id self, SEL _cmd, ...) {
          // party of the __log__ speed optimization. This is not portable and may break in future Objective-C runtimes.
        struct objc_class {
            Class isa;
            Class super_class;
            const char *name;
            long version;
            long info;
            long instance_size;
            struct objc_ivar_list *ivars;
            struct objc_method_list **methodLists;
            struct objc_cache *cache;
            struct objc_protocol_list *protocols;
        };
        __log__("\n\n<======== Entry ========>\n");

    if(self && _cmd) {
            va_list va;
            char *className, *methodName, *methodPtr, *argPtr;
            Method method = nil;
            int numArgs, k, realNumArgs;
            BOOL isInstanceMethod = true;
            id fooId;
            Class fooClass;
            char json[2048]; // meh
            char argName[256]; // srlsy
            char buf[1027]; // yup
            Class c;
            
            // this is pretty egregious abuse of the runtime in the name of speed.
            //c = (struct objc_class *)self; //(struct objc_class *)orig_objc_msgSend(self, @selector(class));
            c = (Class)object_getClass(self); // orig_objc_msgSend(self, @selector(class));
            __log__("Test\n");
            className = (char *)object_getClassName(self);
            __log__("Test2\n");
            //methodName = (char *)_cmd->sel_id;
            methodName = (char *)sel_getName(_cmd);
            __log__("Test3\n");
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
            

            if(!meta) {
                __log__("instance\n");
                method = class_getInstanceMethod(c, (SEL)_cmd);
            } else {
                __log__("class\n");
                method = class_getClassMethod(c, (SEL)_cmd);
                //method = class_getClassMethod((Class)c, (SEL)_cmd);
                isInstanceMethod = false;
            }
            
            if(!method || !className || !methodName) {
                return;
            }

            __log__("args\n");
            numArgs = method_getNumberOfArguments(method);
            realNumArgs = numArgs - 2;

            __log__("sprintf\n");
            // start the JSON block
            snprintf(json, sizeof(json), "{\"messageType\":\"objc_msgSend_stret\",\"class\":\"%s\",\"method\":\"%s\",\"isInstanceMethod\":%d,\"numArgs\":%d,\"args\":[", className, methodName, isInstanceMethod, realNumArgs);

            __log__("vaargs\n");
            // setup varargs
            va_start(va, _cmd);
            
            
            
            // use this to iterate over argument names
            methodPtr = methodName;
            __log__("Hitting loop...\n");
            
            // cycle through the paramter list for this method.
            // start at k=2 so that we omit Cls and SEL, the first 2 args of every function/method
            for(k=2; k < numArgs; k++) {
                char argTypeBuffer[256]; // safe and reasonable limit on var name length
                char *type = NULL;
                int argNum = k - 2;

                argPtr = argName;
                while(*methodPtr != ':' && *methodPtr != '\0')
                    *(argPtr++) = *(methodPtr++);
                *argPtr = (char)0;
                
                __log__("argType\n");
                // get the type code for the argument
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
                        snprintf(json, sizeof(json), "%s\"type\":\"char\",\"value\":0x%x (%d) (%c)", json, (unsigned int)paramVal, (int)paramVal, (int)paramVal); 
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
                        snprintf(json, sizeof(json), "%s\"type\":\"char\",\"value\":0x%x (%u) ('%c')", json, (unsigned int)paramVal, (unsigned int)paramVal, (unsigned int)paramVal); 
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
                            //unsigned int *f = (unsigned int *)paramVal;
                            sprintf(buf, "%p\n", paramVal);
                            __log__(buf);
                            //fooId = (id)paramVal;
                            fooClass = object_getClass((id)paramVal);
                            __log__("name\n");
                            __log__(class_getName(fooClass));
                            __log__("sprintf\n");
                            snprintf(json, sizeof(json), "%s\"type\":\"%s\",", json, class_getName(fooClass)); //(struct objc_class *)paramVal)->name); //class_getName(fooClass));
                            __log__("value\n");
                            if(class_respondsToSelector(fooClass, @selector(description))) {
                                __log__("desc\n");
                                NSString *desc = orig_objc_msgSend(fooClass, @selector(description));
                                __log__("sprintf\n");
                                snprintf(json, sizeof(json), "%s\"value\":\"%s\"", json, (char *)orig_objc_msgSend(desc, @selector(UTF8String)));
                            } else {
                                __log__("no desc\n");
                                snprintf(json, sizeof(json), "%s\"value\":\"%s\"", json, "BARF");
                            }
                        } else {
                            __log__("invalid pointer\n");
                            snprintf(json, sizeof(json), "%s\"type\":\"<Invalid memory address>\",\"value\":\"N/A\"", json);
                        }
                        break;
                    case '#':
                        if(is_valid_pointer(paramVal)) {
                            sprintf(buf, "%p\n", paramVal);
                            __log__("CLASS valid pointer. get class...\n");
                            __log__(buf);
                            //fooId = (id)paramVal;
                            __log__("name\n");
                            __log__(class_getName((Class)paramVal));
                            __log__("sprintf\n");
                            snprintf(json, sizeof(json), "%s\"type\":\"%s\",", json, class_getName((Class)paramVal)); //(struct objc_class *)paramVal)->name); //class_getName(fooClass));
                            __log__("value\n");
                            if(class_respondsToSelector((Class)paramVal, @selector(description))) {
                                __log__("desc\n");
                                NSString *desc = orig_objc_msgSend((id)paramVal, @selector(description));
                                __log__("sprintf\n");
                                snprintf(json, sizeof(json), "%s\"value\":\"%s\"", json, (char *)orig_objc_msgSend(desc, @selector(UTF8String)));
                            } else {
                                __log__("no desc\n");
                                snprintf(json, sizeof(json), "%s\"value\":\"%s\"", json, "NO_DATA_FIXME");
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
                //snprintf(json, sizeof(json), "%s}%c", json, (argNum==realNumArgs-1)?' ':','); 
                __log__("Looping...\n");                               
            }
            __log__("Loop finished.\n");

            // finish the JSON block
            strlcat(json, "]}", sizeof(json));
            //snprintf(json, sizeof(json), "%s]}\n", json);
            va_end(va);

            __log__("writing to websocket\n");
            // b00m!
            bf_websocket_write(json);
        }

        return;
    }

    static void lr_list_destructor(void* value) {
        delete reinterpret_cast<std::stack<lr_node>*>(value);
    }

    static void make_key_stret() {
        // setup pthreads
        pthread_key_create(&thr_key_stret, lr_list_destructor);
    }

    EXPORT void 
    bf_enable_msgSend_stret() {
        enabled_stret=1;
    }

    EXPORT void bf_disable_msgSend_stret() {
        enabled_stret=0;
    }

    EXPORT void bf_hook_msgSend_stret() {
        bf_disable_msgSend_stret();
        pthread_once(&key_once_stret, make_key_stret);
        pthread_key_create(&thr_key_stret, lr_list_destructor);
        MSHookFunction((void *)objc_msgSend_stret, (void *)replaced_objc_msgSend_stret, (void **)&original_objc_msgSend_stret);
    }

#pragma mark _replaced_objc_msgSend_stret (ARM)
    __asm__ (
        ".text\n"
                "_replaced_objc_msgSend_stret:\n"

                // 0. Check if the hook is enabled. If not, quit now.
                "ldr r12, (LES0)\n"
    "LoadES0:"    "ldr r12, [pc, r12]\n"
                "teq r12, #0\n"
                "ldreq r12, (LOS0)\n"
    "LoadOS0:"    "ldreq pc, [pc, r12]\n"

                // is this method on the whitelist?
                "push {r0-r11,lr}\n"
                "bl _is_this_method_on_whitelist_stret\n"
                "mov r12, r0\n" 
                "pop {r0-r11,lr}\n"
                "teq r12, #0\n"
                "ldreq r12, (LOS2)\n"
    "LoadOS2:"   "ldreq pc, [pc, r12]\n"

    // Save regs, set pthread mutex, restore regs
                "push {r0-r11,lr}\n"
                "bl _do_objc_msgSend_stret_mutex_lock\n"
                "pop {r0-r11,lr}\n"    

                // 1. Save the registers.
                "ldr r12, (LSS1)\n"
    "LoadSS1:"    "add r12, pc, r12\n"
                "stmia r12, {r0-r3}\n"
                
                // 2 Push lr onto our custom stack.
                "mov r0, lr\n"
                "bl _push_lr_stret\n"
                
                // 3. Print the arguments.
                "ldr r2, (LSS3)\n"
    "LoadSS3:"    "add r12, pc, r2\n"
                "ldmia r12, {r0-r3}\n"
                "bl _print_args_stret\n"
                
                // 4. Restore the registers.
                "ldr r1, (LSS4)\n"
    "LoadSS4:"    "add r2, pc, r1\n"
                "ldmia r2, {r0-r3}\n"
                
                // Unlock the pthread mutex
                "push {r0-r11,lr}\n"
                "bl _do_objc_msgSend_stret_mutex_unlock\n"
                "pop {r0-r11,lr}\n"
                
                // 5. Call original objc_msgSend_stret
                ".arm\n"
                "ldr r12, (LOS1)\n"
    "LoadOS1:"    "ldr r12, [pc, r12]\n"
                "blx r12\n"
                
                // 6. Print return value.
                "str r0, [sp, #-4]!\n"
                "bl _show_retval\n"
                "bl _pop_lr_stret\n"
                "mov lr, r0\n"
                "ldr r0, [sp], #4\n"
                "bx lr\n"                
                
    "LES0:        .long _enabled_stret - 8 - (LoadES0)\n"
    "LOS0:        .long _original_objc_msgSend_stret - 8 - (LoadOS0)\n"
    "LSS1:        .long _rx_reserve_stret - 8 - (LoadSS1)\n"
    "LSS3:        .long _rx_reserve_stret - 8 - (LoadSS3)\n"
    "LSS4:        .long _rx_reserve_stret - 8 - (LoadSS4)\n"
    "LOS1:        .long _original_objc_msgSend_stret - 8 - (LoadOS1)\n"
    "LOS2:       .long _original_objc_msgSend_stret - 8 - (LoadOS2)\n"
    );
} // namespace msgSend_stret

