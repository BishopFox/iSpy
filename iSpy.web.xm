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
#import  "GRMustache/include/GRMustache.h"
#include <dlfcn.h>
#include <mach-o/nlist.h>
#include <semaphore.h>
#import <MobileCoreServices/MobileCoreServices.h>

FILE *logReadFP[MAX_LOG+1];

NSString *templatesPath = @"/var/www/iSpy/templates";   // Path to the Mustache HTML templates
GRMustacheTemplateRepository *templatesRepo;                // Template repository class
static struct mg_connection *globalMsgSendWebSocketPtr = NULL; // mg_connection is (was) a private struct in HTTPKit

@implementation iSpyServer 
/****************************************************************
    This is where we setup the web server and Mustache templates.
*****************************************************************/

// This is a short-cut helper function.
// Pass it the name of a template (eg "home_page") and it'll render it for you.
-(NSString *)renderStaticTemplate:(NSString *)tpl {
    GRMustacheTemplate *bfTemplate = [templatesRepo templateNamed:@"main" error:NULL];
    GRMustacheTemplate *bfContent = [templatesRepo templateNamed:tpl error:NULL];
    id content = @{ @"content": [bfContent renderObject:@{ } error:NULL] };
    return [bfTemplate renderObject:content error:NULL];  
}

-(id)init {
    [super init];
    [self setHttp:NULL];
    [self setWsGeneral:NULL];
    [self setWsStrace:NULL];
    [self setWsMsgSend:NULL];
    [self setWsInstance:NULL];
    [self setWsISpy:NULL];
    
    [self setStraceReadLock:0];
    [self setMsgSendReadLock:0];
    [self setGeneralReadLock:0];
    
    [self setHttp:[[HTTP alloc] init]];
    [self setWsISpy:[[HTTP alloc] init]];
    
    [[self http] setEnableDirListing:NO];
    [[self http] setPublicDir:@"/var/www/iSpy"];

    [[self wsISpy] setEnableKeepAlive:YES];
    
    return self;
} 


-(BOOL) startWebServices {
    // Initialize the iSpy web service
    iSpy *mySpy = [iSpy sharedInstance];
    BOOL ret;
    
    ret = [[self http] listenOnPort:WEBSERVER_PORT onError:^(id reason) {
        bf_logwrite(LOG_GENERAL, "[iSpy] Error starting server: %s", [reason UTF8String]);
    }];
    if(!ret) {
        return ret;
    }

    // Initialize the Mustache HTML templates
    templatesRepo = [GRMustacheTemplateRepository templateRepositoryWithDirectory:templatesPath];

    // Setup the HTTP endpoint handlers
    [[self wsISpy] listenOnPort:31338 onError:^(id reason) {
        NSLog(@"Fucked up web services socket: %s", [reason UTF8String]);
    }];

    [[self wsISpy] handleWebSocket:^id (HTTPConnection *connection) {
        if(!connection.isOpen) {
            bf_logwrite(LOG_GENERAL, "Closed web socket.");
            globalMsgSendWebSocketPtr = NULL;
            return nil;
        }
        
        //NSLog(@"WebSocket message '%s'", [connection.requestBody UTF8String]);
        
        globalMsgSendWebSocketPtr = [connection connectionPtr];

        return nil; // @"Ok"; //[connection.requestBody capitalizedString];
    }];

    // Handler for the web root. Displays home page.
    [[self http] handleGET:@"/"
        with:^(HTTPConnection *connection) {
            return [self renderStaticTemplate:@"home_page"];
    }];
    
    // Handler for all static content: CSS, JavaScript, images, etc
    // Accepts format: http://idevice:31337/static/images/logo.png or /static/css/base.css or /static/js/iSpy.js etc
    [[self http] handleGET:@"/static/*/*"
        with:^(HTTPConnection *connection, NSString *folder, NSString *fname) {
            NSString *contentType;

            // Set Content-Type for images
            if( [fname rangeOfString:@".png"].location != NSNotFound ||
                [fname rangeOfString:@".jpg"].location != NSNotFound ||
                [fname rangeOfString:@".ico"].location != NSNotFound ||
                [fname rangeOfString:@".gif"].location != NSNotFound) {
                contentType = [NSString stringWithFormat:@"image/%@", [fname pathExtension]];
            }

            // Set Content-Type for CSS
            else if([fname rangeOfString:@".css"].location != NSNotFound) {
                contentType = [NSString stringWithFormat:@"text/css"];
            }

            // Set Content-Type for JavaScript
            else if([fname rangeOfString:@".js"].location != NSNotFound) {
                contentType = [NSString stringWithFormat:@"text/javascript"];
            }

            // Fall back to HTML Content-Type
            else {
                contentType = [NSString stringWithFormat:@"text/html"];
            }

            // Locate the file, read it, set the Content-Type and Content-Length, then send the actual data to the client.
            NSString *pathToStaticFile = [NSString stringWithFormat:@"%@/static/%@/%@", [[self http] publicDir], folder, fname];
            NSData *data = [NSData dataWithContentsOfFile:pathToStaticFile];
            [connection setResponseHeader:@"Content-Type" to:contentType]; // blah blah hard-coded type blah
            [connection setResponseHeader:@"Content-Length" to:[NSString stringWithFormat:@"%d", [data length]]];
            [connection writeData:data];
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
            NSData *JSONData = [NSJSONSerialization dataWithJSONObject:[[iSpy sharedInstance] instance_dumpAppInstancesWithPointersArray] options:0 error:NULL];
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
            
            else if([args isEqualToString:@"msgSend/status"]) {
                NSData *JSONData = [NSJSONSerialization dataWithJSONObject:@{
                        @"initialized": [NSString stringWithFormat:@"%d", [mySpy msgSend_isInitialized]],
                        @"enabled": [NSString stringWithFormat:@"%d", [mySpy msgSend_getLoggingState]],
                    } options:0 error:NULL];
                content = [[NSString alloc] initWithBytes:[JSONData bytes] length:[JSONData length] encoding: NSUTF8StringEncoding];
            }

            // /api/monitor/status
            // Returns:
            //      the on/off status of the msgSend logging service
            //      the on/off status of the instance tracker
            //      the on/off status of the strace logger
            //      the on/off status of the HTTP loggers
            else if([args isEqualToString:@"monitor/status"]) {
                NSData *JSONData = [NSJSONSerialization dataWithJSONObject:@{
                        @"instanceState": [NSString stringWithFormat:@"%d", [mySpy instance_getTrackingState]],
                        @"msgSendState": [NSString stringWithFormat:@"%d", [mySpy msgSend_getLoggingState]],
                        @"straceState": [NSString stringWithFormat:@"%d", [mySpy strace_getLoggingState]],
                        @"HTTPState": [NSString stringWithFormat:@"%d", 0],
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

            /*
             /api/strace/readlog
             Returns any unread log entires.
             For this we need our own dedicated filehandles for reading the logs. This way we keep track of
             our location independent of where the log writer is. 
             Arbitrarily truncates lines at 1024 characters.
             Uses very simplistic locking to prevent readlog racing with readentirelog.
            */
            else if([args containsString:@"strace/readlog"]) {
                char buf[1026];
                NSMutableString *mString;
                long oldpos;

                if(![self straceReadLock]) {
                    [self setStraceReadLock:1];
                    mString = [[NSMutableString alloc] init];
                    oldpos = ftell(logReadFP[LOG_STRACE]);
                    fclose(logReadFP[LOG_STRACE]);
                    logReadFP[LOG_STRACE] = fopen(BF_LOGFILE_STRACE, "r");
                    fseek(logReadFP[LOG_STRACE], oldpos, SEEK_SET);
                    while(!feof(logReadFP[LOG_STRACE])) {
                        if(!fgets(buf, 1024, logReadFP[LOG_STRACE]))
                            break;
                        [mString appendString:[NSString stringWithUTF8String:buf]];
                    }
                    content = [[NSString alloc] initWithString:mString];
                    [self setStraceReadLock:0];
                }
            }

            /*
             /api/msgSend/readlog
             Returns any unread log entires for objc_msgSend logging.
             For this we need our own dedicated filehandles for reading the logs. This way we keep track of
             our location independent of where the log writer is. 
             Arbitrarily truncates lines at 1024 characters.
             Uses very simplistic locking to prevent readlog conflicting with readentirelog.
            */
            else if([args containsString:@"msgSend/readlog"]) {
                char buf[1026];
                char prevLine[1026]="\0";
                int lineCount;
                NSMutableString *mString;
                long oldpos;

                if(![self msgSendReadLock]) {
                    [self setMsgSendReadLock:1];
                    lineCount=0;
                    mString = [[NSMutableString alloc] init];
                    oldpos = ftell(logReadFP[LOG_MSGSEND]); // save position in file
                    logReadFP[LOG_MSGSEND] = freopen(BF_LOGFILE_MSGSEND, "r", logReadFP[LOG_MSGSEND]); // reopen to take account of any new entries
                    fseek(logReadFP[LOG_MSGSEND], oldpos, SEEK_SET); // restore position in file

                    [mString appendString:@"{\"logs\":["];
                    // read new entries
                    while(!feof(logReadFP[LOG_MSGSEND])) {
                        if(!fgets(buf, 1024, logReadFP[LOG_MSGSEND])) // 1024 characters is an arbitrary line length limit
                            break;
                        //buf[strlen(buf)-1] = ',';
                        if(strcmp(prevLine, buf) != 0) {
                            if(lineCount) {
                                //[mString appendString:[NSString stringWithFormat:@"Last line repeated %d times\n", lineCount]];
                                lineCount=0;
                            }
                            strcpy(prevLine, buf);
                            [mString appendString:[NSString stringWithUTF8String:buf]];
                        } else {
                            lineCount++;
                        }
                    }
                    [mString appendString:@"[]]}"];
                    content = [[NSString alloc] initWithString:mString];
                    [self setMsgSendReadLock:0];
                }
            }

            // Reads the general iSpy log.
            else if([args containsString:@"general/readlog"]) {
                char buf[1026];
                NSMutableString *mString = [[NSMutableString alloc] init];
                long oldpos;

                NSLog(@"REading logfile... %d", [self generalReadLock]);

                if(![self generalReadLock]) {
                    [self setGeneralReadLock:1];
                    oldpos = ftell(logReadFP[LOG_GENERAL]);
                    fclose(logReadFP[LOG_GENERAL]);
                    logReadFP[LOG_GENERAL] = fopen(BF_LOGFILE_GENERAL, "r");
                    fseek(logReadFP[LOG_GENERAL], oldpos, SEEK_SET);
                    while(!feof(logReadFP[LOG_GENERAL])) {
                        if(!fgets(buf, 1024, logReadFP[LOG_GENERAL]))
                            break;
                        [mString appendString:[NSString stringWithCString:buf encoding:NSUTF8StringEncoding]];
                    }
                    content = [mString copy];
                    [self setGeneralReadLock:0];
                }
                NSLog(@"done reading logfile");
            }

            // The user can elect to reload an entire log from the beginning
            else if([args containsString:@"general/readentirelog"]) {
                rewind(logReadFP[LOG_GENERAL]);
            }
            else if([args containsString:@"strace/readentirelog"]) {
                rewind(logReadFP[LOG_STRACE]);
            }
            else if([args containsString:@"msgSend/readentirelog"]) {
                rewind(logReadFP[LOG_MSGSEND]);
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
                NSString *enabled = [connection requestBodyVar:@"enableDisable"];
                if([enabled isEqualToString:@"on"]) {
                    [mySpy msgSend_enableLogging];
                } else {
                    [mySpy msgSend_disableLogging];
                }

                NSString *restrictToAppBundle = [connection requestBodyVar:@"restrictToAppBundle"];
                if([restrictToAppBundle isEqualToString:@"on"]) {
                    ; // do nothing for now
                } else {
                    ; // more nothing
                }
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
                        [mySpy msgSend_enableLogging];
                    } else {
                        [mySpy msgSend_disableLogging]; // ...and a "0" when turned off
                    }
                }
                if([item isEqualToString:@"straceLogging"]) {
                    if([state isEqualToString:@"1"]) {
                        [mySpy strace_enableLogging];
                    } else {
                        [mySpy strace_disableLogging];
                    }
                }
                if([item isEqualToString:@"instanceTracking"]) {
                    if([state isEqualToString:@"1"]) {
                        [mySpy instance_enableTracking];
                    } else {
                        [mySpy instance_disableTracking];
                    }
                }
                if([item isEqualToString:@"btnHTTPState"]) {
                    if([state isEqualToString:@"1"]) {
                        ;
                    } else {
                        ;
                    }
                }

            }

            /*
                /api/msgSend/clearLog
                Does what it says on the tin.
            */
            else if([args containsString:@"msgSend/clearLog"]) {
                fclose(logReadFP[LOG_MSGSEND]);
                bf_clear_log(LOG_MSGSEND);
                logReadFP[LOG_MSGSEND] = fopen(BF_LOGFILE_MSGSEND, "r");
            }

            /*
                /api/strace/clearLog
                Does what it says on the tin.
            */
            else if([args containsString:@"strace/clearLog"]) {
                fclose(logReadFP[LOG_MSGSEND]);
                bf_clear_log(LOG_MSGSEND);
                logReadFP[LOG_MSGSEND] = fopen(BF_LOGFILE_MSGSEND, "r");
            }

            return content;
    }];

    // Anything that's not a handled GET or POST is a 404
    [[self http] handleGET:@"/*"
        with:^(HTTPConnection *connection, NSString *name) {
            return [self renderStaticTemplate:@"404"];
    }];

    bf_logwrite(LOG_GENERAL, "[iSpy] Started HTTP server on http://YOURDEVICE:%d/", WEBSERVER_PORT);
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
        if(globalMsgSendWebSocketPtr == NULL)
            return -1;
        else
            return mg_websocket_write(globalMsgSendWebSocketPtr, 1, msg, strlen(msg));
    }
}

