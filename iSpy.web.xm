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


static const int MAX_ATTEMPTS = 5;
static const int DEFAULT_WEB_PORT = 31337;
static const char *WS_QUEUE = "com.bishopfox.iSpy.websocket";
static dispatch_queue_t wsQueue = dispatch_queue_create(WS_QUEUE, NULL);




@implementation iSpyServer

-(void)configureWebServer {

    int attempts = 0;
    BOOL successful = NO;
    int settingsPort = [self getListenPortFor:@"settings_webServerPort" fallbackTo:DEFAULT_WEB_PORT];
    int lport = settingsPort;

    do
    {
        [self setPlist:NULL];
        [self setPlist: [[NSMutableDictionary alloc] initWithContentsOfFile:@PREFERENCEFILE]];

        [self setHttpServer:NULL];
        NSLog(@"[iSpy] Start iSpyHTTPServer, attempt #%d ...", attempts + 1);

        iSpyHTTPServer *httpServer = [[iSpyHTTPServer alloc] init];
        [self setHttpServer: httpServer];

        // Tell server to use our custom MyHTTPConnection class.
        [httpServer setConnectionClass:[iSpyHTTPConnection class]];
        [httpServer setPort: lport];
        NSLog(@"[iSpy] iSpyHTTPServer attempting to listen on port %d", lport);

        // Serve files from our embedded Web folder
        [httpServer setDocumentRoot: @"/var/www/iSpy/"];

        NSError *error;
        if ([httpServer start:&error])
        {
            successful = YES;
        }
        else
        {
            NSString *errorMessage = [NSString stringWithFormat:@"%@", error];
            NSLog(@"[iSpy] Error starting HTTP Server: %@", errorMessage);
            ++lport;
            ++attempts;
        }


    } while ( ! successful && attempts < MAX_ATTEMPTS);

    if (successful)
    {
        NSLog(@"[iSpy] HTTP server started successfully on port %d", lport);
    }
    else
    {
        NSLog(@"[iSpy] Failed to start web server, max attempts");
    }

}

-(id)init {
    [super init];
    return self;
}

-(void)bounceWebServer {
    ispy_log_debug(LOG_HTTP, "bounceWebServer...");
}

-(int) getListenPortFor:(NSString *) key
       fallbackTo:(int) fallback
{
    int lport = [[self.plist objectForKey:key] intValue];
    if (lport <= 0 || 65535 <= lport)
    {
        NSLog(@"[iSpy] Invalid listen port (%d); fallback to %d", lport, fallback);
        lport = fallback;
    }
    if (lport <= 1024)
    {
        NSLog(@"[iSpy] %d is a priviledged port, this is most likely not going to work!", lport);
    }
    return lport;
}

-(NSDictionary *)dispatchRPCRequest:(NSString *) JSONString {
    NSData *RPCRequest = [JSONString dataUsingEncoding:NSUTF8StringEncoding];
    if ( ! RPCRequest)
    {
        ispy_log_error(LOG_HTTP, "Could not convert websocket payload into NSData");
        return nil;
    }

    // create a dictionary from the JSON request
    NSDictionary *RPCDictionary = [NSJSONSerialization JSONObjectWithData:RPCRequest options:kNilOptions error:nil];
    if ( ! RPCDictionary)
    {
        ispy_log_error(LOG_HTTP, "invalid RPC request, couldn't deserialze the JSON data.");
        return nil;
    }

    // is this a valid request? (does it contain both "messageType" and "messageData" entries?)
    if ( ! [RPCDictionary objectForKey:@"messageType"] || ! [RPCDictionary objectForKey:@"messageData"])
    {
        ispy_log_error(LOG_HTTP, "Invalid RPC request; must have messageType and messageData.");
        return nil;
    }

    // Verify that the iSpy RPC handler class can execute the requested selector
    NSString *selectorString = [RPCDictionary objectForKey:@"messageType"];
    SEL selectorName = sel_registerName([[NSString stringWithFormat:@"%@:", selectorString] UTF8String]);
    if ( ! selectorName)
    {
        ispy_log_error(LOG_HTTP, "selectorName was null.");
        return nil;
    }
    if ( ! [[self rpcHandler] respondsToSelector:selectorName] )
    {
        ispy_log_error(LOG_HTTP, "doesn't respond to selector");
        return nil;
    }

    // Do it!
    ispy_log_debug(LOG_HTTP, "Dispatching request for: %s", [selectorString UTF8String]);
    NSDictionary *responseDict = [[self rpcHandler] performSelector:selectorName withObject:[RPCDictionary objectForKey:@"messageData"]];
    NSMutableDictionary *mutableResponse = [responseDict mutableCopy];
    [mutableResponse setObject:selectorString forKey:@"messageType"];
    ispy_log_debug(LOG_HTTP, "Created valid response for %s", [selectorString UTF8String]);
    return mutableResponse;
}

@end

// This is the equivalent of [iSpyWebSocket sendMessage:@"Wakka wakka"] except that it's
// pure C all the way down, so it's safe to call it inside the msgSend logging routines.
// NOT thread safe. Handle locking yourself.
// Requires C linkage for the msgSend stuff.
extern "C" {
    void bf_websocket_write(const char *msg) {
        static iSpyWebSocket *syncSocket = [[[iSpy sharedInstance] webServer] iSpyWebSocket]; // static for speed/cache
        NSString *json = orig_objc_msgSend(objc_getClass("NSString"), @selector(stringWithUTF8String:), msg);

        // this async and almost immediately returns
        ispy_log_info(LOG_MSGSEND, msg);

        // be async
        dispatch_async(wsQueue, ^{
            orig_objc_msgSend(syncSocket, @selector(sendMessage:), json);
        });
    }
}

