#include <pthread.h>
#include "iSpy.common.h"
#include "iSpy.class.h"
#include "iSpy.instance.h"

// We need the original class instantiation / destruction functions declared in Tweak.xm
id (*orig_class_createInstance)(Class cls, size_t extraBytes);
id (*orig_object_dispose)(id obj);

extern void bf_MSHookFunction(void *func, void *repl, void **orig); // Tweak.xm

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

