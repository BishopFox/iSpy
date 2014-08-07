#import "iSpyHTTPServer.h"
#import "iSpyWebSocket.h"

@implementation iSpyHTTPServer

-(void) webSocketBroadcast: (NSString *) msg
{
    /*
     * webSockets is a NSMutableArray so we need to lock but
     * the sockets are async so locking shouldn't be terrible
     */
    if (0 < [self numberOfWebSocketConnections]) {
        NSUInteger count = 0;
        [webSocketsLock lock];
        for (iSpyWebSocket *ws in webSockets)
        {
            ispy_log_debug(LOG_HTTP, "[webSocketBroadcast] #%d <- %s", count, [msg UTF8String]);
            [ws sendMessage: msg];
            ++count;
        }
        [webSocketsLock unlock];
    } else {
        ispy_log_debug(LOG_HTTP, "[webSocketBroadcast] no open sockets, skipping broadcast");
    }
}

@end
