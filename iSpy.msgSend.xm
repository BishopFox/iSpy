/*
    iSpy - Bishop Fox iOS hooking framework.

     objc_msgSend() logging.

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

id (*orig_objc_msgSend)(id theReceiver, SEL theSelector, ...);

namespace bf_msgSend {  
    static pthread_once_t key_once = PTHREAD_ONCE_INIT;
    static pthread_key_t thr_key;
    static pthread_mutex_t mutex_objc_msgSend = PTHREAD_MUTEX_INITIALIZER;
    USED static long rx_reserve[6] __asm__("_rx_reserve");
    USED static long enabled __asm__("_enabled") = 0;
    USED static void *original_objc_msgSend __asm__("_original_objc_msgSend");
    __attribute__((used)) __attribute((weakref("replaced_objc_msgSend"))) static void replaced_objc_msgSend() __asm__("_replaced_objc_msgSend");

    extern "C" int is_this_method_on_whitelist(id Cls, SEL selector) {
        if(Cls && selector)
            return bf_objc_msgSend_whitelist_entry_exists(object_getClassName(Cls), sel_getName(selector));
        else
            return NO;
    }

    static void lr_list_destructor(void* value) {
        delete reinterpret_cast<std::stack<lr_node>*>(value);
    }
    
    pthread_rwlock_t stackLock;

    static void make_key() {
        // setup pthreads
        pthread_key_create(&thr_key, lr_list_destructor);
        pthread_rwlock_init(&stackLock, NULL);
    }

    extern "C" USED void show_retval (const char* addr) {
    }

    extern "C" USED void do_objc_msgSend_mutex_lock() {
        pthread_mutex_lock(&mutex_objc_msgSend);

    }

    extern "C" USED void do_objc_msgSend_mutex_unlock() {
        pthread_mutex_unlock(&mutex_objc_msgSend);
    }

    static std::stack<lr_node>& get_lr_list() {
        std::stack<lr_node>* stack = reinterpret_cast<std::stack<lr_node>*>(pthread_getspecific(thr_key));
        if (stack == NULL) {
            stack = new std::stack<lr_node>;
            int err = pthread_setspecific(thr_key, stack);
            if (err) {
                ispy_log_debug(LOG_MSGSEND, "[msgSend] Error: pthread_setspecific() Committing suicide.\n");
                delete stack;
                stack = NULL;
            }
        }
        return *stack;
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
                snprintf(buf, 1024, "%s", x == kCFBooleanTrue ? "True" : "False");
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
        //bf_logwrite_msgSend(LOG_MSGSEND, "<%s %p>", object_getClassName((id)x));
    }

    extern "C" USED int is_valid_pointer(void *ptr) {
        int ret = madvise(ptr, 1, MADV_NORMAL);
        if(ret == 0)
            return YES;

        if(errno == EINVAL || errno == ENOMEM)
            return NO;
        else
            return YES;
    }


    extern "C" USED void print_args(id self, SEL _cmd, ...) {
        if(self && _cmd) {

            // always call this first to ensure the class is initialized
            Class c = orig_objc_msgSend(self, @selector(class));
            if(!c) {
                bf_logwrite_msgSend(LOG_MSGSEND, "\n\nERROR c=nil\n\n");
                return;
            }

            va_list va;
            char *className = (char *)object_getClassName(self);
            char *methodName = (char *)strdup(sel_getName(_cmd));
            static unsigned int counter = 0;
            char buf[1027], buf2[1027];
            Method method = nil;
            int numArgs, k, realNumArgs;
            BOOL isInstanceMethod = true;
            char *tmp;
            id foo, fooId;
            Class fooClass;
            
            // We need to determine if "self" is a meta class or an instance of a class.
            // We can't use Apple's class_isMetaClass() here because it seems to randomly crash just
            // a little too often. Always class_isMetaClass() and always in this piece of code. 
            // Maybe it's shit, maybe it's me. Whatever.
            // Instead we fudge the same functionality, which is nice and stable.
            // 1. Get the name of the object being passed as "self"
            // 2. Get the metaclass of "self" based on its name
            // 3. Compare the metaclass of "self" to "self". If they're the same, it's a metaclass.
            //bool meta = (objc_getMetaClass(className) == object_getClass(self));
            bool meta = (id)c == self;
            
            if(!meta) {
                method = class_getInstanceMethod(object_getClass(self), _cmd);
            } else {
                method = class_getClassMethod(object_getClass(self), _cmd);
                isInstanceMethod = false;
            }

            if(!method || !className || !methodName) {
                bf_logwrite_msgSend(LOG_MSGSEND, "\n\nERROR method=nil or classNAme or methodName\n\n");
                return;
            }

            numArgs = method_getNumberOfArguments(method);
            realNumArgs = numArgs - 2;
            tmp = methodName;

            // start the JSON block
            bf_logwrite_msgSend(LOG_MSGSEND, "{\n\"class\":\"%s\",\n\"method\":\"%s\",\n\"isInstanceMethod\":%d,\n\"numArgs\":%d,\n\"args\":[\n", className, methodName, isInstanceMethod, realNumArgs);

            va_start(va, _cmd);

            // cycle through the paramter list for this method.
            // start at k=2 so that we omit Cls and SEL, the first 2 args of every function/method
            for(k=2; k < numArgs; k++) {
                char tmpBuf[256]; // safe and reasonable limit on var name length
                char *type = NULL;
                char *name = NULL;
                int argNum = k - 2;
                
                // get the arg name
                name = strsep(&methodName, ":");
                if(!name) {
                    bf_logwrite_msgSend(LOG_MSGSEND, "um, so p=NULL in arg printer for class methods... weird. (aka no method name)");
                    continue;
                }
                
                // get the type code for the argument
                method_getArgumentType(method, k, tmpBuf, 255);
                char *typeCode = (tmpBuf[0] == '^') ? &tmpBuf[1] : tmpBuf;

/*                // get human-readable type data
                if((type = (char *)bf_get_type_from_signature(tmpBuf))==NULL) {
                    bf_logwrite(LOG_MSGSEND, "Out of mem");
                    break;
                }
*/
                // arg data
                void *paramVal = va_arg(va, void *);
                
                // start the JSON for this argument
                bf_logwrite_msgSend(LOG_MSGSEND, "{\n\t\"name\":\"%s\",\n\t\"typeCode\":\"TBD\",\n\t\"type\":\"TBD\",\n\t\"addr\":\"%p\",\n", name, paramVal);

                // lololol
                unsigned long v = (unsigned long)paramVal;
                double d = (double)v;

                switch(*typeCode) {
                    case 'c': // char
                    case 'i': // int
                    case 's': // short
                    case 'l': // long
                    case 'q': // long long
                        bf_logwrite_msgSend(LOG_MSGSEND, "\t\"value\":%lld\n", (long long)paramVal); 
                        break;
                    case 'C': // unsigned char
                    case 'I': // unsigned int
                    case 'S': // unsigned short
                    case 'L': // unsigned long
                    case 'Q': // unsigned long long
                        bf_logwrite_msgSend(LOG_MSGSEND, "\t\"value\":%lld", (long long)paramVal); 
                        break;
                    case 'f': // float
                    case 'd': // double
                        bf_logwrite_msgSend(LOG_MSGSEND, "\t\"value\":%llf", (double)d); 
                        break;
                    case 'B': // BOOL
                        bf_logwrite_msgSend(LOG_MSGSEND, "\t\"value\":%s", ((int)paramVal)?"true":false);
                        break;
                    case 'v': // void
                        bf_logwrite_msgSend(LOG_MSGSEND, "\t\"ptr\":\"%p\"", paramVal);
                        break;
                    case '*': // char *
                        bf_logwrite_msgSend(LOG_MSGSEND, "\t\"value\":\"%s\",\n\t\"ptr\":\"%p\" ", (char *)paramVal, paramVal);
                        break;
                    case '{': // struct
                        bf_logwrite_msgSend(LOG_MSGSEND, "\t\"ptr\":\"%p\"", paramVal);
                        break;
                    case ':': // selector
                        bf_logwrite_msgSend(LOG_MSGSEND, "\t\"value\":\"@selector(%s)\"", (paramVal)?(char *)paramVal:"nil");
                        break;
                    case '@': // object
                    case '#':
                        if(is_valid_pointer(paramVal)) {
                            fooId = (id)paramVal;
                            fooClass = object_getClass(fooId);
                            bf_logwrite_msgSend(LOG_MSGSEND, "\t\"type\":\"%s\",\n", class_getName(fooClass));
                            bf_logwrite_msgSend(LOG_MSGSEND, "\t\"value\":\"%s\"", (char *)orig_objc_msgSend(orig_objc_msgSend(fooId, @selector(description)), @selector(UTF8String)));
                        } else {
                            bf_logwrite_msgSend(LOG_MSGSEND, "\t\"type\":\"<Invalid memory address>\"");
                        }
                        break;
                    default:
                        bf_logwrite_msgSend(LOG_MSGSEND, "\t\"dvalue\":\"%p\"", fooId);
                        break;
                }
                bf_logwrite_msgSend(LOG_MSGSEND, "}%c\n", (argNum==realNumArgs-1)?' ':',');
                //free(type);

            }

            // finish the JSON block
            bf_logwrite_msgSend(LOG_MSGSEND, "%s}\n\n", (1)?"]":"");

            free(tmp);
            va_end(va);


            // keep a local copy of the log in /tmp/bf_msgsend
            strcat(buf, "\n");
            ispy_log_info(LOG_MSGSEND, buf);
        }

        return;
    }

    extern "C" USED void push_lr (intptr_t lr) {
        lr_node node;
        node.lr = lr;
        memcpy(node.regs, rx_reserve, 6); // save our thread's registers into a thread-specific array
        node.should_filter = true;
        get_lr_list().push(node);
    }

    extern "C" USED  intptr_t pop_lr () { 
        std::stack<lr_node>& lr_list = get_lr_list();
        int retval = lr_list.top().lr;
        lr_list.pop();
        return retval;
    }

    EXPORT void bf_enable_msgSend() {
        enabled=1;
    }

    EXPORT void bf_disable_msgSend() {
        enabled=0;
    }

    EXPORT int bf_get_msgSend_state() {
        return enabled;
    }

    // This is called in the main iSpy constructor.
    EXPORT void bf_hook_msgSend() {
        bf_disable_msgSend();
        pthread_once(&key_once, make_key);
        pthread_key_create(&thr_key, lr_list_destructor);
        MSHookFunction((void *)objc_msgSend, (void *)replaced_objc_msgSend, (void **)&original_objc_msgSend);
        orig_objc_msgSend = (id (*)(id, SEL, ...))original_objc_msgSend;
    }

// This is ripped from Subjective-C and bastardized like a mofo.
#pragma mark _replaced_objc_msgSend (ARM)
    __asm__ (".arm\n"
        ".text\n"
                "_replaced_objc_msgSend:\n"
                
                // Check if the hook is enabled. If not, quit now.
                "ldr r12, (LEna0)\n"
    "LoadEna0:"    "ldr r12, [pc, r12]\n"
                "teq r12, #0\n"
                "ldreq r12, (LOrig0)\n"
    "LoadOrig0:""ldreq pc, [pc, r12]\n"

                // is this method on the whitelist?
                "push {r0-r11,lr}\n"
                "bl _is_this_method_on_whitelist\n"
                "mov r12, r0\n" 
                "pop {r0-r11,lr}\n"
                "teq r12, #0\n"
                "ldreq r12, (LO2)\n"
    "LoadO2:"   "ldreq pc, [pc, r12]\n"

                // Save regs, set pthread mutex, restore regs
                // TBD: find a more elegant way to do this in a thread-safe way.
                "push {r0-r11,lr}\n"
                "bl _do_objc_msgSend_mutex_lock\n"
                "pop {r0-r11,lr}\n"

                // Save the registers
                "ldr r12, (LSR1)\n"
    "LoadSR1:"    "add r12, pc, r12\n"
                "stmia r12, {r0-r3}\n"
        
                // Push lr onto our custom stack.
                "mov r0, lr\n"
                "bl _push_lr\n"
                            
                // Log this call to objc_msgSend
                "ldr r2, (LSR3)\n"
    "LoadSR3:"    "add r12, pc, r2\n"
                "ldmia r12, {r0-r3}\n"

                //"push {r0-r11,lr}\n"
                //"bl _do_objc_msgSend_mutex_unlock\n"
                //"pop {r0-r11,lr}\n"

                "bl _print_args\n"
                
                //"push {r0-r11,lr}\n"
                //"bl _do_objc_msgSend_mutex_lock\n"
                //"pop {r0-r11,lr}\n"

                // Restore the registers.
                "ldr r1, (LSR4)\n"
    "LoadSR4:"    "add r2, pc, r1\n"
                "ldmia r2, {r0-r3}\n"
                    
                // Unlock the pthread mutex
                "push {r0-r11,lr}\n"
                "bl _do_objc_msgSend_mutex_unlock\n"
                "pop {r0-r11,lr}\n"

                // Call original objc_msgSend
                "ldr r12, (LOrig1)\n"
    "LoadOrig1:""ldr r12, [pc, r12]\n"
                "blx r12\n"

                // Print return value.
                "push {r0-r3}\n"    // assume no intrinsic type takes >128 bits...
                "mov r0, sp\n"
                "bl _show_retval\n"
                "bl _pop_lr\n"
                "mov lr, r0\n"
                "pop {r0-r3}\n"
                "bx lr\n"
                    
    "LEna0:         .long _enabled - 8 - (LoadEna0)\n"
    "LOrig0:    .long _original_objc_msgSend - 8 - (LoadOrig0)\n"
    "LSR1:        .long _rx_reserve - 8 - (LoadSR1)\n"
    "LSR3:        .long _rx_reserve - 8 - (LoadSR3)\n"
    "LSR4:        .long _rx_reserve - 8 - (LoadSR4)\n"
    "LOrig1:    .long _original_objc_msgSend - 8 - (LoadOrig1)\n"
    "LO2:       .long _original_objc_msgSend - 8 - (LoadO2)\n"
    );
} // namespace msgSend
