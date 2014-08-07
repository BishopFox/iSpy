/*
 * iSpy - Bishop Fox iOS hacking/hooking/sandboxing framework.
 */

#include <stack>
#include <fcntl.h>
#include <stdio.h>
#include <dlfcn.h>
#include <stdarg.h>
#include <unistd.h>
#include <string.h>
#include <dirent.h>
#include <stdbool.h>
#include <pthread.h>
#include <sys/stat.h>
#include <sys/param.h>
#include <sys/mount.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/sysctl.h>
#include <sys/mman.h>
#include <sys/uio.h>
#include <objc/objc.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <mach-o/dyld.h>
#include <netinet/in.h>
#import  <Security/Security.h>
#import  <Security/SecCertificate.h>
#include <CFNetwork/CFNetwork.h>
#include <CFNetwork/CFProxySupport.h>
#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFStream.h>
#import  <Foundation/NSJSONSerialization.h>
#include <dlfcn.h>
#include <mach-o/nlist.h>
#include <semaphore.h>
#import <MobileCoreServices/MobileCoreServices.h>

#include "iSpy.common.h"
#include "iSpy.instance.h"
#include "iSpy.class.h"
#include "hooks_C_system_calls.h"
#include "hooks_CoreFoundation.h"

#import "iSpy.rpc.h"
#import "iSpyServer/CocoaHTTPServer/DDLog.h"
#import "iSpyServer/CocoaHTTPServer/DDTTYLogger.h"
#import "iSpyServer/iSpyHTTPServer.h"
#import "iSpyServer/iSpyHTTPConnection.h"


static const int DEFAULT_WEB_PORT = 31337;
static const char *WS_QUEUE = "com.bishopfox.iSpy.websocket";
static dispatch_queue_t wsQueue = dispatch_queue_create(WS_QUEUE, NULL);

@implementation iSpyServer

-(void)configureWebServer {

    [self setPlist:NULL];
    [self setPlist: [[NSMutableDictionary alloc] initWithContentsOfFile:@PREFERENCEFILE]];

    [self setHttpServer:NULL];
    NSLog(@"[iSpy] Alloc iSpyHTTPServer ..");
    // [DDLog addLogger:[DDTTYLogger sharedInstance]];
    iSpyHTTPServer *httpServer = [[iSpyHTTPServer alloc] init];
    [self setHttpServer: httpServer];

    // Tell server to use our custom MyHTTPConnection class.
    NSLog(@"[iSpy] Setting up iSpyHTTPConnection ..");
    [httpServer setConnectionClass:[iSpyHTTPConnection class]];

    // Tell the server to broadcast its presence via Bonjour.
    // This allows browsers such as Safari to automatically discover our service.
    //[httpServer setType:@"_http._tcp."];

    // Normally there's no need to run our server on any specific port.
    // Technologies like Bonjour allow clients to dynamically discover the server's port at runtime.
    // However, for easy testing you may want force a certain port so you can just hit the refresh button.
    int lport = [self getListenPortFor:@"settings_webServerPort" fallbackTo:DEFAULT_WEB_PORT];
    [httpServer setPort: lport];
    NSLog(@"[iSpy] iSpyHTTPServer configured to listen on port %d", lport);

    // Serve files from our embedded Web folder
    [httpServer setDocumentRoot: @"/var/www/iSpy/"];

    // Start the server (and check for problems)
    NSError *error;
    if( ! [httpServer start:&error])
    {
        NSString *errorMessage = [NSString stringWithFormat:@"%@", error];
        NSLog(@"[iSpy] Error starting HTTP Server: %@", errorMessage);
    }
    NSLog(@"[iSpy] HTTP server started successfully");
}

-(id)init {
    [super init];
    [self configureWebServer];
    return self;
}

-(void)bounceWebServer {
    ispy_log_debug(LOG_HTTP, "bounceWebServer...");
}

-(int) getListenPortFor:(NSString *) key
       fallbackTo:(int) fallback
{
    int lport = [[self.plist objectForKey:key] intValue];
    if (lport <= 0 || 65535 <= lport) {
        NSLog(@"[iSpy] Invalid listen port (%d); fallback to %d", lport, fallback);
        lport = fallback;
    }
    if (lport <= 1024) {
        NSLog(@"[iSpy] %d is a priviledged port, this is most likely not going to work!", lport);
    }
    return lport;
}

// Pass this an NSString containing a JSON-RPC request.
// It will do sanity/security checks, then dispatch the method, then return an NSDictionary as a return value.
-(NSDictionary *)dispatchRPCRequest:(NSString *) JSONString {
    NSData *RPCRequest = [JSONString dataUsingEncoding:NSUTF8StringEncoding];
    if ( ! RPCRequest) {
        ispy_log_error(LOG_HTTP, "Could not convert websocket payload into NSData");
        return nil;
    }

    // create a dictionary from the JSON request
    NSDictionary *RPCDictionary = [NSJSONSerialization JSONObjectWithData:RPCRequest options:kNilOptions error:nil];
    if ( ! RPCDictionary) {
        ispy_log_error(LOG_HTTP, "invalid RPC request, couldn't deserialze the JSON data.");
        return nil;
    }

    // is this a valid request? (does it contain both "messageType" and "messageData" entries?)
    if ( ! [RPCDictionary objectForKey:@"messageType"] || ! [RPCDictionary objectForKey:@"messageData"]) {
        ispy_log_error(LOG_HTTP, "Invalid request. Must have messageType and messageData.");
        return nil;
    }

    // Verify that the iSpy RPC handler class can execute the requested selector
    NSString *selectorString = [RPCDictionary objectForKey:@"messageType"];
    SEL selectorName = sel_registerName([[NSString stringWithFormat:@"%@:", selectorString] UTF8String]);
    if ( ! selectorName) {
        ispy_log_error(LOG_HTTP, "selectorName was null.");
        return nil;
    }
    if ( ! [[self rpcHandler] respondsToSelector:selectorName] ) {
        ispy_log_error(LOG_HTTP, "doesn't respond to selector");
        return nil;
    }

    // Do it!
    ispy_log_debug(LOG_HTTP, "Dispatching request for: %s", [selectorString UTF8String]);
    NSMutableDictionary *responseDict = [[self rpcHandler] performSelector:selectorName withObject:[RPCDictionary objectForKey:@"messageData"]];
    return responseDict;
}

@end

// This is the equivalent of [iSpyWebSocket sendMessage:@"Wakka wakka"] except that it's
// pure C all the way down, so it's safe to call it inside the msgSend logging routines.
// NOT thread safe. Handle locking yourself.
// Requires C linkage for the msgSend stuff.
extern "C" {
    void bf_websocket_write(const char *msg) {
        NSString *json = orig_objc_msgSend(objc_getClass("NSString"), @selector(stringWithFormat:), @"%s", msg);
        dispatch_async(wsQueue, ^{
            iSpyHTTPServer *httpServer = [[[iSpy sharedInstance] webServer] httpServer];
            [httpServer webSocketBroadcast: json];
        });
    }
}

