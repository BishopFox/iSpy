#include "iSpy.common.h"
#include "iSpy.class.h"
#include "iSpy.msgSend.whitelist.h"
#include <iostream>
#include <string>
#include <vector>
#include <memory>

// Typically we will want to ignore this crap, although we can turn it back on if we really want it.
// It's basically a bunch of methods inherited from NSObject. 
// Yes, it's hardcoded but this isn't the place to change it:
// Do so by creating a new list and changing the pointer (bf_objc_msgSend_captured_class->uninterestingMethods) on a per-class basis.
//const char *bf_msgSend_uninterestingList = "|retain|dealloc|alloc|init|release|class|load|initialize|allocWithZone:|copy|copyWithZone:|mutableCopy|mutableCopyWithZone:|new|class|superclass|isSubClassOfClass:|instancesRespondToSelector|";

void bf_objc_msgSend_whitelist_startup() {
    int i, numClasses, m, numMethods, count=0;
    static std::tr1::unordered_map<std::string, std::tr1::unordered_map<std::string, int> > WhitelistClassMap;

    NSArray *classes = [[iSpy sharedInstance] classes];
	numClasses = [classes count];
    
    ispy_log_debug(LOG_GENERAL, "[Whitelist] adding %d classes...", numClasses);

    // Iterate through all the class names, adding each one to our lookup table
    for(i = 0; i < numClasses; i++) {
    	NSString *name = [classes objectAtIndex:i];
    	if(!name) {
    		continue;
    	}

    	NSArray *methods = [[iSpy sharedInstance] methodListForClass:name];
    	if(!methods) {
    		continue;
    	}

    	numMethods = [methods count];
    	if(!numMethods) {
    		[methods release];
    		[name release];
    		continue;
    	}

    	for(m = 0; m < numMethods; m++) {
    		NSString *methodName = [methods objectAtIndex:m];
    		if(!methodName) {
    			continue;
    		}
    		std::string *nameString = new std::string([name UTF8String]);
    		std::string *methodNameString = new std::string([methodName UTF8String]);
    		if(!nameString || !methodNameString) {
    			if(methodNameString)
    				delete methodNameString;
    			if(nameString)
    				delete nameString;
    			continue;
    		}
    		ispy_log_debug(LOG_GENERAL, "[Whitelist (%d) %d / %d] adding [%s %s]", ++count, i, m, nameString->c_str(), methodNameString->c_str());
    		WhitelistClassMap[(*nameString)][(*methodNameString)] = 1;
    		[methodName release];
    		delete methodNameString;
    		delete nameString;
    	}
    	[name release];
    	[methods release];
    }
    [classes release];

    ispy_log_debug(LOG_GENERAL, "[whitelist] Added %d of %d classes to the whitelist. Adding to iSpy class...", i, numClasses);
    [[iSpy sharedInstance] setClassWhitelist:&WhitelistClassMap];
    ispy_log_debug(LOG_GENERAL, "[whitelist] All done!\n");
    
}

