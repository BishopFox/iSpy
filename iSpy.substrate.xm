/*
 iSpy - Bishop Fox iOS hooking framework.

 This module replaces MobileSubstrate's MSMessageHookEx method-swizzling function with a
 cache-poisoning variant that goes undetected by some anti-swizzling protections.

 Once loaded, this variant will let you write normal Theos tweaks that work on protected
 binaries that perform anti-swizzling checks. ?

 You can enable this by editing Tweak.xm and setting the ENABLE_BF_SUBSTRATE_REPLACEMENT flag.
 After that you can simply add tweaks to Tweak.xm like normal.
 */
//#include "/usr/include/objc/objc-runtime.h"
#include <objc/objc.h>
#include "iSpy.common.h"
#include "substrate.h"

// Why are we not using the correct headers?
struct objc_method {
    SEL method_name;
    char *method_types;
    IMP method_imp;
};

// Maintain a linked list of hooked methods
struct poisonedCacheList {
    struct objc_method *orig_method;
    IMP new_imp;
    id cls;
    struct poisonedCacheList *next;
};

static void (*orig_MSHookMessageEx)(id, id cls, SEL selector, IMP replacement,
        IMP *result);
static IMP (*orig_method_getImplementation)(Method method);
static void bf_MSHookMessageEx(id cls, SEL selector, IMP replacement,
        IMP *result);
static IMP bf_method_getImplementation(Method method);

// This is our linked list of hooked methods.
static struct poisonedCacheList *hookList = NULL;

/*
 Replace the MobileSubstrate MSHookMessageEx function.

 This version chucks out the normal swizzling function and replaces it with one that
 uses the Metaforic cache poisoning exploit. Any method name passed to this function
 is added to a linked list, along with a pointer to the replacing function.

 After that it returns to the caller - job done: the linked list will now have another node.

 The real swizzle happens in method_getImplementation where the linked list is checked
 and handled accordingly.
 */
static void bf_MSHookMessageEx(id cls, SEL selector, IMP replacement,
        IMP *result) {
    struct poisonedCacheList *p;

    NSLog(@"[iSpy]: substrate: Someone is using MSHookMessageEx to hook [%s %s]. Using iSpy's hooker instead.", (char *)class_getName(cls), (char *)sel_getName(selector));
    p=hookList;
    if(p != NULL) {
        NSLog(@"[iSpy]: substrate: Adding new node for %s", (char *)sel_getName(selector));
        while(p->next)
            p=p->next;
        p->next=(struct poisonedCacheList *)malloc(sizeof(struct poisonedCacheList));
        p=p->next;
    } else {
        NSLog(@"[iSpy] substrate: Initializing hook list");
        p = (struct poisonedCacheList *) malloc(
                sizeof(struct poisonedCacheList));
        hookList = p;
    }
    p->next = NULL;
    p->orig_method = NULL;
    p->new_imp = replacement;

    // handle the differences between meta classes and class instances
    if (class_isMetaClass(cls)) {
        p->orig_method = (struct objc_method *) class_getClassMethod(cls, selector);
    } else {
        p->orig_method = (struct objc_method *) class_getInstanceMethod(cls, selector);
    }

    if (result && p->orig_method) {
        *result = p->orig_method->method_imp;
    } else {
        *result = replacement;
    }

    NSLog(@"[iSpy] substrate: Method @ %p // IMP @ %p", p->orig_method, *result);
}

/*
 This function replaces the standard method_getImplementation. It searches a linked list
 of methods that are to be swizzled; any hits are swizzled by returning a poisoned pointer.
 The original pointers are returned for non-swizzled methods.
 */
static IMP bf_method_getImplementation(Method method) {
    struct poisonedCacheList *p;
    IMP origFunc;

    origFunc=orig_method_getImplementation(method);
    p=hookList;
    while(p) {
        if(p->orig_method == method) {
            NSLog(@"[iSpy]: substrate: method_getImplementation: Found hooked method %s, replacing it with swizzled version!", (char *)sel_getName(method->method_name));
            return p->new_imp;
        }
        p = p->next;
    }
    return origFunc;
}

/*
 Call this from Tweak.xm to install the cache-poisoning variant of MSMessageHookEx()
 */
EXPORT void bf_init_substrate_replacement() {
    NSLog(@"[iSpy] substrate: replacing method_getImplementation and MSHookMessageEx...");
    hookList = NULL;
    MSHookFunction((void *) method_getImplementation,
            (void *) bf_method_getImplementation,
            (void **) &orig_method_getImplementation);
    MSHookFunction((void *) MSHookMessageEx, (void *) bf_MSHookMessageEx,
            (void **) &orig_MSHookMessageEx);
    NSLog(@"[iSpy] substrate: done.");
}


