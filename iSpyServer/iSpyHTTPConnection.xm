#import "CocoaHTTPServer/HTTPMessage.h"
#import "CocoaHTTPServer/HTTPResponse.h"
#import "CocoaHTTPServer/GCDAsyncSocket.h"
#import "iSpyHTTPConnection.h"
#import "iSpyWebSocket.h"


@implementation iSpyHTTPConnection

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
    NSLog(@"[iSpy] iSpyHTTPConnection - method: %@ path: %@", method, path);
    return [super httpResponseForMethod:method URI:path];
}

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
