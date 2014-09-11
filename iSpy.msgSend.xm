#include <substrate.h>
#include "iSpy.common.h"
#include "iSpy.msgSend.whitelist.h"
#include "iSpy.msgSend.common.h"
#include "iSpy.class.h"

id (*orig_objc_msgSend)(id theReceiver, SEL theSelector, ...);
extern FILE *superLogFP;
extern pthread_once_t key_once;
extern pthread_key_t stack_keys[ISPY_MAX_RECURSION], curr_stack_key;

namespace bf_msgSend {  
    USED static long enabled __asm__("_enabled") = 0;
    USED static void *original_objc_msgSend __asm__("_original_objc_msgSend");
    USED __attribute((weakref("replaced_objc_msgSend"))) static void replaced_objc_msgSend() __asm__("_replaced_objc_msgSend");
    static ClassMap_t *ClassMap = NULL;

    extern "C" int is_this_method_on_whitelist(id Cls, SEL selector) {
        if(Cls && selector) {
            std::string className(object_getClassName(Cls));
            std::string methodName(sel_getName(selector));
            return (*ClassMap)[className][methodName];
        }
        else
            return NO;
    }

    extern "C" void make_key() {
        // setup pthreads
        pthread_key_create(&curr_stack_key, NULL);
        pthread_setspecific(curr_stack_key, 0);
        for(int i = 0; i < ISPY_MAX_RECURSION; i++) {
            pthread_key_create(&(stack_keys[i]), NULL);
            pthread_setspecific(stack_keys[i], 0);
        }
    }

    extern "C" USED void *print_args(id self, SEL _cmd, ...) {
        void *retVal;
        std::va_list va;
        va_start(va, _cmd);
        retVal = print_args_v(self, _cmd, va);
        va_end(va);
        return retVal;
    }

    EXPORT void bf_enable_msgSend() {
        ispy_log_wtf(LOG_GENERAL, "Enabled msgSend bool!");
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
        int pagesize = sysconf(_SC_PAGE_SIZE);
        NSLog(@"Page size: %d // align: %d", pagesize, (int)objc_msgSend % pagesize);
#ifdef DO_SUPER_DEBUG_MODE
        char buf[256];
        superLogFP = fopen("/tmp/bf.log","a");
        sprintf(buf, "\n\n=================\nLOGGIN (NSThread threaded: %d)\n=================\n\n", [NSThread isMultiThreaded]);
        fputs(buf, superLogFP);
        fflush(superLogFP);
#endif
        bf_disable_msgSend();
        bf_disable_msgSend_stret();

        ClassMap = [[iSpy sharedInstance] classWhitelist];

        __log__("setup pthread_once\n");
        pthread_once(&key_once, make_key);
        dispatch_async(dispatch_get_main_queue(), ^{
            MSHookFunction((void *)objc_msgSend, (void *)replaced_objc_msgSend, (void **)&original_objc_msgSend);
            __log__("hooked\n");
            orig_objc_msgSend = (id (*)(id, SEL, ...))original_objc_msgSend;
        });
    }

// This is basically a rewrite of Subjective-C.
// It's thread-safe. Hooray!
#pragma mark _replaced_objc_msgSend (ARM)
    __asm__ (
                ".arm\n"        // force 4-byte ARM mode (not Thumb or variants)
                ".text\n"       // guess what this is

                // label our function
                "_replaced_objc_msgSend:\n"

                // Check if the obj_msgSend hook is enabled.
                // If not, just transfer control to original objc_msgSend function.
                "ldr r12, (LEna0)\n"
"LoadEna0:"     "ldr r12, [pc, r12]\n"
                "teq r12, #0\n"
                "ldreq r12, (LOrig0)\n"
"LoadOrig0:"    "ldreq pc, [pc, r12]\n"

                // Is this method on the whitelist?
                // If not, just transfer control to original objc_msgSend function.
                "push {r0-r3,lr}\n"
                "bl _is_this_method_on_whitelist\n"
                "mov r12, r0\n"
                "pop {r0-r3,lr}\n"
                "teq r12, #0\n"
                "ldreq r12, (LO2)\n"
"LoadO2:"       "ldreq pc, [pc, r12]\n"

                // Save r0, r1, r2, r3 and lr.
                "push {r0-r3,lr}\n" // first copy the registers onto the stack
                "push {r12}\n"
                "mov r0, r12\n"
                "bl _interesting_call_preflight_check\n"
                "mov r0, #32\n"     // allocate 5 * 4 bytes + 8 bytes, enough to hold 5 registers plus 3x 4-byte addresses
                "bl _malloc\n"      // malloc'd pointer returned in r0
                "pop {r1}\n"        // pop the whitelist entry type
                "mov r12, r0\n"
                "add r12, #24\n"    // move to the end of the buffer
                "stmia r12, {r1}\n" // store it at the end of the thread-specific buffer
                "bl _saveBuffer\n"  // save the malloc'd pointer thread-specific buffer. Return the buffer addr in r0.
                "mov r12, r0\n"     // keep a copy of the malloc'd buffer
                "pop {r0-r3,lr}\n"  // restore regs to original state from the stack

                // Save the registers into the malloc'd buffer
                "stmia r12, {r0-r3,lr}\n"

                // log this call to objc_msgSend
                "bl _print_args\n"
                "push {r0}\n"       // save the returned pointer to the JSON data

                "bl _loadBuffer\n"  // restore the thread-specific malloc'd buffer
                "mov r12, r0\n"     // make a copy
                "add r12, #20\n"    // move to the end of the buffer
                "pop {r2}\n"        // grab the address of the JSON data pointer
                "stmia r12, {r2}\n" // store it at the end of the thread-specific buffer

                // restore the original register values from the thread-specific buffer
                "mov r12, r0\n"
                "ldmia r12, {r0-r3,lr}\n"

                // Call original objc_msgSend
                "ldr r12, (LOrig1)\n"
"LoadOrig1:"    "ldr r12, [pc, r12]\n"
                "blx r12\n"

                "push {r0-r11}\n"           // save a copy of the return value and other regs onto the stack
                "push {r0}\n"               // save another copy of return value
                "bl _loadBuffer\n"          // get the address of the thread-specific buffer
                "pop {r1}\n"                // get the return value from objc_msgSend
                "mov r12, r0\n"
                "add r12, #20\n"
                "ldmia r12, {r0, r2}\n"
                "bl _show_retval\n"         // add the return value to the JSON buffer:
                                            // _show_retval(threadSpecificBuffer, returnValue)
                                            // returns the address of the thread-specific buffer

                // fetch the malloc'd buffer, restore the regs from it, then free() it
                //"bl _finalLoadBuffer\n"     // get malloc buffer
                "bl _loadBuffer\n"
                "push {r0}\n"               // save buffer address on stack
                "mov r12, r0\n"             // move buffer address into general purpose reg...
                "ldmia r12, {r0-r3,lr}\n"   // ...then restore the original registers from it (clobbers r12)
                "pop {r12}\n"               // once again put buffer address in r12
                "push {r0-r3,lr}\n"         // save the restored registers on the stack so we can call free()
                "mov r0, r12\n"             // put the malloc'd buffer address into r0
                "bl _free\n"                // free() the malloc'd buffer
                "bl _cleanUp\n"
                "pop {r0-r3,lr}\n"          // restore the saved registers from the stack (we only care about lr)

                // restore the return value and other regs
                "pop {r0-r11}\n"

                // return to caller
                "bx lr\n"

    "LEna0:     .long _enabled - 8 - (LoadEna0)\n"
    "LOrig0:    .long _original_objc_msgSend - 8 - (LoadOrig0)\n"
    "LOrig1:    .long _original_objc_msgSend - 8 - (LoadOrig1)\n"
    "LO2:       .long _original_objc_msgSend - 8 - (LoadO2)\n"
    );
} // namespace
