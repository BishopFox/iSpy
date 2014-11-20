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

	return @{
		@"status":@"OK",
		@"JSON": @{
            @"state": state,
        },
	};
}


-(NSDictionary *) testJSONRPC:(NSDictionary *)args {
	return @{
		@"status":@"OK",
		@"JSON": @{
            @"args": args,
        },
	};
}

-(NSDictionary *) ASLR:(NSDictionary *)args {
	return @{
		@"status":@"OK",
		@"JSON": @{
            @"ASLROffset": [NSString stringWithFormat:@"%d", [[iSpy sharedInstance] ASLR]]
        },
	};
}

/*
args = NSDictionary containing an object ("classes"), which is is an NSArray of NSDictionaries, like so:
{
	"classes": [
		{
			"class": "ClassName1",
			"methods": [ @"Method1", @"Method2", ... ]
		},
		{
			"class": "ClassName2",
			"methods": [ @"MethodX", @"MethodY", ... ]
		},
		...
	]
}

If "methods" is nil, assume all methods in class.
*/
-(NSDictionary *) addMethodsToWhitelist:(NSDictionary *)args {
    int i, numClasses, m, numMethods;
    static std::tr1::unordered_map<std::string, std::tr1::unordered_map<std::string, int> > WhitelistClassMap;

    NSArray *classes = [args objectForKey:@"classes"];
    if(classes == nil) {
    	return @{
    		@"status": @"error",
    		@"errorMessage": @"Empty class list"
    	};
    }

	numClasses = [classes count];

    // Iterate through all the class names, adding each one to our lookup table
    for(i = 0; i < numClasses; i++) {
    	NSDictionary *itemToAdd = [classes objectAtIndex:i];
    	NSString *name = [itemToAdd objectForKey:@"class"];
    	if(!name) {
    		continue;
    	}

    	NSArray *methods = [itemToAdd objectForKey:@"methods"];
    	if(!methods) {
    		continue;
    	}

    	numMethods = [methods count];
    	if(!numMethods) {
    		continue;
    	}

    	for(m = 0; m < numMethods; m++) {
    		NSString *methodName = [methods objectAtIndex:m];
    		if(!methodName) {
    			continue;
    		}
    		std::string *classNameString = new std::string([name UTF8String]);
    		std::string *methodNameString = new std::string([methodName UTF8String]);
    		if(!classNameString || !methodNameString) {
    			if(methodNameString)
    				delete methodNameString;
    			if(classNameString)
    				delete classNameString;
    			continue;
    		}
    		ispy_log_debug(LOG_GENERAL, "[Whitelist] Adding [%s %s]", classNameString->c_str(), methodNameString->c_str());
            whitelist_add_method(classNameString, methodNameString, (unsigned int)WHITELIST_PRESENT);
    		delete methodNameString;
    		delete classNameString;
    	}
    }
    return @{
    	@"status": @"OK",
    	@"JSON": @{},
    };
}


/*
 * 	Classes and internals
 */


-(NSDictionary *) classList:(NSDictionary *)args {
	NSArray *classes = [[iSpy sharedInstance] classes];
	return @{
		@"status": @"OK",
		@"JSON": @{
            @"classes": classes,
        },
	};
}

-(NSDictionary *) classListWithProtocolInfo:(NSDictionary *)args {
	NSArray *classes = [[iSpy sharedInstance] classesWithSuperClassAndProtocolInfo];
	return @{
		@"status": @"OK",
		@"JSON": @{
            @"classes": classes,
        },
	};
}

-(NSDictionary *) methodsForClass:(NSDictionary *)args {
	NSString *className = [args objectForKey:@"class"];
    if(className == nil) {
    	return @{
    		@"status": @"error",
    		@"errorMessage": @"Empty class name",
    	};
    }

    NSArray *methods = [[iSpy sharedInstance] methodListForClass:className];
    if(methods == nil) {
    	return @{
    		@"status": @"error",
    		@"errorMessage": @"Empty methods list",
    	};
    }

    return @{
    	@"status": @"OK",
    	@"JSON": @{
            @"name": className,
            @"methods": methods,
        },
    };
}

-(NSDictionary *) propertiesForClass:(NSDictionary *)args {
	NSString *className = [args objectForKey:@"class"];
    if(className == nil) {
    	return @{
    		@"status": @"error",
    		@"errorMessage": @"Empty class name"
    	};
    }

    NSArray *properties = [[iSpy sharedInstance] propertiesForClass:className];
    if(properties == nil) {
    	return @{
    		@"status": @"error",
    		@"errorMessage": @"Empty properties list"
    	};
    }

    return @{
    	@"status": @"OK",
    	@"JSON": @{
            @"name": className,
            @"properties": properties,
        },
    };
}

-(NSDictionary *) protocolsForClass:(NSDictionary *)args {
	NSString *className = [args objectForKey:@"class"];
    if(className == nil) {
    	return @{
    		@"status": @"error",
    		@"errorMessage": @"Empty class name"
    	};
    }

    NSArray *protocols = [[iSpy sharedInstance] protocolsForClass:className];
    if(protocols == nil) {
    	return @{
    		@"status": @"error",
    		@"errorMessage": @"Empty protocols list"
    	};
    }

    return @{
    	@"status": @"OK",
    	@"JSON": @{
            @"name": className,
            @"protocols": protocols,
        },
    };
}

-(NSDictionary *) iVarsForClass:(NSDictionary *)args {
	NSString *className = [args objectForKey:@"class"];
    if(className == nil) {
    	return @{
    		@"status": @"error",
    		@"errorMessage": @"Empty class name"
    	};
    }

    NSArray *iVars = [[iSpy sharedInstance] iVarsForClass:className];
    if(iVars == nil) {
    	return @{
    		@"status": @"error",
    		@"errorMessage": @"Empty iVars list"
    	};
    }


    return @{
    	@"status": @"OK",
    	@"JSON": @{
            @"name": className,
            @"iVars": iVars,
        },
    };
}

-(NSDictionary *) infoForMethod:(NSDictionary *)args {
	NSString *className = [args objectForKey:@"class"];
	NSString *methodName = [args objectForKey:@"method"];
	if(className == nil || methodName == nil) {
    	return @{
    		@"status": @"error",
    		@"errorMessage": @"Empty class and/or name"
    	};
    }

    Class cls = objc_getClass([className UTF8String]);
    if(cls == nil) {
    	return @{
    		@"status": @"error",
    		@"errorMessage": @"That class doesn't exist"
    	};
    }

    SEL selector = sel_registerName([methodName UTF8String]);
    if(selector == nil) {
    	return @{
    		@"status": @"error",
    		@"errorMessage": @"That selector name was bad"
    	};
    }

    NSLog(@"class: %@ // method: %s", cls, [methodName UTF8String]);

    NSDictionary *infoDict = [[iSpy sharedInstance] infoForMethod:selector inClass:cls];
    if(infoDict == nil) {
    	return @{
    		@"status": @"error",
    		@"errorMessage": @"Error fetching information for that class/method"
    	};
    }

    return @{
    	@"status": @"OK",
    	@"JSON": @{
            @"methodInfo": infoDict
        },
    };
}


/*
 *	Protocol RPC
 */

-(NSDictionary *) methodsForProtocol:(NSDictionary *)args {
	NSString *protocolName = [args objectForKey:@"protocol"];
    if(protocolName == nil) {
    	return @{
    		@"status": @"error",
    		@"errorMessage": @"Empty protocol name"
    	};
    }

    NSArray *methods = [[iSpy sharedInstance] methodsForProtocol:objc_getProtocol([protocolName UTF8String])];
    if(methods == nil) {
    	return @{
    		@"status": @"error",
    		@"errorMessage": @"Empty methods list"
    	};
    }

    return @{
    	@"status": @"OK",
    	@"JSON": methods
    };
}

-(NSDictionary *) propertiesForProtocol:(NSDictionary *)args {
	NSString *protocolName = [args objectForKey:@"protocol"];
    if(protocolName == nil) {
    	return @{
    		@"status": @"error",
    		@"errorMessage": @"Empty protocol name"
    	};
    }

    NSArray *properties = [[iSpy sharedInstance] propertiesForProtocol:objc_getProtocol([protocolName UTF8String])];
    if(properties == nil) {
    	return @{
    		@"status": @"error",
    		@"errorMessage": @"Empty properties list"
    	};
    }

    return @{
    	@"status": @"OK",
    	@"JSON": properties
    };
}


/*
 *	Instance RPC
 */


-(NSDictionary *) instanceAtAddress:(NSDictionary *)args {
	NSString *addr = [args objectForKey:@"address"];
    if(addr == nil) {
    	return @{
    		@"status": @"error",
    		@"errorMessage": @"Empty address value"
    	};
    }

    return @{
    	@"status":@"OK",
    	@"JSON": [[InstanceTracker sharedInstance] instanceAtAddress:addr]
    };
}


-(NSDictionary *) instancesOfAppClasses:(NSDictionary *)args {
	return @{
		@"status":@"OK",
		@"JSON": @{
            @"classInstances": [[InstanceTracker sharedInstance] instancesOfAppClasses],
        },
	};
}


/*
 *	App info RPC
 */

-(NSDictionary *) applicationIcon:(NSDictionary *)args {
	UIImage *appIcon = [UIImage imageNamed:[[NSBundle mainBundle].infoDictionary[@"CFBundleIcons"][@"CFBundlePrimaryIcon"][@"CFBundleI‌​conFiles"] firstObject]];
	if(!appIcon) {
		appIcon = [UIImage imageNamed: [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIconFiles"] objectAtIndex:0]];
		if(!appIcon) {
			appIcon = [UIImage imageNamed:@"Icon@2x.png"];
			if(!appIcon) {
				appIcon = [UIImage imageNamed:@"Icon-72.png"];
				if(!appIcon) {
					appIcon = [UIImage imageNamed:@"/var/www/iSpy/img/bf-orange-alpha.png"];
					if(!appIcon) {
						return @{
							@"status":@"error",
							@"error": @"WTF, no app icon"
						};
					}
				}
			}
		}
	}
	
	//NSLog(@"Icon files: %@", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIconFiles"]);
	NSLog(@"appIcon: %@", appIcon);
	NSData *PNG = UIImagePNGRepresentation(appIcon);
	NSLog(@"PNG: %@", appIcon);
	NSString *base64PNG = [PNG base64EncodedStringWithOptions:0];

	return @{
		@"status":@"OK",
		@"JSON": @{
			@"imageURI": [NSString stringWithFormat:@"data:image/png;base64,%@", base64PNG]
		}
	};
}

-(NSDictionary *) appInfo:(NSDictionary *)args {
	NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
	NSArray *keys = [infoDict allKeys];
	NSMutableDictionary *interestingProperties = [[NSMutableDictionary alloc] init];

	for(int i=0; i < [keys count]; i++) {
		id obj = [keys objectAtIndex:i];
		if([[infoDict objectForKey:obj] class] == objc_getClass("__NSCFString")) {
			[interestingProperties setObject:[NSString stringWithString:[infoDict objectForKey:obj]] forKey:obj];
		}
	}

	return @{
		@"status":@"OK",
		@"JSON": interestingProperties
	};
}


-(NSDictionary *) keyChainItems:(NSDictionary *)args {
	return @{
		@"status":@"OK",
		@"JSON": [[iSpy sharedInstance] keyChainItems]
	};
}

-(NSDictionary *) releaseBreakpoint:(NSDictionary *)args {
    const char *className = [[args objectForKey:@"className"] UTF8String];
    const char *methodName = [[args objectForKey:@"methodName"] UTF8String];
    breakpoint_release_breakpoint(className, methodName);
    return @{
        @"status":@"OK",
        @"JSON": @"Released."
    };   
}

@end


