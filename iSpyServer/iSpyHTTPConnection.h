#import <Foundation/Foundation.h>

#import "CocoaHTTPServer/HTTPConnection.h"

@class iSpyWebSocket;

@interface iSpyHTTPConnection : HTTPConnection
{
    iSpyWebSocket *ws;
}

@end
