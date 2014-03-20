//
//  NSBlock+TypedDescription.h
//  BlockTypeDescription
//
//  Created by Conrad Kramer on 3/17/13.
//  Copyright (c) 2013 Kramer Software Productions, LLC. All rights reserved.
//
 
// Taken directly from http://clang.llvm.org/docs/Block-ABI-Apple.html#high-level, and prefixed with 'TD'
 
struct TD_Block_literal_1 {
    void *isa; // initialized to &_NSConcreteStackBlock or &_NSConcreteGlobalBlock
    int flags;
    int reserved;
    void (*invoke)(void *, ...);
    struct TD_Block_descriptor_1 {
        unsigned long int reserved;         // NULL
        unsigned long int size;         // sizeof(struct TD_Block_literal_1)
        // optional helper functions
        void (*copy_helper)(void *dst, void *src);     // IFF (1<<25)
        void (*dispose_helper)(void *src);             // IFF (1<<25)
        // required ABI.2010.3.16
        const char *signature;                         // IFF (1<<30)
    } *descriptor;
    // imported variables
};
 
enum {
    TD_BLOCK_HAS_COPY_DISPOSE =  (1 << 25),
    TD_BLOCK_HAS_CTOR =          (1 << 26), // helpers have C++ code
    TD_BLOCK_IS_GLOBAL =         (1 << 28),
    TD_BLOCK_HAS_STRET =         (1 << 29), // IFF TD_BLOCK_HAS_SIGNATURE
    TD_BLOCK_HAS_SIGNATURE =     (1 << 30),
};
 
extern NSString *TDFormattedStringForBlockSignature(id block);
