#include <substrate.h>
#include "iSpy.common.h"
#include "iSpy.msgSend.whitelist.h"
#include "iSpy.msgSend.common.h"
#include "iSpy.class.h"

//
// In this file, all the __log__() functions are #ifdef'd out unless you add:
//      #define DO_SUPER_DEBUG_MODE 1
// to iSpy.msgSend.common.h. Don't do this unless you're debugging iSpy - it's super slow.
//

namespace bf_objc_msgSend_stret {
    USED static long enabled_stret __asm__("_enabled_stret") = 0;
    USED static void *original_objc_msgSend_stret __asm__("_original_objc_msgSend_stret");
    USED __attribute((weakref("replaced_objc_msgSend_stret"))) static void replaced_objc_msgSend_stret() __asm__("_replaced_objc_msgSend_stret");

    extern "C" USED inline int is_this_method_on_whitelist_stret(void *dummy, id Cls, SEL selector) {
        return is_this_method_on_whitelist(Cls, selector);
    }

    extern "C" USED inline void *print_args_stret(void *retval, id self, SEL _cmd, ...) {
        void *retVal;
        std::va_list va;
        va_start(va, _cmd);
        retVal = print_args_v(self, _cmd, va);
        va_end(va);
        return retVal;
    }

    EXPORT void bf_hook_msgSend_stret() {
        __log__("Hook stret\n");
        dispatch_async(dispatch_get_main_queue(), ^{
            MSHookFunction((void *)objc_msgSend_stret, (void *)replaced_objc_msgSend_stret, (void **)&original_objc_msgSend_stret);
            __log__("Hooked\n");
        });
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
                "push {r0-r3,lr}\n" // first copy the registers onto the stack
                "push {r12}\n"
                "mov r0, r12\n"
                "bl _interesting_call_preflight_check\n"
                "mov r0, #32\n"     // allocate 5 * 4 bytes + 4 bytes, enough to hold 5 registers plus 2x 4-byte address 
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
                "bl _print_args_stret\n"
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
                "ldr r12, (LSOrig1)\n"
"LoadSOrig1:"   "ldr r12, [pc, r12]\n"
                "blx r12\n"

                "push {r0-r11}\n"           // save a copy of the return value and other regs onto the stack
                "push {r0}\n"               // save another copy of return value
                "bl _loadBuffer\n"          // get the address of the thread-specific buffer
                "pop {r1}\n"                // get the return value from objc_msgSend                
                "mov r12, r0\n"
                "add r12, #20\n"
                "ldmia r12, {r0}\n"
                "bl _show_retval\n"         // add the return value to the JSON buffer:
                                            // _show_retval(threadSpecificBuffer, returnValue)
                                            // returns the address of the thread-specific buffer

                // fetch the malloc'd buffer, restore the regs from it, then free() it
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
                    
    "LSEna0:     .long _enabled_stret - 8 - (LoadSEna0)\n"
    "LSOrig0:    .long _original_objc_msgSend_stret - 8 - (LoadSOrig0)\n"
    "LSOrig1:    .long _original_objc_msgSend_stret - 8 - (LoadSOrig1)\n"
    "LSO2:       .long _original_objc_msgSend_stret - 8 - (LoadSO2)\n"
    );

} // namespace msgSend_stret
