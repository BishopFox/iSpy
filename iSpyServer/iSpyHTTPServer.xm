#import "iSpyHTTPServer.h"
#import "iSpyWebSocket.h"

@implementation iSpyHTTPServer

-(void) webSocketBroadcast: (NSString *) msg {
    /*
     * webSockets is a NSMutableArray so we need to lock but
     * the sockets are async so locking shouldn't be terrible
     */
    if (0 < [self numberOfWebSocketConnections]) {
        [webSocketsLock lock];
        for (iSpyWebSocket *ws in webSockets) {
            [ws sendMessage: msg];
        }
        [webSocketsLock unlock];
    }
}

@end
