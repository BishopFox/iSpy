#include <substrate.h>
#include "iSpy.common.h"
#include "iSpy.msgSend.whitelist.h"
#include "iSpy.msgSend.common.h"
#include "iSpy.class.h"

namespace bf_objc_msgSend_stret {
    static pthread_once_t key_once_stret = PTHREAD_ONCE_INIT;
    static pthread_key_t stack_keys_stret[ISPY_MAX_RECURSION], curr_stack_key_stret;
    USED static long enabled_stret __asm__("_enabled_stret") = 0;
    USED static void *original_objc_msgSend_stret __asm__("_original_objc_msgSend_stret");
    static ClassMap_t *ClassMap_stret;
    __attribute__((used)) __attribute((weakref("replaced_objc_msgSend_stret"))) static void replaced_objc_msgSend_stret() __asm__("_replaced_objc_msgSend_stret");

    extern "C" int is_this_method_on_whitelist_stret(void *dummy, id Cls, SEL selector) {
        if(Cls && selector) {
            std::string className(object_getClassName(Cls));
            std::string methodName(sel_getName(selector));
            return (*ClassMap_stret)[className][methodName];
            //return bf_objc_msgSend_whitelist_entry_exists(object_getClassName(Cls), sel_getName(selector));
        }
        else
            return NO;
    }

    static void make_key_stret() {
        // setup pthreads
        pthread_key_create(&curr_stack_key_stret, NULL);
        pthread_setspecific(curr_stack_key_stret, 0);
        for(int i = 0; i < ISPY_MAX_RECURSION; i++) {
            pthread_key_create(&(stack_keys_stret[i]), NULL);
            pthread_setspecific(stack_keys_stret[i], 0);    
        }
    }

    extern "C" USED void increment_depth_stret() {
        int currentDepth = (int)pthread_getspecific(curr_stack_key_stret);
        currentDepth++;
        pthread_setspecific(curr_stack_key_stret, (void *)currentDepth);
    }

    extern "C" USED void decrement_depth_stret() {
        int currentDepth = (int)pthread_getspecific(curr_stack_key_stret);
        currentDepth--;
        pthread_setspecific(curr_stack_key_stret, (void *)currentDepth);
    }

    extern "C" USED int get_depth_stret() {
        return (int)pthread_getspecific(curr_stack_key_stret);
    }

    extern "C" USED id saveBuffer_stret(id buffer) {
        char buf[1024];

        increment_depth_stret();
        sprintf(buf, ">> stret Saving (%p[%d]) buffer: %p <<\n", pthread_self(), get_depth_stret(), buffer);
        __log__(buf);
        pthread_setspecific(stack_keys_stret[get_depth_stret()], buffer);
        __log__(">> stret SAVE DONE <<\n\n");
        return buffer;
    }

    extern "C" USED void *loadBuffer_stret() {
        void *retVal;
        char buf[1024];
        sprintf(buf, ">> stret Loading (%p[%d]) <<\n", pthread_self(), get_depth_stret());
        __log__(buf);
        retVal = pthread_getspecific(stack_keys_stret[get_depth_stret()]);
        sprintf(buf, ">> stret Got buffer: %p << \n", retVal);
        __log__(buf);
        __log__(">> stret LOAD DONE <<\n\n");
        return retVal;
    }

    extern "C" USED void *finalLoadBuffer_stret() {
        void *retVal;
        char buf[1024];
        sprintf(buf, ">> stret Final loading (%p[%d]) <<\n", pthread_self(), get_depth_stret());
        __log__(buf);
        retVal = pthread_getspecific(stack_keys_stret[get_depth_stret()]);
        sprintf(buf, ">> stret Final got buffer: %p << \n", retVal);
        __log__(buf);
        __log__(">> stret FINAL LOAD DONE <<\n\n");
        decrement_depth_stret();
        return retVal;
    }

    extern "C" USED void print_args_stret(void *retval, id self, SEL _cmd, ...) {
        std::va_list va;
        va_start(va, _cmd);
        print_args_v(self, _cmd, va);
        va_end(va);
    }

    EXPORT void bf_hook_msgSend_stret() {
        __log__("Hook stret\n");
        ClassMap_stret = [[iSpy sharedInstance] classWhiteList];
        pthread_once(&key_once_stret, make_key_stret);
        MSHookFunction((void *)objc_msgSend_stret, (void *)replaced_objc_msgSend_stret, (void **)&original_objc_msgSend_stret);
        __log__("Hooked\n");
    }

    EXPORT void bf_enable_msgSend_stret() {
        enabled_stret=1;
    }

    EXPORT void bf_disable_msgSend_stret() {
        enabled_stret=0;
    }


#pragma mark _replaced_objc_msgSend_stret (ARM)
    __asm__ (   
                ".arm\n"        // force 4-byte ARM mode (not Thumb or variants)
                ".text\n"       // guess what this is
                
"_replaced_objc_msgSend_stret:\n"
                
                // Check if the obj_msgSend hook is enabled. 
                // If not, just transfer control to original objc_msgSend function.
                "ldr r12, (LSEna0)\n"
"LoadSEna0:"    "ldr r12, [pc, r12]\n"
                "teq r12, #0\n"
                "ldreq r12, (LSOrig0)\n"
"LoadSOrig0:"   "ldreq pc, [pc, r12]\n"

                // Is this method on the whitelist?
                // If not, just transfer control to original objc_msgSend function.
                "push {r0-r3,lr}\n"
                "bl _is_this_method_on_whitelist_stret\n"
                "mov r12, r0\n" 
                "pop {r0-r3,lr}\n"
                "teq r12, #0\n"
                "ldreq r12, (LSO2)\n"
"LoadSO2:"      "ldreq pc, [pc, r12]\n"

                // Save r0, r1, r2, r3 and lr.
                "push {r0-r3,lr}\n"     // first copy the registers onto the stack
                "mov r0, #20\n"         // allocate 5 * 4 bytes, enough to hold 4 registers 
                "bl _malloc\n"          // malloc'd pointer returned in r0
                "bl _saveBuffer_stret\n"// save the malloc'd pointer thread-specific buffer. Return the buffer addr in r0.
                "mov r12, r0\n"         // keep a copy of the malloc'd buffer
                "pop {r0-r3,lr}\n"      // restore regs to original state from the stack

                // Save the registers into the malloc'd buffer
                "stmia r12, {r0-r3,lr}\n"
        
                // log this call to objc_msgSend
                "bl _print_args_stret\n"

                // restore the malloc'd buffer
                "bl _loadBuffer_stret\n"

                // restore the regs saved in the buffer 
                "mov r12, r0\n"
                "ldmia r12, {r0-r3,lr}\n"

                // Call original objc_msgSend
                "ldr r12, (LSOrig1)\n"
"LoadSOrig1:"   "ldr r12, [pc, r12]\n"
                "blx r12\n"

                // save a copy of the return value on the stack
                "push {r0}\n"

                // Print return value
                "bl _show_retval\n"

                // fetch the malloc'd buffer, restore the regs from it, then free() it
                "bl _finalLoadBuffer_stret\n"     // get malloc buffer
                "push {r0}\n"               // save buffer address on stack
                "mov r12, r0\n"             // move buffer address into general purpose reg...
                "ldmia r12, {r0-r3,lr}\n"   // ...then restore the original registers from it (clobbers r12)
                "pop {r12}\n"               // once again put buffer address in r12
                "push {r0-r3,lr}\n"         // save the restored registers on the stack so we can call free()
                "mov r0, r12\n"             // put the malloc'd buffer address into r0
                "bl _free\n"                // free() the malloc'd buffer
                "pop {r0-r3,lr}\n"          // restore the saved registers from the stack
                
                // restore the return value
                "pop {r0}\n"                
                
                // return to caller
                "bx lr\n"
                    
    "LSEna0:     .long _enabled_stret - 8 - (LoadSEna0)\n"
    "LSOrig0:    .long _original_objc_msgSend_stret - 8 - (LoadSOrig0)\n"
    "LSOrig1:    .long _original_objc_msgSend_stret - 8 - (LoadSOrig1)\n"
    "LSO2:       .long _original_objc_msgSend_stret - 8 - (LoadSO2)\n"
    );

} // namespace msgSend_stret
