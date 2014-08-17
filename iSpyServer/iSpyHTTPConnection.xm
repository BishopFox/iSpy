#import "iSpyHTTPConnection.h"

@implementation iSpyHTTPConnection

/*
 * This is almost identical to the parent objects impl but we use an
 * iSpyStaticFileResponse object instead of an HTTPFileResponse object.
 */
- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
    ispy_log_info(LOG_HTTP, "%s - %s", [method UTF8String], [path UTF8String]);
//     return [super httpResponseForMethod:method URI:path];

    NSString *filePath = [self filePathForURI:path allowDirectory:NO];
    BOOL isDir = NO;

    if (filePath && [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDir] && !isDir)
    {
        return [[iSpyStaticFileResponse alloc] initWithFilePath:filePath forConnection:self];
    }
    return nil;
}

- (WebSocket *)webSocketForURI:(NSString *) path
{
    /* TODO: Validate origin */
//    NSString *origin = [request headerField:@"Origin"];

    if ([path isEqualToString:@"/jsonrpc"]) {
        return [[iSpyWebSocket alloc] initWithRequest:request socket:asyncSocket];
    }

    if ([path isEqualToString:@"/shell"]) {
        return [[iSpyWebSocket alloc] initWithRequest:request socket:asyncSocket];
    }

    return nil;
}

@end
