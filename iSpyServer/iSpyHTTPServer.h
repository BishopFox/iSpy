/*
 *
 */

#import <Foundation/Foundation.h>

#import "CocoaHTTPServer/HTTPServer.h"


@interface iSpyHTTPServer : HTTPServer
{

}

-(void) webSocketSendAll: (NSString *) msg;

@end
