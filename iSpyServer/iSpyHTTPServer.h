/*
 * We add a instance method to send a message to all
 * open websocket connections
 */

#import <Foundation/Foundation.h>
#import "CocoaHTTPServer/HTTPServer.h"


@interface iSpyHTTPServer : HTTPServer
{
    id server;
}

@property(nonatomic) id server;

-(void) webSocketBroadcast: (NSString *) msg;

@end
