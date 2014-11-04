#import "iSpyHTTPServer.h"
#import "iSpyWebSocket.h"

@implementation iSpyHTTPServer

- (id)init
{
    if ((self = [super init]))
    {
        ispySockets = [[NSMutableArray alloc] init];
        ispySocketLock  = [[NSLock alloc] init];
    }
    return self;
}

-(void) ispySocketBroadcast: (NSString *) msg
{

    /*
     * webSockets is a NSMutableArray so we need to lock but
     * the sockets are async so locking shouldn't be terrible
     */

    if (0 < [self numberOfSyncSocketConnections])
    {
        [ispySocketLock lock];
        for (iSpyWebSocket *ws in ispySockets)
        {
            [ws sendMessage: msg];
        }
        [ispySocketLock unlock];
    }
}

- (NSUInteger)numberOfSyncSocketConnections
{
    NSUInteger result = 0;
    [ispySocketLock lock];
    result = [ispySockets count];
    [ispySocketLock unlock];
    return result;
}

- (void)addWebSocket:(WebSocket *)ws
{
    [webSocketsLock lock];
    [webSockets addObject:ws];
    [webSocketsLock unlock];
    if ([ws isKindOfClass:[iSpyWebSocket class]])
    {
        [ispySocketLock lock];
        [ispySockets addObject:ws];
        [ispySocketLock unlock];
    }
}

- (void)webSocketDidDie:(NSNotification *)notification
{
    // Note: This method is called on the connection queue that posted the notification

    [webSocketsLock lock];
    [webSockets removeObject:[notification object]];
    [webSocketsLock unlock];

    if ([[notification object] isKindOfClass:[iSpyWebSocket class]])
    {
        [ispySocketLock lock];
        [ispySockets removeObject:[notification object]];
        [ispySocketLock unlock];
    }
}


@end
