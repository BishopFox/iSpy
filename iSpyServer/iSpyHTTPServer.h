/*
 * We add a instance method to send a message to all
 * open websocket connections
 */

#import <Foundation/Foundation.h>
#import "CocoaHTTPServer/HTTPServer.h"


@interface iSpyHTTPServer : HTTPServer
{
    NSMutableArray *ispySockets;
    NSLock *ispySocketLock;
}

-(void) ispySocketBroadcast: (NSString *) msg;

@end
