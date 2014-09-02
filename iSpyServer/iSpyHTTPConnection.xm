#import <Foundation/Foundation.h>

#import "CocoaHTTPServer/HTTPConnection.h"
#import "CocoaHTTPServer/HTTPDataResponse.h"
#import "iSpyStaticFileResponse.h"
#import "iSpyWebSocket.h"
#import "../iSpy.common.h"
#import "../iSpy.class.h"
#import "iSpyHTTPConnection.h"


@implementation iSpyHTTPConnection

- (BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path
{
    // Add support for POST
    if ([method isEqualToString:@"POST"])
    {
        if ([path isEqualToString:@"/rpc"])
        {
            return true;
        }
    }
    return [super supportsMethod:method atPath:path];
}

- (BOOL)expectsRequestBodyFromMethod:(NSString *)method atPath:(NSString *)path
{
    if([method isEqualToString:@"POST"])
       return YES;
    return [super expectsRequestBodyFromMethod:method atPath:path];
}

// REQUIRED in order to process POST requests
- (void)processBodyData:(NSData *)postDataChunk
{
    [request appendData:postDataChunk];
}

/*
 * This is almost identical to the parent objects impl but we use an
 * iSpyStaticFileResponse object instead of an HTTPFileResponse object.
 */
- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
    // Handle JSON RPC requests via HTTP POST
    if([path isEqualToString:@"/rpc"] && [method isEqualToString:@"POST"]) {
        // Convert the POST request body into an NSString
        NSString *body = [[NSString alloc] initWithData:[request body] encoding:NSUTF8StringEncoding];
        
        // Dispatch the RPC request
        NSDictionary *responseDict = [[[iSpy sharedInstance] webServer] dispatchRPCRequest:body];
        
        // Convert the response to NSData
        NSData *responseData = [NSJSONSerialization dataWithJSONObject:responseDict options:0 error:nil];

        // Return the result to the caller as a JSON blob
        return [[HTTPDataResponse alloc] initWithData:responseData];
    }

    // Static content
    NSString *filePath = [self filePathForURI:path allowDirectory:NO];
    BOOL isDir = NO;
    if (filePath && [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDir] && !isDir)
    {
        return [[iSpyStaticFileResponse alloc] initWithFilePath:filePath forConnection:self];
    }

    // 404
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
