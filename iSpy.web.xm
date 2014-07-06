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
#include "iSpy.common.h"
#include "iSpy.instance.h"
#include "iSpy.class.h"
#include "hooks_C_system_calls.h"
#include "hooks_CoreFoundation.h"
#import "HTTPKit/HTTP.h"
#import "HTTPKit/mongoose.h" 
#import  "GRMustache/include/GRMustache.h"
#include <dlfcn.h>
#include <mach-o/nlist.h>
#include <semaphore.h>
#import <MobileCoreServices/MobileCoreServices.h>

/* Underscore.js requires the use of eval :( */
static NSString *CSP = @"default-src 'self'; script-src 'self' 'unsafe-eval'";
static NSDictionary *STATIC_CONTENT = @{
    @"js": @"text/javascript",
    @"css": @"text/css",
    @"png": @"image/png",
    @"jpg": @"image/jpeg",
    @"jpeg": @"image/jpeg",
    @"ico": @"image/ico",
    @"gif": @"image/gif",
    @"svg": @"image/svg+xml",
    @"tff": @"application/x-font-ttf",
    @"eot": @"application/vnd.ms-fontobject",
    @"woff": @"application/x-font-woff",
    @"otf": @"application/x-font-otf",
};

NSString *templatesPath = @"/var/www/iSpy/templates";   // Path to the Mustache HTML templates
GRMustacheTemplateRepository *templatesRepo;                // Template repository class
static struct mg_connection *globalMsgSendWebSocketPtr = NULL; // mg_connection is (was) a private struct in HTTPKit

@implementation iSpyServer

-(void)configureWebServer {
    [self setHttp:NULL];
    [self setWsGeneral:NULL];
    [self setWsStrace:NULL];
    [self setWsMsgSend:NULL];
    [self setWsInstance:NULL];
    [self setWsISpy:NULL];
    
    [self setHttp:[[HTTP alloc] init]];
    [self setWsISpy:[[HTTP alloc] init]];
    
    [[self http] setEnableDirListing:NO];
    [[self http] setPublicDir:@"/var/www/iSpy"];

    [[self wsISpy] setEnableKeepAlive:YES];
}

-(id)init {
    [super init];
    [self configureWebServer];
    
    return self;
} 

-(void)bounceWebServer {
    ispy_log_debug(LOG_GENERAL, "Stopping mongoose...");
    mg_stop([[self http] __ctx]);
    sleep(2);
    ispy_log_debug(LOG_GENERAL, "Starting webserver...");
    [self startWebServices];
    ispy_log_debug(LOG_GENERAL, "Done.");
}

-(BOOL) startWebServices {
    // Initialize the iSpy web service
    iSpy *mySpy = [iSpy sharedInstance];
    BOOL ret;
    
    ret = [[self http] listenOnPort:WEBSERVER_PORT onError:^(id reason) {
        ispy_log_wtf(LOG_GENERAL, "[iSpy] Error starting server: %s", [reason UTF8String]);
    }];
    if(!ret) {
        return ret;
    }

    /* This is the only page that is sent */
    [[self http] handleGET:@"/"
        with:^(HTTPConnection *connection) {
            NSString *pathToIndex = [NSString stringWithFormat:@"%@/pages/index.html", [[self http] publicDir]];
            NSData *data = [NSData dataWithContentsOfFile:pathToIndex];
            ispy_log_info(LOG_HTTP, "[GET] Page -> %s", [pathToIndex UTF8String]);

            /*
                Since iSpy is basically remote code execution as a feature, it seems
                prudent to add as many security headers as possible.
            */
            [connection setResponseHeader:@"X-XSS-Protection" to:@"1; mode=block"];
            [connection setResponseHeader:@"X-Frame-Options" to:@"DENY"];
            [connection setResponseHeader:@"X-Content-Type-Options" to:@"nosniff"];
            [connection setResponseHeader:@"Content-Security-Policy" to:CSP];
            [connection setResponseHeader:@"Content-Type" to:@"text/html"];
            [connection setResponseHeader:@"Content-Length" to:[NSString stringWithFormat:@"%d", [data length]]];
            [connection writeData:data];
            return nil;
    }];

    /*
     * Handler for all static content: CSS, JavaScript, images, etc (but notably not HTML)
     */
    [[self http] handleGET:@"/static/*/*"
        with:^(HTTPConnection *connection, NSString *folder, NSString *fname) {
            [connection setResponseHeader:@"X-XSS-Protection" to:@"1; mode=block"];
            [connection setResponseHeader:@"X-Frame-Options" to:@"DENY"];
            [connection setResponseHeader:@"X-Content-Type-Options" to:@"nosniff"];
            [connection setResponseHeader:@"Content-Security-Policy" to:CSP];

            NSString *contentType = [STATIC_CONTENT valueForKey:[fname pathExtension]];
            if(!contentType) {
                [connection setResponseHeader:@"Content-Type" to:"@x/unknown"];
                ispy_log_warning(LOG_HTTP, "Could not determine content-type of static resource: %s", [fname UTF8String]);
            } else {
                /* We only write the data if we know the content-type */
                NSString *pathToStaticFile = [NSString stringWithFormat:@"%@/static/%@/%@", [[self http] publicDir], folder, fname];
                NSData *data = [NSData dataWithContentsOfFile:pathToStaticFile];
                [connection setResponseHeader:@"Content-Type" to:contentType];
                [connection setResponseHeader:@"Content-Length" to:[NSString stringWithFormat:@"%d", [data length]]];
                [connection writeData:data];
            }
            return nil;
    }];

    [[self http] handleGET:@"/ping"
        with:^(HTTPConnection *connection) {
            return @"pong\n";
    }];

    [[self http] handleGET:@"/generalMonitor"
        with:^(HTTPConnection *connection) {
            return [self renderStaticTemplate:@"generalMonitor"];
    }];
    
    [[self http] handleGET:@"/straceMonitor"
        with:^(HTTPConnection *connection) {
            return [self renderStaticTemplate:@"straceMonitor"];
    }];

    [[self http] handleGET:@"/msgSendMonitor"
        with:^(HTTPConnection *connection) {
            return [self renderStaticTemplate:@"msgSendMonitor"];
    }];

    [[self http] handleGET:@"/info"
        with:^(HTTPConnection *connection) {
            return [self renderStaticTemplate:@"info"];
    }];

    [[self http] handleGET:@"/symbols"
        with:^(HTTPConnection *connection) {
            return [self renderStaticTemplate:@"symbols"];
    }]; 
    
    [[self http] handleGET:@"/keychain"
        with:^(HTTPConnection *connection) {
            return [self renderStaticTemplate:@"keychain"];
    }];
    
    [[self http] handleGET:@"/classdump"
        with:^(HTTPConnection *connection) {
            return [self renderStaticTemplate:@"classdump"];
    }];

    [[self http] handleGET:@"/instances"
        with:^(HTTPConnection *connection) {
            return [self renderStaticTemplate:@"instances"];
    }];

    // This is a GAPING SECURITY HOLE
    [[self http] handleGET:@"/download/**"
        with:^(HTTPConnection *connection, NSString *fname) {
            NSString *contentType;
            NSString *path = [NSString stringWithFormat:@"/%@", fname];
            
            if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
                return nil;
            }
            // Borrowed from http://stackoverflow.com/questions/5996797/determine-mime-type-of-nsdata-loaded-from-a-file
            // itself, derived from  http://stackoverflow.com/questions/2439020/wheres-the-iphone-mime-type-database
            CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)[path pathExtension], NULL);
            CFStringRef mimeType = UTTypeCopyPreferredTagWithClass (UTI, kUTTagClassMIMEType);
            CFRelease(UTI);
            if (!mimeType) {
                contentType = [NSMakeCollectable((NSString *)@"application/octet-stream") autorelease];
            } else {
                contentType = [NSMakeCollectable((NSString *)mimeType) autorelease];
            }

            NSData *data = [NSData dataWithContentsOfFile:path];
            [connection setResponseHeader:@"Content-Type" to:contentType];
            [connection writeData:data];
            return nil;
    }];

    [[self http] handleGET:@"/api/instance/*"
        with:^(HTTPConnection *connection, NSString *instanceAddr) {
            NSData *JSONData = [NSJSONSerialization dataWithJSONObject:[[iSpy sharedInstance] instance_dumpInstanceAtAddress:instanceAddr] options:0 error:NULL];
            [connection writeString:[[NSString alloc] initWithBytes:[JSONData bytes] length:[JSONData length] encoding: NSUTF8StringEncoding]];
            return nil;
    }];

    [[self http] handleGET:@"/api/instances"
        with:^(HTTPConnection *connection) {
            NSData *JSONData = [NSJSONSerialization dataWithJSONObject:[[iSpy sharedInstance] instance_dumpAppInstancesWithPointersDict] options:0 error:NULL];
            [connection writeString:[[NSString alloc] initWithBytes:[JSONData bytes] length:[JSONData length] encoding: NSUTF8StringEncoding]];
            return nil;
    }];

    // return an array of class names
    [[self http] handleGET:@"/api/classes"
        with:^(HTTPConnection *connection) {
            NSData *JSONData = [NSJSONSerialization dataWithJSONObject:[[iSpy sharedInstance] classes] options:0 error:NULL];
            [connection writeString:[[NSString alloc] initWithBytes:[JSONData bytes] length:[JSONData length] encoding: NSUTF8StringEncoding]];
            return nil;
    }];    // return an array of class names
    
    [[self http] handleGET:@"/api/appChecksum"
        with:^(HTTPConnection *connection) {
            NSData *JSONData = [NSJSONSerialization dataWithJSONObject:@{ @"SHA256HMAC": [[iSpy sharedInstance] SHA256HMACForAppBinary]} options:0 error:NULL];
            [connection writeString:[[NSString alloc] initWithBytes:[JSONData bytes] length:[JSONData length] encoding: NSUTF8StringEncoding]];
            return nil;
    }];

    // return an array of class names
    [[self http] handleGET:@"/api/classesWithSuperClassAndProtocolInfo"
        with:^(HTTPConnection *connection) {
            NSData *JSONData = [NSJSONSerialization dataWithJSONObject:[[iSpy sharedInstance] classesWithSuperClassAndProtocolInfo] options:0 error:NULL];
            [connection writeString:[[NSString alloc] initWithBytes:[JSONData bytes] length:[JSONData length] encoding: NSUTF8StringEncoding]];
            return nil;
    }];

    [[self http] handleGET:@"/api/infoForMethod/*/*"
        with:^(HTTPConnection *connection, NSString *selName, NSString *clsName) {
            NSDictionary * dict = [[iSpy sharedInstance] infoForMethod:NSSelectorFromString(selName) inClass:objc_getClass([clsName UTF8String])];
            NSData *JSONData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:NULL];
            [connection writeString:[[NSString alloc] initWithBytes:[JSONData bytes] length:[JSONData length] encoding: NSUTF8StringEncoding]];
            return nil;
    }];

    [[self http] handleGET:@"/api/protocolDump"
        with:^(HTTPConnection *connection, NSString *clsName) {
            NSData *JSONData = [NSJSONSerialization dataWithJSONObject:[[iSpy sharedInstance] protocolDump] options:0 error:NULL];
            [connection writeString:[[NSString alloc] initWithBytes:[JSONData bytes] length:[JSONData length] encoding: NSUTF8StringEncoding]];
            return nil;
    }];

    [[self http] handleGET:@"/api/classDump"
        with:^(HTTPConnection *connection, NSString *clsName) {
            NSData *JSONData = [NSJSONSerialization dataWithJSONObject:[[iSpy sharedInstance] classDump] options:0 error:NULL];
            [connection writeString:[[NSString alloc] initWithBytes:[JSONData bytes] length:[JSONData length] encoding: NSUTF8StringEncoding]];
            return nil;
    }];

    [[self http] handleGET:@"/api/classDumpClass/*"
        with:^(HTTPConnection *connection, NSString *clsName) {
            NSData *JSONData = [NSJSONSerialization dataWithJSONObject:[[iSpy sharedInstance] classDumpClass:clsName] options:0 error:NULL];
            [connection writeString:[[NSString alloc] initWithBytes:[JSONData bytes] length:[JSONData length] encoding: NSUTF8StringEncoding]];
            return nil;
    }];

    [[self http] handleGET:@"/api/protocolsForClass/*"
        with:^(HTTPConnection *connection, NSString *clsName) {
            NSData *JSONData = [NSJSONSerialization dataWithJSONObject:[[iSpy sharedInstance] protocolsForClass:clsName] options:0 error:NULL];
            [connection writeString:[[NSString alloc] initWithBytes:[JSONData bytes] length:[JSONData length] encoding: NSUTF8StringEncoding]];
            return nil;
    }];

    [[self http] handleGET:@"/api/iVarsForClass/*"
        with:^(HTTPConnection *connection, NSString *clsName) {
            NSData *JSONData = [NSJSONSerialization dataWithJSONObject:[[iSpy sharedInstance] iVarsForClass:clsName] options:0 error:NULL];
            [connection writeString:[[NSString alloc] initWithBytes:[JSONData bytes] length:[JSONData length] encoding: NSUTF8StringEncoding]];
            return nil;
    }];


    [[self http] handleGET:@"/api/propertiesForClass/*"
        with:^(HTTPConnection *connection, NSString *clsName) {
            NSData *JSONData = [NSJSONSerialization dataWithJSONObject:[[iSpy sharedInstance] propertiesForClass:clsName] options:0 error:NULL];
            [connection writeString:[[NSString alloc] initWithBytes:[JSONData bytes] length:[JSONData length] encoding: NSUTF8StringEncoding]];
            return nil;
    }];

    [[self http] handleGET:@"/api/methodsForClass/*"
        with:^(HTTPConnection *connection, NSString *clsName) {
            NSData *JSONData;
            NSArray *methods = [[iSpy sharedInstance] methodsForClass:clsName];
            JSONData = [NSJSONSerialization dataWithJSONObject:methods options:0 error:NULL];
            [connection writeString:[[NSString alloc] initWithBytes:[JSONData bytes] length:[JSONData length] encoding: NSUTF8StringEncoding]];
            return nil;
    }];

    // Rest of the API stuff
    [[self http] handleGET:@"/api/**"
        with:^(HTTPConnection *connection, NSString *args) {
            NSString *content;
            content = [[[NSString alloc] initWithString:@""] autorelease];

            // /api/info
            if([args isEqualToString:@"info"]) {
                NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
                NSData *JSONData = [NSJSONSerialization dataWithJSONObject:@{
                        @"iOS Version": [[NSProcessInfo processInfo] operatingSystemVersionString],
                        @"Process Name": [infoDict valueForKey:@"CFBundleDisplayName"],
                        @"Commandline": [[NSProcessInfo processInfo] arguments],
                        @"environment": [[NSProcessInfo processInfo] environment],
                        @"Hostname": [[NSProcessInfo processInfo] hostName],
                        @"Physical RAM": [NSString stringWithFormat:@"%lld bytes", [[NSProcessInfo processInfo] physicalMemory]],
                        @"PID": [NSString stringWithFormat:@"%d", [[NSProcessInfo processInfo] processIdentifier]],
                        @"Bundle ID":  [infoDict valueForKey:@"CFBundleIdentifier"],
                        @"Network": [self getNetworkInfo],
                    } options:0 error:NULL];
                content = [[NSString alloc] initWithBytes:[JSONData bytes] length:[JSONData length] encoding: NSUTF8StringEncoding];
            }

            // /api/summary
            else if([args isEqualToString:@"info/summary"]) {
                NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
                NSData *JSONData = [NSJSONSerialization dataWithJSONObject:@{
                        @"iOS Version": [[NSProcessInfo processInfo] operatingSystemVersionString],
                        @"Process Name": [infoDict valueForKey:@"CFBundleDisplayName"],
                        @"Commandline": [[NSProcessInfo processInfo] arguments],
                        @"Bundle ID": [infoDict valueForKey:@"CFBundleIdentifier"],
                        @"Path": [[[NSBundle mainBundle] resourcePath] stringByDeletingLastPathComponent],
                    } options:0 error:NULL];
                content = [[NSString alloc] initWithBytes:[JSONData bytes] length:[JSONData length] encoding: NSUTF8StringEncoding];
            }

            // /api/network
            else if([args isEqualToString:@"info/network"]) {
                NSData *JSONData = [NSJSONSerialization dataWithJSONObject:[self getNetworkInfo] options:0 error:NULL];
                content = [[NSString alloc] initWithBytes:[JSONData bytes] length:[JSONData length] encoding: NSUTF8StringEncoding];
            }

            // /api/msgSend/status
            // Returns:
            //      the state of objc_msgSend hook initialization (ie. is the msgSend logging subsytem ready?) (as a boolean 0 / 1)
            //      the current off/on state of the msgSend logger (as a boolean 0 / 1)

            // /api/monitor/status
            // Returns:
            //      the on/off status of the msgSend logging service
            //      the on/off status of the instance tracker
            //      the on/off status of the strace logger
            //      the on/off status of the HTTP loggers

            else if([args isEqualToString:@"monitor/status"]) {
                NSData *JSONData = [NSJSONSerialization dataWithJSONObject:@{
                        @"msgSendState": [NSString stringWithFormat:@"%d", [mySpy msgSend_getLoggingState]],
                    } options:0 error:NULL];
                content = [[NSString alloc] initWithBytes:[JSONData bytes] length:[JSONData length] encoding: NSUTF8StringEncoding];
            }

            // Return a JSON response containing the app's .text symbol table
            else if([args isEqualToString:@"symbols"]) {
                NSData *JSONData = [NSJSONSerialization dataWithJSONObject:@{
                        @"symbols": [mySpy getSymbolTable]
                    } options:0 error:NULL];
                content = [[[NSString alloc] initWithBytes:[JSONData bytes] length:[JSONData length] encoding: NSUTF8StringEncoding] autorelease];
            }

            // return a JSON response containing the app's Mach-O head flags as a 32-bit int.
            // this is interesting for example with relation to MH_PIE flag (0x00200000), which
            // determines the on / off state of ASLR for an app.
            else if([args isEqualToString:@"machFlags"]) {
                NSData *JSONData = [NSJSONSerialization dataWithJSONObject:@{
                        @"flags": [NSString stringWithFormat:@"%d", [mySpy getMachFlags]]
                    } options:0 error:NULL];
                content = [[[NSString alloc] initWithBytes:[JSONData bytes] length:[JSONData length] encoding: NSUTF8StringEncoding] autorelease];
            }

            // /api/keychain
            // Dump the keychain enties as JSON
            else if([args isEqualToString:@"keychain"]) {
                NSData *JSONData = [NSJSONSerialization dataWithJSONObject:@{
                        @"keychain": [mySpy keyChainItems]
                    } options:0 error:NULL];
                content = [[[NSString alloc] initWithBytes:[JSONData bytes] length:[JSONData length] encoding: NSUTF8StringEncoding] autorelease];
            }

            // /api/aslr
            // Dump the ASLR slide for the running instance of the app as an unsigned 32-bit int.
            // if this is 0 (zero) there's a good chance that MH_PIE is not set in the Mach-O header flags.
            else if([args isEqualToString:@"aslr"]) {
                NSData *JSONData = [NSJSONSerialization dataWithJSONObject:@{
                        @"ASLR": [NSString stringWithFormat:@"%u", [mySpy ASLR]],
                    } options:0 error:NULL];
                content = [[[NSString alloc] initWithBytes:[JSONData bytes] length:[JSONData length] encoding: NSUTF8StringEncoding] autorelease];
            }

            // return the content to the caller
            return content;
    }];

    // Handle POST requests to the API
    [[self http] handlePOST:@"/api/**"
        with:^(HTTPConnection *connection, NSString *args) {
            NSString *content;
            NSError *e;
            
            content = @"";
            
            /*
                /api/dirListing
                Parameters: dir=/path/to/return/listing/of
                Returns: an HTML formatted directory listing for the HTML file browser client.

                This should really be JSON instead of mixing data with formatting. TBD.
            */
            if([args containsString:@"dirListing"]) {
                NSMutableString *dirContent = [[NSMutableString alloc] init];
                // stupid %20 bug
                NSString *dir = [[connection requestBodyVar:@"dir"] stringByReplacingOccurrencesOfString:@"%20" withString:@" "];
                NSFileManager *fileMan = [NSFileManager defaultManager];
                NSArray *dirListing = [fileMan contentsOfDirectoryAtPath:dir error:&e];
                NSDictionary *attrs;
                
                [dirContent appendString:[NSString stringWithFormat:@"<ul class='jqueryFileTree' style='display: none;'>"]];
                for (id dirEntry in dirListing) {
                    attrs = [fileMan attributesOfItemAtPath:[NSString stringWithFormat:@"%@/%@", dir, dirEntry] error:NULL];    
                    if([attrs objectForKey:NSFileType] == NSFileTypeDirectory) {
                        [dirContent appendString:[NSString stringWithFormat:@"<li class='directory collapsed'><a href='#' rel='%@/%@/'>%@</a></li>", dir, dirEntry, dirEntry]];
                    } else {
                        [dirContent appendString:[NSString stringWithFormat:@"<li class='file ext_%@'><a href='#' rel='%@/%@'>%@</a></li>", [dirEntry pathExtension], dir, dirEntry, dirEntry]];   
                    }
                }
                [dirContent appendString:[NSString stringWithFormat:@"</ul>\n"]];
                content = [[[NSString alloc] initWithString:dirContent] autorelease];
            }

            /*
                /api/msgSend/options
                Parameters: enableDisable=<on|off>

                Why is this called "options" instead of something more relevant? TBD.
            */
            else if([args containsString:@"msgSend/options"]) {

                NSString *restrictToAppBundle = [connection requestBodyVar:@"restrictToAppBundle"];
                if([restrictToAppBundle isEqualToString:@"on"]) {
                    ; // do nothing for now
                } else {
                    ; // more nothing
                }
            }

            // restart the webserver to flush its cache, etc
            else if([args containsString:@"bounceWebServer"]) {
                [self bounceWebServer];
            }

/*
                This is used by the client to enable or disable logging for
                any of the facilities (msgSend, strace, etc).

                It's called by the navbar buttons whenever a user presses one.
                See menu.mustache.
            */
            else if([args containsString:@"monitor/status"]) {
                NSString *item = [connection requestBodyVar:@"item"];
                NSString *state = [connection requestBodyVar:@"state"];
                // See menu.mustache for the controls that trigger this call
                if([item isEqualToString:@"msgSndLogging"]) { // Look for references to msgSndLogging and straceLogging
                    if([state isEqualToString:@"1"]) {  // the menu button will emit a "1" when it's turned on...
                        ispy_log_debug(LOG_GENERAL, "objc_msgSend logging enabled!");
                        [mySpy msgSend_enableLogging];
                    } else {
                        [mySpy msgSend_disableLogging]; // ...and a "0" when turned off
                    }
                }
            }

            return content;
    }];

    // Anything that's not a handled GET or POST is a 404
    [[self http] handleGET:@"/*"
        with:^(HTTPConnection *connection, NSString *name) {
            return [self renderStaticTemplate:@"404"];
    }];

    ispy_log_info(LOG_GENERAL, "[iSpy] Started HTTP server on http://YOURDEVICE:%d/", WEBSERVER_PORT);
    return true;
}


/*
    Return a dictionary, with one entry per network interface (en0, en1, lo0)
*/
-(NSDictionary *)getNetworkInfo {
    NSString *address;
    NSString *interface;
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    NSMutableDictionary *info = [[NSMutableDictionary alloc] init];

    success = getifaddrs(&interfaces);
    if (success == 0) {
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            interface = [NSString stringWithUTF8String:temp_addr->ifa_name];
            address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
            [info setValue:address forKey:interface];
            temp_addr = temp_addr->ifa_next;
        }
    }

    freeifaddrs(interfaces);
    return info;
}

@end

// This is the equivalent of [[HTTPConnection connection] writeString:@"Wakka wakka"] except that it's
// pure C all the way down, so it's safe to call it inside the msgSend logging routines.
// NOT thread safe. Handle locking yourself.
// Requires C linkage for the msgSend stuff.
extern "C" {
    int bf_websocket_write(const char *msg) {
        if(globalMsgSendWebSocketPtr == NULL) {
            return -1;
        }
        else {
            return mg_websocket_write(globalMsgSendWebSocketPtr, 1, msg, strlen(msg));
        }
    }
}

