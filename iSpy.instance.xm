#include <pthread.h>
#include "iSpy.common.h"
#include "iSpy.class.h"
#include "iSpy.instance.h"

id (*orig_class_createInstance)(Class cls, size_t extraBytes);
id (*orig_object_dispose)(id obj);
extern void bf_MSHookFunction(void *func, void *repl, void **orig);

@implementation InstanceTracker

+(InstanceTracker *) sharedInstance {
	static InstanceTracker *sharedInstance;
	static dispatch_once_t once;
	static InstanceMap_t instanceMap;

	dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setEnabled:false];
		[sharedInstance installHooks];
		[sharedInstance setInstanceMap:&instanceMap];
		[[iSpy sharedInstance] setInstanceTracker:sharedInstance];
	});

	return sharedInstance;
}

-(void) installHooks {
	ispy_log_debug(LOG_GENERAL, "Hooking Objective-C class create/dispose functions...");
	bf_MSHookFunction((void *)class_createInstance, (void *)bf_class_createInstance, (void **)&orig_class_createInstance);
	bf_MSHookFunction((void *)object_dispose, (void *)bf_object_dispose, (void **)&orig_object_dispose);
	ispy_log_debug(LOG_GENERAL, "Done.");
}

-(void) start {
	[self clear];
	[self setEnabled:true];
}

-(void) stop {
	[self setEnabled:false];
}

-(void) clear {
	InstanceMap_t *instanceMap = [self instanceMap];
	(*instanceMap).clear();
}

-(NSArray *) instancesOfAllClasses {
	InstanceMap_t *instanceMap = [self instanceMap];
	NSMutableArray *instances = [[NSMutableArray alloc] init];

	for(InstanceMap_t::const_iterator it = (*instanceMap).begin(); it != (*instanceMap).end(); ++it) {
		[instances addObject:[NSString stringWithFormat:@"0x%x", it->first]];
	}

	return (NSArray *)instances;
}

-(NSArray *) instancesOfAppClasses {
	InstanceMap_t *instanceMap = [self instanceMap];
	NSMutableArray *instances = [[NSMutableArray alloc] init];

	for(InstanceMap_t::const_iterator it = (*instanceMap).begin(); it != (*instanceMap).end(); ++it) {
		id obj = (id)it->first;
		if(!obj)
			continue;

		const char *className = object_getClassName(obj);
		if(!className)
			continue;

		if(false == [iSpy isClassFromApp:[NSString stringWithUTF8String:className]])
			continue;

		NSMutableDictionary *instanceData = [[NSMutableDictionary alloc] init];
		[instanceData setObject:[NSString stringWithFormat:@"0x%x", it->first] forKey:@"address"];
		[instanceData setObject:[NSString stringWithUTF8String:className] forKey:@"class"];
		[instances addObject:(NSDictionary *)instanceData];
	}

	return (NSArray *)instances;
}

// Given a hex address (eg. 0xdeafbeef) dumps the class data from the object at that address.
// Returns an object as discussed in instance_dumpInstance, below.
// This is exposed to /api/instance/0xdeadbeef << replace deadbeef with an actual address.
-(id)instanceAtAddress:(NSString *)addr {
	return [self __dumpInstance:[self __instanceAtAddress:addr]];
}

// Given a string in the format @"0xdeadbeef", this first converts the string to an address, then
// returns an opaque Objective-C object at that address.
// The runtime can treat this return value just like any other object.
// BEWARE: give this an incorrect/invalid address and you'll return a duff pointer. Caveat emptor.
-(id)__instanceAtAddress:(NSString *)addr {
	return (id)strtoul([addr UTF8String], (char **)NULL, 16);
}

// Make sure to pass a valid pointer (instance) to this method!
// In return it'll give you an array. Each element in the array represents an iVar and comprises a dictionary.
// Each element in the dictionary represents the name, type, and value of the iVar.
-(NSArray *)__dumpInstance:(id)instance {
	void *ptr;
	iSpy *mySpy = [iSpy sharedInstance];
	NSArray *iVars = [mySpy iVarsForClass:[NSString stringWithUTF8String:object_getClassName(instance)]];
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

			// Dumb check alert!
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
			// TODO: there are better ways to do this. See obj_mgSend logging stuff. FIXME.
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

	return (NSArray *)[iVarData copy];
}

@end

/*
 * Private methods used to hook the Objective-C runtime create/destroy functions
 */

id bf_class_createInstance(Class cls, size_t extraBytes) {
	id newInstance = orig_class_createInstance(cls, extraBytes);
	InstanceTracker *tracker = [InstanceTracker sharedInstance];

	if([tracker enabled] && newInstance) {
		InstanceMap_t *instanceMap = [tracker instanceMap];
		(*instanceMap)[(unsigned int)newInstance] = (unsigned int)newInstance;
	}

	return newInstance;
}

id bf_object_dispose(id obj) {
	InstanceTracker *tracker = [InstanceTracker sharedInstance];

	if([tracker enabled] && obj) {
		InstanceMap_t *instanceMap = [tracker instanceMap];
		(*instanceMap).erase((unsigned int)obj);	
	}

	orig_object_dispose(obj);
	return nil;
}

