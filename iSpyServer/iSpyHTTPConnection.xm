#import "CocoaHTTPServer/HTTPMessage.h"
#import "CocoaHTTPServer/HTTPResponse.h"
#import "CocoaHTTPServer/GCDAsyncSocket.h"
#import "../iSpy.common.h"
#import "iSpyHTTPConnection.h"
#import "iSpyWebSocket.h"


@implementation iSpyHTTPConnection



- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{

    HTTPResponse *resp = [super httpResponseForMethod:method URI:path];

    ispy_log_info(LOG_HTTP, "%s - %s", [method UTF8String], [path UTF8String]);

    return resp;
}

- (WebSocket *)webSocketForURI:(NSString *) path
{
    /* TODO: Validate origin */
    if([path isEqualToString:@"/jsonrpc"])
    {
        return [[iSpyWebSocket alloc] initWithRequest:request socket:asyncSocket];
    }
    return [super webSocketForURI:path];
}

@end
