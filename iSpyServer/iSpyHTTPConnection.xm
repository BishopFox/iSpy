#import "CocoaHTTPServer/HTTPMessage.h"
#import "CocoaHTTPServer/HTTPResponse.h"
#import "CocoaHTTPServer/GCDAsyncSocket.h"
#import "iSpyHTTPConnection.h"
#import "iSpyWebSocket.h"


// Log levels: off, error, warn, info, verbose
// Other flags: trace

@implementation iSpyHTTPConnection

- (WebSocket *)webSocketForURI:(NSString *) path
{
    /* TODO: Validate origin */
    if([path isEqualToString:@"/connect"])
    {
        return [[iSpyWebSocket alloc] initWithRequest:request socket:asyncSocket];
    }
    return [super webSocketForURI:path];
}

@end
