#include <ifaddrs.h>
#include <arpa/inet.h>
#import <Foundation/Foundation.h>

#import "CocoaHTTPServer/HTTPConnection.h"
#import "CocoaHTTPServer/HTTPDataResponse.h"
#import "iSpyStaticFileResponse.h"
#import "iSpyWebSocket.h"
#import "ShellWebSocket.h"
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
    if([path isEqualToString:@"/rpc"] && [method isEqualToString:@"POST"])
    {
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
    /* Check to see if the request came from a valid origin */
    BOOL validOrigin = YES;
    NSMutableDictionary *plist = [[NSMutableDictionary alloc] initWithContentsOfFile:@PREFERENCEFILE];
    if ( ! [[plist objectForKey:@"settings_ignoreRpcOrigin"] boolValue])
    {

        validOrigin = NO;

        NSString *origin = [request headerField:@"Origin"];
        if (origin != nil)
        {
            NSURL *url = [NSURL URLWithString:origin];
            NSString *localIp = [self getIPAddress];
            ispy_log_debug(LOG_HTTP, "Got a request from origin %s", [[url host] UTF8String]);
            ispy_log_debug(LOG_HTTP, "My local ip address is: %s", [localIp UTF8String]);
            if ([[url host] caseInsensitiveCompare:@"localhost"] == NSOrderedSame || [[url host] isEqualToString:@"127.0.0.1"]
                                                                                  || [[url host] isEqualToString:@"::1"])
            {
                ispy_log_debug(LOG_HTTP, "Request origin matches localhost");
                validOrigin = YES;
            }
            else if ([[url host] isEqualToString:localIp])
            {
                ispy_log_debug(LOG_HTTP, "Request origin matches local ip: %s", [localIp UTF8String]);
                validOrigin = YES;
            }
        }
        else
        {
            ispy_log_debug(LOG_HTTP, "Request did not contain an origin header");
            validOrigin = YES;  // If there is no Origin header the request did not come from a browser
        }

    }

    if (validOrigin)
    {

        id webSocketHandler;

        if ([path isEqualToString:@"/jsonrpc"])
        {
            ispy_log_debug(LOG_HTTP, "WebSocket setup for /jsonrpc");
            webSocketHandler = [[iSpyWebSocket alloc] initWithRequest:request socket:asyncSocket];
            [[[iSpy sharedInstance] webServer] setISpyWebSocket:webSocketHandler];
            return webSocketHandler;
        }

        if ([path isEqualToString:@"/shell"])
        {
            ispy_log_debug(LOG_HTTP, "WebSocket setup for /shell");
            webSocketHandler = [[ShellWebSocket alloc] initWithRequest:request socket:asyncSocket];
            [webSocketHandler setCmdLine:@"/bin/bash -l"];
            return webSocketHandler;
        }

        if ([path isEqualToString:@"/cycript"])
        {
            ispy_log_debug(LOG_HTTP, "WebSocket setup for /cycript");
            webSocketHandler = [[ShellWebSocket alloc] initWithRequest:request socket:asyncSocket];
            NSString *cmd = [NSString stringWithFormat:@"/usr/bin/cycript -p %d", getpid()];
            [webSocketHandler setCmdLine:[cmd copy]];
            return webSocketHandler;
        }
    }
    return nil;
}

- (NSString *)getIPAddress
{

    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0)
    {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL)
        {
            if(temp_addr->ifa_addr->sa_family == AF_INET)
            {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"])
                {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    return address;

}

@end
