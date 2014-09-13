#import <Foundation/Foundation.h>

#import "CocoaHTTPServer/HTTPConnection.h"
#import "CocoaHTTPServer/HTTPMessage.h"
#import "iSpyStaticFileResponse.h"
#import "iSpyWebSocket.h"
#import "../iSpy.common.h"

@class iSpyWebSocket;

@interface iSpyHTTPConnection : HTTPConnection
{
    iSpyWebSocket *ws;
}

- (NSString *) getIPAddress;

@end
