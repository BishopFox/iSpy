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
#include <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonHMAC.h>
#include "iSpy.common.h"
#include "iSpy.instance.h"
#include "iSpy.class.h"
#include "hooks_C_system_calls.h"
#include "hooks_CoreFoundation.h"
#include "HTTPKit/HTTP.h"
#import  "GRMustache/include/GRMustache.h"
#include <dlfcn.h>
#include <mach-o/nlist.h>
#include <semaphore.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>
#import "typestring.h"

static NSString *changeDateToDateString(NSDate *date);
static char *bf_get_type_from_signature(char *typeStr);
static char *bf_get_friendly_method_return_type(Method method);
static char *bf_get_attrs_from_signature(char *attributeCString);

id *appClassWhiteList = NULL;

/*************************************************************************************************
	This is the "iSpy" class implementation. It does cool stuff.  We use it quite a lot inside 
	the iSpy .dylib. It's used as a singleton. For example, consider the following code:

		%hook myTargetAppCoolClass
		-(void) someInterestingMethod {
			// get access to the iSpy singleton
			mySpy *mySpy = [iSpy sharedInstance];
			
			// turn on the strace logger
			[mySpy strace_enableLogging];
			
			// perform the original interesting method
			%orig;

			// turn off the strace logger
			[mySpy strace_disableLogging];

			// do analysis of the data or whatever.
			return;
		}
		%end
	
	This class is also exposed to Cycript, which makes it possible to interact with iSpy at runtime:

		ssh root@your.idevice
		cycript -p <PID>
		mySpy = [iSpy sharedInstance]
		[mySpy instance_enableTracking]
		...
		[mySpy instance_dumpAppInstancesWithPointers];

	The method names are kinda weird (often beginning with instance_, or msgSend_, or strace_, etc.)
	This is to make Cycript's tab-completion a joy to use by grouping methods together in an
	intuitive manner inside the Cycript REPL. For example, let's say you're using cycript and want
	to do something with iSpy's instance tracking support:

		cy# x = [iSpy sharedInstance ]
		"<iSpy: 0x1cd74cd0>"
		cy# [x instance_<<press tab twice>>
		instance_disableTracking                    instance_dumpAppInstancesWithPointers       instance_enableTracking                     instance_searchInstances:
		instance_dumpAllInstancesWithPointers       instance_dumpAppInstancesWithPointersArray  instance_numberOfTrackedInstances

	Voila! All the instance support functions appear. Same for msgSend, strace, etc.
**************************************************************************************************/
@implementation iSpy

// Returns the singleton
+ (id)sharedInstance {
	static iSpy *sharedInstance;
	static dispatch_once_t once;
	
	dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setWebServer:[[iSpyServer alloc] init]];
		[sharedInstance setGlobalStatusStr:@""];
		[sharedInstance setBundleId:[[[NSBundle mainBundle] bundleIdentifier] copy]];
		[sharedInstance setIsInstanceTrackingEnabled: NO];
		[sharedInstance setIsMsgSendTrackingEnabled: NO];
		[sharedInstance setIsStraceTrackingEnabled: NO];
		sharedInstance->_trackedInstances = [[NSMutableDictionary alloc] init];
	});
	
	return sharedInstance;
}

// Given the name of a class, this returns true if the class is declared in the target app, false if not.
// It's waaaaaay faster than checking bundleForClass shit from the Apple runtime.
+(BOOL)isClassFromApp:(NSString *)className {
	char *imageName = (char *)class_getImageName(objc_getClass([className UTF8String]));
	char *p = NULL;

	if(!imageName)
		return false;

	if(!(p = strrchr(imageName, '/')))
		return false;

	if(strncmp(imageName, [[[NSProcessInfo processInfo] arguments][0] UTF8String], p-imageName-1) == 0)
		return true;

	return false;
}

// A lot of methods are just wrapping pure C calls, which has the effect of exposing core iSpy features
// to Cycript for advanced use.
-(void) instance_enableTracking {
	bf_enable_instance_tracker();
}

-(void) instance_disableTracking {
	bf_disable_instance_tracker();
}

// Dumps a list of all the instances in the runtime, including all Apple's classes like NSString, etc. 
// Generates a ton of output.
// Human-readable text.
-(NSString *) instance_dumpAllInstancesWithPointers {
	struct bf_instance *p = bf_get_instance_list_ptr();
	NSString *instances = @"";

	while(p) {
		instances = [NSString stringWithFormat:@"%@\n%p => %s", instances, p->instance, p->name];
		p=p->next;
	}
	return instances;
}

// Returns a human-readable list of runtime class instances, restricted to application-defined classes.
// Dumps the corresponding pointers, too.
// You can then grab handles to instances in Cycript by using "x = new Instance(0xwhatever)" syntax.
-(NSString *) instance_dumpAppInstancesWithPointers {
	NSString *result = @"";
	for(NSArray *arr in [self instance_dumpAppInstancesWithPointersArray]) {
		result = [NSString stringWithFormat:@"%@%.10s => %s\n", result, [[arr objectAtIndex:1] UTF8String], [[arr objectAtIndex:0] UTF8String]];
	}
	return result;
}

// Returns a computer parsable array of runtime class instances, restricted to application-defined classes.
// [ {class_description, class_name}, {class_description, class_name}, ... ]
-(NSArray *) instance_dumpAppInstancesWithPointersArray {
	NSMutableArray *instances = [[NSMutableArray alloc] init];
	struct bf_instance *p = bf_get_instance_list_ptr();

	while(p) {
		if( p->name && p->instance && [iSpy isClassFromApp:[NSString stringWithUTF8String:p->name]] ) {
			[instances addObject:[NSArray arrayWithObjects:[NSString stringWithCString:p->name encoding:NSUTF8StringEncoding], [NSString stringWithFormat:@"%p", p->instance], nil]];
		}
		p=p->next;
	}

	return [instances copy];
}

-(NSDictionary *) instance_dumpAppInstancesWithPointersDict {
	NSMutableDictionary *instances = [[NSMutableDictionary alloc] init];
	struct bf_instance *p = bf_get_instance_list_ptr();

	while(p) {
		if( p->name && p->instance && [iSpy isClassFromApp:[NSString stringWithUTF8String:p->name]] ) {
			[instances setObject:[NSString stringWithFormat:@"%p", p->instance] forKey:[NSString stringWithCString:p->name encoding:NSUTF8StringEncoding]];
		}
		p=p->next;
	}

	return [instances copy];
}

// Does a brute-force search of the linked list of currently tracked instances.
// Returns the number of tracked instances.
-(int) instance_numberOfTrackedInstances {
	int i = 0;
	struct bf_instance *p = bf_get_instance_list_ptr();
	
	while(p) {
		p=p->next;
		i++;
	}
	return i;
}

-(void) instance_searchInstances:(NSString *)forName {
	return;
}

-(BOOL) instance_getTrackingState {
	return bf_get_instance_tracking_state();
}

// Turn on objc_msgSend logging
-(void) msgSend_enableLogging {
	bf_enable_msgSend_logging();
}

// Turn off objc_msgSend logging
-(void) msgSend_disableLogging {
	bf_disable_msgSend_logging();
}

// Return true/false depending on whether or not objc_msgSend logging is on or off
-(BOOL) msgSend_getLoggingState {
	return bf_get_msgSend_state();
}

// is the msgSend logging system ready to roll?
-(BOOL) msgSend_isInitialized {
	return bf_has_msgSend_initialized_yet();
}

-(void) strace_enableLogging {
	bf_set_log_state(true, LOG_STRACE);
}

-(void) strace_disableLogging {
	bf_set_log_state(false, LOG_STRACE);
}

-(BOOL) strace_getLoggingState {
	return bf_get_log_state(LOG_STRACE);
}

-(void) http_enableLogging {
	bf_set_log_state(true, LOG_HTTP);
}

-(void) http_disableLogging {
	bf_set_log_state(false, LOG_HTTP);
}

-(void) tcpip_enableLogging {
	bf_set_log_state(true, LOG_TCPIP);
}

-(void) tcpip_disableLogging {
	bf_set_log_state(false, LOG_TCPIP);
}

-(void) log_setGeneralLogState:(BOOL)state {
	bf_set_log_state(state, LOG_GENERAL);
}

-(void) log_setStraceLogState:(BOOL)state {
	bf_set_log_state(state, LOG_STRACE);
}

-(void) log_setHTTPLogState:(BOOL)state {
	bf_set_log_state(state, LOG_HTTP);
}

-(void) log_setTCPIPLogState:(BOOL)state {
	bf_set_log_state(state, LOG_TCPIP);
}

-(void) log_setMsgSendLogState:(BOOL)state {
	bf_set_log_state(state, LOG_MSGSEND);
}

-(void) log_setLogState:(BOOL)state forLog:(int)facility {
	bf_set_log_state(state, facility);   
}

-(NSDictionary *) getSymbolTable {
	return nil;
}

-(unsigned int) getMachFlags {
	return 0;
	/*
	sqlite3_stmt *stmt;
	iSpy *mySpy = [iSpy sharedInstance];
	unsigned int flags;

	sqlite3_prepare_v2([[mySpy db] handle], "SELECT flags FROM machFlags", -1, &stmt, NULL);
	if(sqlite3_step(stmt) == SQLITE_ROW)
		flags = (unsigned int)sqlite3_column_int(stmt, 0);
	else
		flags = 0xffffffff;
	sqlite3_finalize(stmt);
	return flags;
	*/
}


-(NSDictionary *)keyChainItems {
	NSMutableDictionary *genericQuery = [[NSMutableDictionary alloc] init];
	NSMutableDictionary *keychainDict = [[NSMutableDictionary alloc] init];
	// genp, inet, idnt, cert, keys
	NSArray *items = [NSArray arrayWithObjects:(id)kSecClassGenericPassword, kSecClassInternetPassword, kSecClassIdentity, kSecClassCertificate, kSecClassKey, nil];
	int i = 0, j, count;

	count = [items count];
	do {
		NSMutableArray *keychainItems = nil;
		NSLog(@"[iSpy] Area: %@", [items objectAtIndex:i]);
		[genericQuery setObject:(id)[items objectAtIndex:i] forKey:(id)kSecClass];
		[genericQuery setObject:(id)kSecMatchLimitAll forKey:(id)kSecMatchLimit];
		[genericQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnAttributes];
		[genericQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnRef];
		[genericQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];

		if (SecItemCopyMatching((CFDictionaryRef)genericQuery, (CFTypeRef *)&keychainItems) != noErr)
			continue;

		// NSJSONSerializer won't parse NSDate or NSData, so we convert any of those into NSString for later JSON-ification.
		for(j = 0; j < [keychainItems count]; j++) {
			NSLog(@"Data: %@", [keychainItems objectAtIndex:j]);
			for(NSString *key in [[keychainItems objectAtIndex:j] allKeys]) {
				// We don't need the v_Ref attribute; it's just an obkect representation of a cert, which we already have.
				if([key isEqual:@"v_Ref"])
				   [[keychainItems objectAtIndex:j] removeObjectForKey:key];

				// Is this some kind of NSData/__NSFSData/etc?
				else if([[[keychainItems objectAtIndex:j] objectForKey:key] respondsToSelector:@selector(bytes)]) {
					NSString *str = [[NSString alloc] initWithData:[[keychainItems objectAtIndex:j] objectForKey:key] encoding:NSUTF8StringEncoding];
					if(str == nil)
						str = @"";
					[[keychainItems objectAtIndex:j] setObject:str forKey:key];
				}

				// how about NSDate?
				else if([[[keychainItems objectAtIndex:j] objectForKey:key] respondsToSelector:@selector(isEqualToDate:)]) {
					[[keychainItems objectAtIndex:j] setObject:changeDateToDateString([[keychainItems objectAtIndex:j] objectForKey:key]) forKey:key];
				}

				NSLog(@"Data: %@ (class: %@) = %@", key, [[[keychainItems objectAtIndex:j] objectForKey:key] class], [[keychainItems objectAtIndex:j] objectForKey:key]);
			}
		}
		[keychainDict setObject:keychainItems forKey:[items objectAtIndex:i]];
	} while(++i < count);

	return [keychainDict copy];
}

-(unsigned int)ASLR {
	return (unsigned int)_dyld_get_image_vmaddr_slide(0);
}




/*
Returns a NSDictionary like this:
{
	"name" = "doSomething:forString:withChars:",

	"parameters" = { 
		// name = type
		"arg1" = "id",
		"arg2" = "NSString *",
		"arg3" = "char *"        
	},

	"returnType" = "void";
}
*/

-(id)testMethodThing {
	return [self iVarsForClass:@"NSString"];
}

-(NSDictionary *)infoForMethod:(SEL)selector inClass:(Class)cls {
	return [self infoForMethod:selector inClass:cls isInstanceMethod:1];
}

-(NSDictionary *)infoForMethod:(SEL)selector inClass:(Class)cls isInstanceMethod:(BOOL)isInstance {
	Method method = nil;
	BOOL isInstanceMethod = true;
	NSMutableArray *parameters = [[NSMutableArray alloc] init];
	NSMutableDictionary *methodInfo = [[NSMutableDictionary alloc] init];
	int numArgs, k;
	NSString *returnType;
	char *freeMethodName, *methodName, *tmp; 

	if(cls == NULL || selector == NULL || cls == nil || selector == nil)
		return nil;

	if([cls instancesRespondToSelector:selector] == YES) {
		method = class_getInstanceMethod(cls, selector);
	} else if([object_getClass(cls) respondsToSelector:selector] == YES) {
		method = class_getClassMethod(object_getClass(cls), selector);
		isInstanceMethod = false;
	} else {
		return nil;
	}

	if(method == nil)
		return nil;    

	numArgs = method_getNumberOfArguments(method);

	// get the method's name as a (char *)
	freeMethodName = methodName = (char *)strdup(sel_getName(method_getName(method)));
	
	// cycle through the paramter list for this method.
	// start at k=2 so that we omit Cls and SEL, the first 2 args of every function/method
	for(k=2; k < numArgs; k++) {
		char tmpBuf[256]; // safe and reasonable limit on var name length
		char *type;
		char *name;
		NSMutableDictionary *param = [[NSMutableDictionary alloc] init];

		name = strsep(&methodName, ":");
		if(!name) {
			ispy_log_debug(LOG_GENERAL, "um, so p=NULL in arg printer for class methods... weird.");
			continue;
		}

		method_getArgumentType(method, k, tmpBuf, 255);
	
		if((type = (char *)bf_get_type_from_signature(tmpBuf))==NULL) {
			ispy_log_debug(LOG_GENERAL, "Out of mem");
			break;
		}

		[param setObject:[NSString stringWithUTF8String:type] forKey:@"type"];
		[param setObject:[NSString stringWithUTF8String:name] forKey:@"name"];
		[parameters addObject:param];
		free(type);
	} // args   
	
	tmp = (char *)bf_get_friendly_method_return_type(method);

	if(!tmp)
		returnType = @"XXX_unknown_type_XXX";
	else {
		returnType = [NSString stringWithUTF8String:tmp];
		free(tmp);
	}
	
	[methodInfo setObject:parameters forKey:@"parameters"];
	[methodInfo setObject:returnType forKey:@"returnType"];
	[methodInfo setObject:[NSString stringWithUTF8String:freeMethodName] forKey:@"name"];
	[methodInfo setObject:[NSNumber numberWithInt:isInstanceMethod] forKey:@"isInstanceMethod"];
	free(freeMethodName);
	
	return [methodInfo copy];
}

-(id)iVarsForClass:(NSString *)className {
	unsigned int iVarCount = 0, j;
	Ivar *ivarList = class_copyIvarList(objc_getClass([className UTF8String]), &iVarCount);
	NSMutableArray *iVars = [[NSMutableArray alloc] init];

	if(!ivarList)
		return nil; //[iVars copy];

	for(j = 0; j < iVarCount; j++) {
		NSMutableDictionary *iVar = [[NSMutableDictionary alloc] init];

		char *name = (char *)ivar_getName(ivarList[j]);
		char *type = bf_get_type_from_signature((char *)ivar_getTypeEncoding(ivarList[j]));
		[iVar setObject:[NSString stringWithUTF8String:type] forKey:[NSString stringWithUTF8String:name]];
		[iVars addObject:iVar];
		free(type);
	}
	return [iVars copy];
}

-(id)propertiesForClass:(NSString *)className {
	unsigned int propertyCount = 0, j;
	objc_property_t *propertyList = class_copyPropertyList(objc_getClass([className UTF8String]), &propertyCount);
	NSMutableArray *properties = [[NSMutableArray alloc] init];

	if(!propertyList)
		return nil; //[properties copy];

	for(j = 0; j < propertyCount; j++) {
		NSMutableDictionary *property = [[NSMutableDictionary alloc] init];

		char *name = (char *)property_getName(propertyList[j]);
		char *attr = bf_get_attrs_from_signature((char *)property_getAttributes(propertyList[j])); 
		[property setObject:[NSString stringWithUTF8String:attr] forKey:[NSString stringWithUTF8String:name]];
		[properties addObject:property];
		free(attr);
	}
	return [properties copy];
}

-(id)propertiesForProtocol:(Protocol *)protocol {
	unsigned int propertyCount = 0, j;
	objc_property_t *propertyList = protocol_copyPropertyList(protocol, &propertyCount);
	NSMutableArray *properties = [[NSMutableArray alloc] init];

	if(!propertyList)
		return properties;

	for(j = 0; j < propertyCount; j++) {
		NSMutableDictionary *property = [[NSMutableDictionary alloc] init];

		char *name = (char *)property_getName(propertyList[j]);
		char *attr = bf_get_attrs_from_signature((char *)property_getAttributes(propertyList[j])); 
		[property setObject:[NSString stringWithUTF8String:attr] forKey:[NSString stringWithUTF8String:name]];
		[properties addObject:property];
		free(attr);
	}
	return [properties copy];
}

-(id)methodsForProtocol:(Protocol *)protocol {
	BOOL isReqVals[4] =      {NO, NO,  YES, YES};
	BOOL isInstanceVals[4] = {NO, YES, NO,  YES};
	unsigned int methodCount;
	NSMutableArray *methods = [[NSMutableArray alloc] init];
	
	for( int i = 0; i < 4; i++ ){
		struct objc_method_description *methodDescriptionList = protocol_copyMethodDescriptionList(protocol, isReqVals[i], isInstanceVals[i], &methodCount);
		if(!methodDescriptionList)
			continue;

		if(methodCount <= 0) {
			free(methodDescriptionList);
			continue;
		}

		NSMutableDictionary *methodInfo = [[NSMutableDictionary alloc] init];
		for(int j = 0; j < methodCount; j++) {
			NSArray *types = ParseTypeString([NSString stringWithUTF8String:methodDescriptionList[j].types]);
			[methodInfo setObject:[NSString stringWithUTF8String:sel_getName(methodDescriptionList[j].name)] forKey:@"methodName"];
			[methodInfo setObject:[types objectAtIndex:0] forKey:@"returnType"];
			[methodInfo setObject:((isReqVals[i]) ? @"1" : @"0") forKey:@"required"];
			[methodInfo setObject:((isInstanceVals[i]) ? @"1" : @"0") forKey:@"instance"];

			NSMutableArray *params = [[NSMutableArray alloc] init];
			if([types count] > 3) {  // return_type, class, selector, ...
				NSRange range;
				range.location = 3;
				range.length = [types count]-3;
				[params addObject:[types subarrayWithRange:range]];
			}
			[methodInfo setObject:params forKey:@"parameters"];
		}

		[methods addObject:methodInfo];

		free(methodDescriptionList);
	}
	return [methods copy];
}

-(id)protocolsForClass:(NSString *)className {
	unsigned int protocolCount = 0, j;
	Protocol **protocols = class_copyProtocolList(objc_getClass([className UTF8String]), &protocolCount);
	NSMutableArray *protocolList = [[NSMutableArray alloc] init];

	if(protocolCount <= 0)
		return protocolList;

	// some of this code was inspired by (and a little of it is copy/pasta) https://gist.github.com/markd2/5961219
	for(j = 0; j < protocolCount; j++) {
		NSMutableArray *adoptees;
		NSMutableDictionary *protocolInfoDict = [[NSMutableDictionary alloc] init];
		const char *protocolName = protocol_getName(protocols[j]); 
		unsigned int adopteeCount;
		Protocol **adopteesList = protocol_copyProtocolList(protocols[j], &adopteeCount);
	
		adoptees = [[NSMutableArray alloc] init];
		for(int i = 0; i < adopteeCount; i++) {
			const char *adopteeName = protocol_getName(adopteesList[i]);
			if(!adopteeName)
				continue; // skip broken names
			[adoptees addObject:[NSString stringWithUTF8String:adopteeName]];
		}
		free(adopteesList);

		[protocolInfoDict setObject:[NSString stringWithUTF8String:protocolName] forKey:@"protocolName"];
		[protocolInfoDict setObject:adoptees forKey:@"adoptees"];
		[protocolInfoDict setObject:[self propertiesForProtocol:protocols[j]] forKey:@"properties"];
		[protocolInfoDict setObject:[self methodsForProtocol:protocols[j]] forKey:@"methods"];
		 
		[protocolList addObject:protocolInfoDict];
	}
	free(protocols);
	return [protocolList copy];
}

-(NSDictionary *)protocolDump {
	unsigned int protocolCount = 0, j;
	Protocol **protocols = objc_copyProtocolList(&protocolCount);
	NSMutableDictionary *protocolList = [[NSMutableDictionary alloc] init];

	if(protocolCount <= 0)
		return protocolList;

	// some of this code was inspired by (and a little of it is copy/pasta) https://gist.github.com/markd2/5961219
	for(j = 0; j < protocolCount; j++) {
		NSMutableArray *adoptees;
		NSMutableDictionary *protocolInfoDict = [[NSMutableDictionary alloc] init];
		const char *protocolName = protocol_getName(protocols[j]); 
		unsigned int adopteeCount;
		Protocol **adopteesList = protocol_copyProtocolList(protocols[j], &adopteeCount);

		if(!adopteeCount) {
			free(adopteesList);
			continue;
		}
	
		adoptees = [[NSMutableArray alloc] init];
		for(int i = 0; i < adopteeCount; i++) {
			const char *adopteeName = protocol_getName(adopteesList[i]);

			if(!adopteeName) {
				free(adopteesList);
				continue; // skip broken names or shit we don't care about
			}
			[adoptees addObject:[NSString stringWithUTF8String:adopteeName]];
		}
		free(adopteesList);

		[protocolInfoDict setObject:[NSString stringWithUTF8String:protocolName] forKey:@"protocolName"];
		[protocolInfoDict setObject:adoptees forKey:@"adoptees"];
		[protocolInfoDict setObject:[self propertiesForProtocol:protocols[j]] forKey:@"properties"];
		[protocolInfoDict setObject:[self methodsForProtocol:protocols[j]] forKey:@"methods"];
		 
		[protocolList setObject:protocolInfoDict forKey:[NSString stringWithUTF8String:protocolName]];
	}
	free(protocols);
	return (NSDictionary *)[protocolList copy];
}


-(id)methodsForClass:(NSString *)className {
	unsigned int numClassMethods = 0;
	unsigned int numInstanceMethods = 0;
	unsigned int i;
	NSMutableArray *methods = [[NSMutableArray alloc] init];
	Class c;
	char *classNameUTF8;
	Method *classMethodList = NULL;
	Method *instanceMethodList = NULL;
	
	if(!className)
		return nil; //[methods copy];

	if((classNameUTF8 = (char *)[className UTF8String]) == NULL)
		return nil; //[methods copy];

	Class cls = objc_getClass(classNameUTF8);
	if(cls == nil)
		return nil; //[methods copy];
	
	c = object_getClass(cls);
	if(c)
		classMethodList = class_copyMethodList(c, &numClassMethods);
	else
		numClassMethods = 0;
	instanceMethodList  = class_copyMethodList(cls, &numInstanceMethods);
	
	if(classMethodList != NULL) {
		for(i = 0; i < numClassMethods; i++) {
			SEL sel = method_getName(classMethodList[i]);
			if(!sel)
				continue;
			NSDictionary *methodInfo = [self infoForMethod:sel inClass:cls];
			if(methodInfo != nil)
				[methods addObject:methodInfo];    
		}
		free(classMethodList);
	}

	if(instanceMethodList != NULL) {
		for(i = 0; i < numInstanceMethods; i++) {
			SEL sel = method_getName(instanceMethodList[i]);
			if(!sel)
				continue;
			NSDictionary *methodInfo = [self infoForMethod:sel inClass:cls];
			if(methodInfo != nil)
				[methods addObject:methodInfo];    
		}
		free(instanceMethodList);
	}
	return [methods copy];
}

-(id)classes {
	Class * classes = NULL;
	NSMutableArray *classArray = [[NSMutableArray alloc] init];
	int numClasses;

	numClasses = objc_getClassList(NULL, 0);
	if(numClasses <= 0)
		return nil; //[classArray copy]; 
	
	if((classes = (Class *)malloc(sizeof(Class) * numClasses)) == NULL)
		return [classArray copy];
	
	objc_getClassList(classes, numClasses);
	
	int i=0;
	while(i < numClasses) {
		NSString *className = [NSString stringWithUTF8String:class_getName(classes[i])];
		if([iSpy isClassFromApp:className])
			[classArray addObject:className];
		i++;
	}
	return [classArray copy];  
}

-(id)classesWithSuperClassAndProtocolInfo {
	Class * classes = NULL;
	NSMutableArray *classArray = [[NSMutableArray alloc] init];
	int numClasses;
	unsigned int numProtocols;

	numClasses = objc_getClassList(NULL, 0);
	if(numClasses <= 0)
		return nil; //[classArray copy]; 
	
	if((classes = (Class *)malloc(sizeof(Class) * numClasses)) == NULL)
		return [classArray copy];
	
	objc_getClassList(classes, numClasses);
	
	int i=0;
	while(i < numClasses) {
		NSString *className = [NSString stringWithUTF8String:class_getName(classes[i])];
		NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

		if([iSpy isClassFromApp:className]) {
			Protocol **protocols = class_copyProtocolList(classes[i], &numProtocols);
			Class superClass = class_getSuperclass(classes[i]);
			char *superClassName = NULL;

			if(superClass)
				superClassName = (char *)class_getName(superClass);

			[dict setObject:className forKey:@"className"];
			[dict setObject:[NSString stringWithUTF8String:superClassName] forKey:@"superClass"];

			NSMutableArray *pr = [[NSMutableArray alloc] init];
			if(numProtocols) {
				for(int i = 0; i < numProtocols; i++) {
					[pr addObject:[NSString stringWithUTF8String:protocol_getName(protocols[i])]];
				}
				free(protocols);
			}
			[dict setObject:pr forKey:@"protocols"];
			[classArray addObject:dict];
		}
		i++;
	}
	return [classArray copy];   
}

/*
{
	"MyClass1": {
		"className": "MyClass1",
		"superClass": "class name",
		"methods": {
			
		},
		"ivars": {
			
		},
		"properties": {

		},
		"protocols": {

		}
	},
	"MyClass2": {
		"methods": {
			
		},
		"ivars": {
			
		},
		"properties": {

		},
		"protocols": {

		}
	},
	...
}
*/
-(NSDictionary *)classDump {
	NSMutableDictionary *classDumpDict = [[NSMutableDictionary alloc] init];
	NSArray *clsList = [self classesWithSuperClassAndProtocolInfo]; // returns an array of dictionaries
	
	NSLog(@"[iSpy] Got %d classes", [clsList count]);
	for(int i = 0; i < [clsList count]; i++) {
		NSMutableDictionary *cls = [[clsList objectAtIndex:i] mutableCopy];
		NSString *className = [cls objectForKey:@"className"];

		[cls setObject:[NSArray arrayWithArray:[self methodsForClass:className]]     forKey:@"methods"];
		[cls setObject:[NSArray arrayWithArray:[self iVarsForClass:className]]       forKey:@"ivars"];
		[cls setObject:[NSArray arrayWithArray:[self propertiesForClass:className]]  forKey:@"properties"];
		[cls setObject:[NSArray arrayWithArray:[self methodsForClass:className]]     forKey:@"methods"];
		[classDumpDict setObject:[NSDictionary dictionaryWithDictionary:cls] forKey:className];
		[cls release];
	}

	return [classDumpDict copy];
}

-(NSDictionary *)classDumpClass:(NSString *)className {
	NSMutableDictionary *cls = [[NSMutableDictionary alloc] init];
	Class theClass = objc_getClass([className UTF8String]);
	unsigned int numProtocols;

	Class superClass = class_getSuperclass(theClass);
	char *superClassName = NULL;

	if(superClass)
		superClassName = (char *)class_getName(superClass);

	Protocol **protocols = class_copyProtocolList(theClass, &numProtocols);
	NSMutableArray *pr = [[NSMutableArray alloc] init];
	if(numProtocols) {
		for(int i = 0; i < numProtocols; i++) {
			[pr addObject:[NSString stringWithUTF8String:protocol_getName(protocols[i])]];
		}
		free(protocols);
	}
	[cls setObject:pr 															 forKey:@"protocols"];
	[cls setObject:className 													 forKey:@"className"];
	[cls setObject:[NSString stringWithUTF8String:superClassName]				 forKey:@"superClass"];
	[cls setObject:[NSArray arrayWithArray:[self methodsForClass:className]]     forKey:@"methods"];
	[cls setObject:[NSArray arrayWithArray:[self iVarsForClass:className]]       forKey:@"ivars"];
	[cls setObject:[NSArray arrayWithArray:[self propertiesForClass:className]]  forKey:@"properties"];
	[cls setObject:[NSArray arrayWithArray:[self methodsForClass:className]]     forKey:@"methods"];

	return (NSDictionary *)[cls copy];
}

-(NSString *)SHA256HMACForAppBinary {
	NSString *fileName = [[[NSProcessInfo processInfo] arguments] objectAtIndex:0];
	NSString *HMAC = SHA256HMAC([NSData dataWithContentsOfFile:fileName]);
	NSLog(@"[iSpy] HMAC: %@", HMAC);
	return HMAC;
}


-(id)instance_atAddress:(NSString *)addr {
	// Given a string in the format @"0xdeadbeef", this first converts the string to an address, then
	// returns an opaque Objective-C object at that address.
	// The runtime can treat this return value just like any other object.
	// BEWARE: give this an incorrect/invalid address and you'll return a duff pointer. Caveat emptor.
	return (id)strtoul([addr UTF8String], (char **)NULL, 16);
}

// Given a hex address (eg. 0xdeafbeef) dumps the class data from the object at that address.
// Returns an object as discussed in instance_dumpInstance, below.
// This is exposed to /api/instance/0xdeadbeef << replace deadbeef with an actual address.
-(id)instance_dumpInstanceAtAddress:(NSString *)addr {
	return [self instance_dumpInstance:[self instance_atAddress:addr]];
}

// Make sure to pass a valid pointer (instance) to this method!
// In return it'll give you an array. Each element in the array represents an iVar and comprises a dictionary.
// Each element in the dictionary represents the name, type, and value of the iVar.
-(id)instance_dumpInstance:(id)instance {
	void *ptr;
	NSArray *iVars = [self iVarsForClass:[NSString stringWithUTF8String:object_getClassName(instance)]];
	int i;
	NSMutableArray *iVarData = [[NSMutableArray alloc] init];

	for(i=0; i< [iVars count]; i++) {
		NSDictionary *iVar = [iVars objectAtIndex:i];
		NSEnumerator *e = [iVar keyEnumerator];
		id key;

		while((key = [e nextObject])) {
			NSMutableDictionary *iVarInfo = [[NSMutableDictionary alloc] init];
			[iVarInfo setObject:key forKey:@"name"];
			
			object_getInstanceVariable(instance, [key UTF8String], &ptr );
			
			// Retarded check alert!
			// The logic goes like this. All parameter types have a style guide. 
			// e.g. If the type of argument we're examining is an Objective-C class, the first letter of its name
			// will be a capital letter. We can dump these with ease using the Objective-C runtime.
			// Similarly, anything from the C world should have a lower case first letter.
			// Now, we can easily leverage the Objective-C runtime to dump class data. but....
			// The C environment ain't so easy. Easy stuff is booleans (just a "char") or ints. 
			// Of course we could dump strings (char*) too, but we need to write code to handle that.
			// As iSpy matures we'll do just that. Meantime, you'll get (a) the type of the var you're looking at,
			// (b) a pointer to that var. Do as you please with it. BOOLs (really just chars) are already taken care of as an example
			// of how to deal with this shit. 
			char *type = (char *)[[iVar objectForKey:key] UTF8String];
			
			if(islower(*type)) {
				char *boolVal = (char *)ptr;
				if(strcmp(type, "char") == 0) {
					[iVarInfo setObject:@"BOOL" forKey:@"type"];
					[iVarInfo setObject:[NSString stringWithFormat:@"%d", (int)boolVal&0xff] forKey:@"value"];
				} else {
					[iVarInfo setObject:[iVar objectForKey:key] forKey:@"type"];
					[iVarInfo setObject:[NSString stringWithFormat:@"[%s] pointer @ %p", type, ptr] forKey:@"value"];
				}
			} else {
				// This is likely to be an Objective-C class. Hey, what's the worst that could happen if it's not?
				// That would be a segfault. Signal 11. Do not pass go, do not collect a stack trace.
				// This is a shady janky-ass mofo of a function. 
				[iVarInfo setObject:[iVar objectForKey:key] forKey:@"type"];
				[iVarInfo setObject:[NSString stringWithFormat:@"%@", ptr] forKey:@"value"];
			}
			[iVarData addObject:iVarInfo];
			[iVarInfo release];
		}
	}

	return [iVarData copy];
}

/*-(void) bounceWebServer {
    ispy_log_debug(LOG_GENERAL, "Bouncing webserver...");
    iSpyServer *selfHTTP = [self webServer];
    [selfHTTP dealloc];
    selfHTTP = nil;
    sleep(2);
    [[self webServer] configureWebServer];
    [[self webServer] startWebServices];
    ispy_log_debug(LOG_GENERAL, "Bounce done.");
}*/

@end


/***********************************************************************************************
 * These are private functions that aren't intended to be exposed to iSpy class and/or Cycript *
 ***********************************************************************************************/

static NSString *changeDateToDateString(NSDate *date) {
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
	NSString *dateString = [dateFormatter stringFromDate:date];
	if(dateString == nil)
		return @"Bad date.";
	return dateString;
}

// The caller is responsible for calling free() on the pointer returned by this function.
static char *bf_get_type_from_signature(char *typeStr) {
	NSArray *types = ParseTypeString([NSString stringWithUTF8String:typeStr]);
	NSString *result = [[types valueForKey:@"description"] componentsJoinedByString:@" "];
	return (char *)strdup([result UTF8String]);
}

/*
	Returns the human-friendly return type for the method specified.
	Eg. "void" or "char *" or "id", etc.
	The caller must free() the buffer returned by this func.
*/
static char *bf_get_friendly_method_return_type(Method method) {
	// Here, I'll paste from the Apple docs:
	//      "The method's return type string is copied to dst. dst is filled as if strncpy(dst, parameter_type, dst_len) were called."
	// Um, ok... but how big does my destination buffer need to be?
	char tmpBuf[1024];
	
	// Does it pad with a NULL? Jeez. *shakes fist in Apple's general direction*
	memset(tmpBuf, 0, 1024);
	method_getReturnType(method, tmpBuf, 1023);
	return bf_get_type_from_signature(tmpBuf);
}

// based on code from https://gist.github.com/markd2/5961219
// The caller must free the returned pointer.
static char *bf_get_attrs_from_signature(char *attributeCString) {
	NSString *attributeString = @( attributeCString );
	NSArray *chunks = [attributeString componentsSeparatedByString: @","];
	NSMutableArray *translatedChunks = [NSMutableArray arrayWithCapacity: chunks.count];
	char *subChunk, *type;

	NSString *string;

	for (NSString *chunk in chunks) {
		unichar first = [chunk characterAtIndex: 0];

		switch (first) {
			case 'T': // encode type. @ has class name after it
				subChunk = (char *)[[chunk substringFromIndex: 1] UTF8String];
				type = bf_get_type_from_signature(subChunk);
				break;
			case 'V': // backing ivar name
				//string = [NSString stringWithFormat: @"ivar: %@", [chunk substringFromIndex: 1]];
				//[translatedChunks addObject: string];
				break;
			case 'R': // read-only
				[translatedChunks addObject: @"readonly"];
				break;
			case 'C': // copy
				[translatedChunks addObject: @"copy"];
				break;
			case '&': // retain
				[translatedChunks addObject: @"retain"];
				break;
			case 'N': // non-atomic
				[translatedChunks addObject: @"non-atomic"];
				break;
			case 'G': // custom getter
				string = [NSString stringWithFormat: @"getter: %@",[chunk substringFromIndex: 1]];
				[translatedChunks addObject: string];
				break;
			case 'S': // custom setter
				string = [NSString stringWithFormat: @"setter: %@", [chunk substringFromIndex: 1]];
				[translatedChunks addObject: string];
				break;
			case 'D': // dynamic
				[translatedChunks addObject: @"dynamic"];
				break;
			case 'W': // weak
				[translatedChunks addObject: @"__weak"];
				break;
			case 'P': // eligible for GC
				[translatedChunks addObject: @"GC"];
				break;
			case 't': // old-style encoding
				[translatedChunks addObject: chunk];
				break;
			default:
				[translatedChunks addObject: chunk];
				break;
		}
	}
	NSString *result = [NSString stringWithFormat:@"(%@) %s", [translatedChunks componentsJoinedByString: @", "], type];

	return strdup([result UTF8String]);
}

/*
	This incorporates code originally from http://doxygen.asterisk.org/asterisk1.0/dlfcn_8c.html
	It's been tweaked to fit this purpose.
*/
/*
static void bf_enumerate_symbol_table() {
	unsigned long i;
	unsigned long j;
	struct mach_header *mh = 0;
	struct load_command *lc = 0;
	unsigned long table_off = (unsigned long)0;
	unsigned int vmAddrSlide;
	unsigned int flags;
	char* errorMessage;
	iSpy *mySpy = [iSpy sharedInstance];
	sqlite3 *dbHandle = [[mySpy db] handle];
	sqlite3_stmt *stmt;

	// prep for speed
	sqlite3_exec(dbHandle, "PRAGMA synchronous=OFF", NULL, NULL, &errorMessage);
	sqlite3_exec(dbHandle, "PRAGMA count_changes=OFF", NULL, NULL, &errorMessage);
	sqlite3_exec(dbHandle, "PRAGMA journal_mode=MEMORY", NULL, NULL, &errorMessage);
	sqlite3_exec(dbHandle, "PRAGMA temp_store=MEMORY", NULL, NULL, &errorMessage);
	sqlite3_exec(dbHandle, "BEGIN TRANSACTION", NULL, NULL, &errorMessage);
	sqlite3_prepare_v2(dbHandle, "INSERT INTO symbols (name, offset, n_stab, n_pext, n_ext, n_pbud, n_indr, n_arm, type) VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)", -1, &stmt, NULL);

	// Grab the ASLR slide info
	vmAddrSlide = (unsigned int)_dyld_get_image_vmaddr_slide(0);
	ispy_log_debug(LOG_GENERAL, "ASLR slide = 0x%x", vmAddrSlide);

	// Find the __LINKEDIT segment of the Mach-O header in memory
	mh = (struct mach_header *)_dyld_get_image_header(0);
	
	// cache a copy of the Mach-O header flags for later
	flags = mh->flags;
	
	// find the relevant load command and segment name
	lc = (struct load_command *)((char *)mh + sizeof(struct mach_header));
	for (j = 0; j < mh->ncmds; j++, lc = (struct load_command *)((char *)lc + lc->cmdsize)) {
		if (LC_SEGMENT == lc->cmd) {
			if (!strcmp(((struct segment_command *)lc)->segname, "__LINKEDIT"))
				break;
		}
	}
	
	if(strcmp(((struct segment_command *)lc)->segname, "__LINKEDIT"))
		return;

	ispy_log_debug(LOG_GENERAL, "Found __LINKEDIT");

	// Calculate the offset to the Load Commands
	table_off =
		((unsigned long)((struct segment_command *)lc)->vmaddr) -
		((unsigned long)((struct segment_command *)lc)->fileoff) + vmAddrSlide;

	ispy_log_debug(LOG_GENERAL, "Table offset = 0x%x", table_off);

	// Find the Load Command(s) for the symbol table(s)
	lc = (struct load_command *)((char *)mh + sizeof(struct mach_header));
	for (j = 0; j < mh->ncmds; j++, lc = (struct load_command *)((char *)lc + lc->cmdsize)) {
		
		// Is this a symbol table?
		if(LC_SYMTAB == lc->cmd) {
			struct nlist *symtable = (struct nlist *)(((struct symtab_command *)lc)->symoff + table_off);
			unsigned long numsyms = ((struct symtab_command *)lc)->nsyms;
			unsigned long strtable = (unsigned long)(((struct symtab_command *)lc)->stroff + table_off);
			
			// Loop through each entry in the symbol table, dumping all the things
			for (i = 0; i < numsyms; i++) {
				if(symtable) {
					if(strlen((char *)(strtable + symtable->n_un.n_strx))) {                        
						unsigned int type = (unsigned int)symtable->n_type;
						sqlite3_bind_text(stmt, 1, (char *)(strtable + symtable->n_un.n_strx), strlen((char *)(strtable + symtable->n_un.n_strx)), SQLITE_STATIC);
						sqlite3_bind_int(stmt, 2, (int)symtable->n_value);
						sqlite3_bind_int(stmt, 3, (int)(type & N_STAB) ? 1 : 0);
						sqlite3_bind_int(stmt, 4, (int)(type & N_PEXT) ? 1 : 0);
						sqlite3_bind_int(stmt, 5, (int)(type & N_EXT) ? 1 : 0);
						sqlite3_bind_int(stmt, 6, (int)(type & N_PBUD) ? 1 : 0);
						sqlite3_bind_int(stmt, 7, (int)(type & N_INDR) ? 1 : 0);
						sqlite3_bind_int(stmt, 8, (int)(type & N_ARM_THUMB_DEF) ? 1 : 0);
						sqlite3_bind_int(stmt, 9, (int)type);
						sqlite3_step(stmt);
						sqlite3_reset(stmt);
					}
				}
				symtable++;
			}
		}
	}
	sqlite3_exec(dbHandle, "COMMIT TRANSACTION", NULL, NULL, &errorMessage);
	sqlite3_finalize(stmt);
	sqlite3_prepare_v2(dbHandle, "INSERT INTO machFlags (flags) VALUES(?1)", -1, &stmt, NULL);
	sqlite3_bind_int(stmt, 1, (int)flags);
	sqlite3_step(stmt);
	sqlite3_finalize(stmt);
	return;
}
*/

EXPORT NSString *base64forData(NSData *theData) {
	const uint8_t* input = (const uint8_t*)[theData bytes];
	NSInteger length = [theData length];

	static char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";

	NSMutableData* data = [NSMutableData dataWithLength:((length + 2) / 3) * 4];
	uint8_t* output = (uint8_t*)data.mutableBytes;

	NSInteger i;
	for (i=0; i < length; i += 3) {
		NSInteger value = 0;
		NSInteger j;
		for (j = i; j < (i + 3); j++) {
			value <<= 8;

			if (j < length) {
				value |= (0xFF & input[j]);
			}
		}

		NSInteger theIndex = (i / 3) * 4;
		output[theIndex + 0] =                    table[(value >> 18) & 0x3F];
		output[theIndex + 1] =                    table[(value >> 12) & 0x3F];
		output[theIndex + 2] = (i + 1) < length ? table[(value >> 6)  & 0x3F] : '=';
		output[theIndex + 3] = (i + 2) < length ? table[(value >> 0)  & 0x3F] : '=';
	}

	return [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease];
}

NSString *SHA256HMAC(NSData *theData) {
    const char *cKey  = (const char *)"This is a hardcoded but unimportant key. Don't do this at home.";
    unsigned char *cData = (unsigned char *)[theData bytes];
    unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH+1];
    
    if(!cData) {
    	NSLog(@"[iSpy] Error with theData in SHA256HMAC");
    	return nil;
    }
    memset(cHMAC, 0, sizeof(cHMAC));
    CCHmac(kCCHmacAlgSHA256, cKey, strlen(cKey), cData, [theData length], cHMAC);

    NSMutableString *result = [[NSMutableString alloc] init];
    for (int i = 0; i < sizeof(cHMAC); i++) {
        [result appendFormat:@"%02hhx", cHMAC[i]];
    }

    return [result copy];
}
