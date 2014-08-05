#import "iSpyHTTPServer.h"

@implementation iSpyHTTPServer

-(void) webSocketSendAll: (NSString *) msg
{
    /* webSockets is a NSMutableArray so we need to lock */
    [webSocketsLock lock];
    for (unsigned int index = 0; index < [webSockets count]; ++index)
    {
        [[webSockets objectAtIndex:index] sendMessage: msg];
    }
    [webSocketsLock unlock];
}

@end
