#ifndef __ISPY_INSTANCE__
#define __ISPY_INSTANCE__

typedef std::tr1::unordered_map<unsigned int, unsigned int> InstanceMap_t;

@interface InstanceTracker : NSObject {

}
@property (assign) InstanceMap_t *instanceMap;
@property (assign) BOOL enabled;

+(InstanceTracker *) sharedInstance;
-(void) installHooks;
-(void) start;
-(void) stop;
-(void) clear;
-(NSArray *)instancesOfAllClasses;  
-(NSArray *) instancesOfAppClasses;
-(id)instanceAtAddress:(NSString *)addr; 
// Don't call these
-(id)__instanceAtAddress:(NSString *)addr;
-(NSArray *)__dumpInstance:(id)instance;
@end

// Hooks
id bf_class_createInstance(Class cls, size_t extraBytes);
id bf_object_dispose(id obj);

// Helper functions
void bf_init_instance_tracker();

#endif // __ISPY_INSTANCE__
