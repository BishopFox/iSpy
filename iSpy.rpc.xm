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
#include <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonHMAC.h>
#include "iSpy.common.h"
#include "iSpy.instance.h"
#include "iSpy.class.h"
#include "hooks_C_system_calls.h"
#include "hooks_CoreFoundation.h"
#include <dlfcn.h>
#include <mach-o/nlist.h>
#include <semaphore.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>
#import "typestring.h"
#import "iSpy.rpc.h"

/*
 *
 * RPC handlers take exactly one argument: an NSDictionary of parameter/value pairs.
 *
 * RPC handlers return an NSDictionary that will be sent to the RPC caller as JSON,
 * either via a websocket (if initiated by websocket) or as a response to an HTTP POST.
 *
 * You can also return nil, that's fine too. For websockets nothing will happen; for POST
 * requests it'll cause a blank response to be sent back to the RPC caller.
 *
 */
@implementation RPCHandler

-(NSDictionary *) setMsgSendLoggingState:(NSDictionary *) args {
	NSString *state = [args objectForKey:@"state"];

	if( ! state || ( ! [state isEqualToString:@"true"] && ! [state isEqualToString:@"false"] )) {
		ispy_log_debug(LOG_HTTP, "setMsgSendLoggingState: Invalid state");
		return @{
			@"status":@"error",
			@"errorMessage":@"Invalid status"
		};
	}

	if([state isEqualToString:@"true"]) {
		[[iSpy sharedInstance] msgSend_enableLogging];
	}
	else if([state isEqualToString:@"false"]) {
		[[iSpy sharedInstance] msgSend_disableLogging];
	}

	return @{ @"status":state };
}


-(NSDictionary *) testJSONRPC:(NSDictionary *)args {
	return @{ @"REPLY_TEST":args };
}

@end


