//
//  NSBlock+TypedDescription.m
//  BlockTypeDescription
//
//  Created by Conrad Kramer on 3/17/13.
//  Copyright (c) 2013 Kramer Software Productions, LLC. All rights reserved.
//
 
#import "NSBlock+TypedDescription.h"
 
#import <objc/runtime.h>
 
static NSString * (*TDOriginalDescription)(id, SEL);
 
static NSString *TDFormattedStringForComplexType(const char *encoding) {
    NSString *type;
    if (*encoding == '(') {
        type = @"union";
    } else if (*encoding == '{') {
        type = @"struct";
    } else {
        return nil;
    }
 
    const char *namePtr = encoding + 1;
    unsigned length = 0;
    while (*namePtr && *namePtr != '=' && *namePtr != '}' && *namePtr != ')') {
        namePtr++;
        length++;
    }
    NSString *name = [[NSString alloc] initWithBytes:(encoding + 1) length:length encoding:NSUTF8StringEncoding];
 
    return [NSString stringWithFormat:@"%@%@%@", type, name.length ? @" " : @"", name];
}
 
static NSString *TDFormattedStringForType(const char *encoding) {
    char type = *encoding;
 
    switch (type) {
        case 'c': return @"char";
        case 'i': return @"int";
        case 's': return @"short";
        case 'l': return @"long";
        case 'q': return @"long long";
        case 'C': return @"unsigned char";
        case 'I': return @"unsigned int";
        case 'S': return @"unsigned short";
        case 'L': return @"unsigned long";
        case 'Q': return @"unsigned long long";
        case 'f': return @"float";
        case 'd': return @"double";
        case 'D': return @"long double";
        case 'B': return @"_Bool"; // C99 _Bool or C++ bool
        case 'v': return @"void";
        case '*': return @"STR";
        case '#': return @"Class";
        case ':': return @"SEL";
        case '%': return @"NXAtom";
        case '?': return @"void";
        case 'j': return @"_Complex";
        case 'r': return @"const";
        case 'n': return @"in";
        case 'N': return @"inout";
        case 'o': return @"out";
        case 'O': return @"bycopy";
        case 'R': return @"byref";
        case 'V': return @"oneway";
        case '@': return @"id";
        case '^': return [NSString stringWithFormat:@"%@*", TDFormattedStringForType(encoding + 1)];
        case '[': {
            char *type;
            long size = strtol(encoding + 1, &type, 10);
            return [NSString stringWithFormat:@"%@[%li]", TDFormattedStringForType(type), size];
        }
        case '(':
        case '{':
            return TDFormattedStringForComplexType(encoding);
        default:
            break;
    }
 
    return @"";
}
 
NSString *TDFormattedStringForBlockSignature(id block) {
    struct TD_Block_literal_1 *blockRef = (__bridge struct TD_Block_literal_1 *)block;
    int flags = blockRef->flags;
 
    if ((flags & TD_BLOCK_HAS_SIGNATURE) == 0) return nil;
 
    struct TD_Block_descriptor_1 *descriptor = blockRef->descriptor;
 
    void *signaturePtr = descriptor;
    signaturePtr += sizeof(descriptor->reserved);
    signaturePtr += sizeof(descriptor->size);
 
    if (flags & TD_BLOCK_HAS_COPY_DISPOSE) {
        signaturePtr += sizeof(descriptor->copy_helper);
        signaturePtr += sizeof(descriptor->dispose_helper);
    }
 
    const char *signature = *(const char **)signaturePtr;
    NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:signature];
 
    // Purposefully ignore first argument, it is a reference to the block itself
    NSMutableArray *arguments = [NSMutableArray array];
    for (int i=1; i < methodSignature.numberOfArguments; i++) {
        NSString *type = TDFormattedStringForType([methodSignature getArgumentTypeAtIndex:i]);
        [arguments addObject:type];
    }
 
    NSString *returnType = TDFormattedStringForType(methodSignature.methodReturnType);
    return [NSString stringWithFormat:@"(%@ (^)(%@))", returnType, [arguments componentsJoinedByString:@", "]];
}
 
static NSString * TDReplacedDescription(id self, SEL _cmd) {
    NSString *blockType = TDFormattedStringForBlockSignature(self);
 
    if (blockType) {
        return [NSString stringWithFormat:@"<%@: %@>", NSStringFromClass([self class]), blockType];
    } else {
        return TDOriginalDescription(self, _cmd);
    }
}
 
static __attribute__((constructor)) void constructor() {
    Method descriptionMethod = class_getInstanceMethod(NSClassFromString(@"NSBlock"), @selector(description));
    TDOriginalDescription = (NSString * (*)(id, SEL))method_setImplementation(descriptionMethod, (IMP)&TDReplacedDescription);
}
