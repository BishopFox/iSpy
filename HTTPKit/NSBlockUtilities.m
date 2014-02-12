#import "NSBlockUtilities.h"
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <objc/runtime.h>
#import <string.h>

struct _BlockLiteral {
    void *isa;
    int flags;
    int reserved;
    id (*invoke)(id, ...);
    void *descriptor;
};

id CallBlockWithArguments(id aBlock, NSArray *aArguments)
{
    if(!aBlock)
        return nil;

    // We also want to work with NSPointerArray which doesn't implement -getObjects:
    unsigned long count = [aArguments count];
    __unsafe_unretained id args[count];
    memset(args, 0, count*sizeof(id));

    NSUInteger c;
    unsigned int i = 0;
    id stackBuf[16];
    NSFastEnumerationState enumState = {0};
    while((c = [aArguments countByEnumeratingWithState:&enumState
                                               objects:stackBuf
                                                 count:16]) != 0) {
        memcpy(args+ i*sizeof(id), enumState.itemsPtr, c*sizeof(id));
        i += c;
    }

    switch(count) {
        case 0:
            return ((id (^)())aBlock)();
        case 1:
            return ((id (^)(id arg))aBlock)(args[0]);
        case 2:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1]);
        case 3:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2]);
        case 4:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3]);
        case 5:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4]);
        case 6:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5]);
        case 7:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6]);
        case 8:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]);
        case 9:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]);
        case 10:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9]);
        case 11:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10]);
        case 12:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11]);
        case 13:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12]);
        case 14:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13]);
        case 15:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14]);
        case 16:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14], args[15]);
        case 17:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14], args[15], args[16]);
        case 18:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14], args[15], args[16], args[17]);
        case 19:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14], args[15], args[16], args[17], args[18]);
        case 20:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14], args[15], args[16], args[17], args[18], args[19]);
        case 21:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14], args[15], args[16], args[17], args[18], args[19], args[20]);
        case 22:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14], args[15], args[16], args[17], args[18], args[19], args[20], args[21]);
        case 23:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14], args[15], args[16], args[17], args[18], args[19], args[20], args[21], args[22]);
        case 24:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14], args[15], args[16], args[17], args[18], args[19], args[20], args[21], args[22], args[23]);
        case 25:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14], args[15], args[16], args[17], args[18], args[19], args[20], args[21], args[22], args[23], args[24]);
        case 26:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14], args[15], args[16], args[17], args[18], args[19], args[20], args[21], args[22], args[23], args[24], args[25]);
        case 27:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14], args[15], args[16], args[17], args[18], args[19], args[20], args[21], args[22], args[23], args[24], args[25], args[26]);
        case 28:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14], args[15], args[16], args[17], args[18], args[19], args[20], args[21], args[22], args[23], args[24], args[25], args[26], args[27]);
        case 29:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14], args[15], args[16], args[17], args[18], args[19], args[20], args[21], args[22], args[23], args[24], args[25], args[26], args[27], args[28]);
        case 30:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14], args[15], args[16], args[17], args[18], args[19], args[20], args[21], args[22], args[23], args[24], args[25], args[26], args[27], args[28], args[29]);
        case 31:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14], args[15], args[16], args[17], args[18], args[19], args[20], args[21], args[22], args[23], args[24], args[25], args[26], args[27], args[28], args[29], args[30]);
        case 32:
            return ((id (^)(id arg, ...))aBlock)(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14], args[15], args[16], args[17], args[18], args[19], args[20], args[21], args[22], args[23], args[24], args[25], args[26], args[27], args[28], args[29], args[30], args[31]);
        default:
            return nil;
    }
}
