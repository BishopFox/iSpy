/*
 * We add a instance method to send a message to all
 * open websocket connections
 */

#import <Foundation/Foundation.h>
#import "CocoaHTTPServer/HTTPServer.h"


@interface iSpyHTTPServer : HTTPServer
{

}

-(void) webSocketBroadcast: (NSString *) msg;

@end
