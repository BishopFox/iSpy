#include "iSpy.common.h"
#include "iSpy.class.h"
#include "iSpy.msgSend.whitelist.h"
#include <iostream>
#include <string>
#include <vector>
#include <memory>

struct interestingCall interestingCalls[] = {
    /*
    {
        // Field meanings:

        "Classification of interesting call",
        "Name of class to trigger on",
        "Name of method to trigger on",
        "Provide a description that will be sent to the iSpy UI",
        "Provide a risk rating",
        one of: INTERESTING_CALL or INTERESTING_BREAKPOINT
    }
    */
    // Data Storage
    { 
        "Data Storage",
        "NSManagedObjectContext", 
        "save", 
        "Core Data uses unencrypted SQLite databases. Sensitive information should not be stored here.", 
        "Medium",
        INTERESTING_CALL
    },
    {
        "Data Storage",
        "NSDictionary",
        "writeToFile",
        "Sensitive data should not be saved in this manner.",
        "Medium",
        INTERESTING_CALL
    },
    {
        "Data Storage",
        "NSUserDefaults",
        "init",
        "Sensitive data should not be saved using NSUserDefaults.",
        "Medium",
        INTERESTING_CALL
    },
    {
        "Data Storage",
        "NSURLCache",
        "initWithMemoryCapacity:diskCapacity:diskPath:",
        "Sensitive SSL-encrypted data may be stored in the clear using NSURLCache.",
        "Medium",
        INTERESTING_CALL
    },
    {
        "Data Storage",
        "NSURLCache",
        "storeCachedResponse:forRequest:",
        "Sensitive SSL-encrypted data may be stored in the clear using NSURLCache.",
        "Medium",
        INTERESTING_CALL
    },
    {
        "Data Storage",
        "NSURLCache",
        "setDiskCapacity:",
        "Sensitive SSL-encrypted data may be stored in the clear using NSURLCache.",
        "Medium",
        INTERESTING_CALL
    },
    

    // Breakpoints
    /*
    {
        "TEST",                         // must be present, value unimportant
        "RealTimeDataViewController",   // class
        "showLoadingView",              // method
        "",
        "",
        INTERESTING_BREAKPOINT          // must be present
    },
    */
    { NULL }
};

extern void whitelist_add_method(std::string *className, std::string *methodName, unsigned int type) {
    ispy_log_debug(LOG_GENERAL, "[Whitelist] add [%s %s]", className->c_str(), methodName->c_str());
    ClassMap_t *ClassMap = [[iSpy sharedInstance] classWhitelist];
    (*ClassMap)[*className][*methodName] = type;
}

extern void whitelist_remove_method(std::string *className, std::string *methodName) {
    ClassMap_t *ClassMap = [[iSpy sharedInstance] classWhitelist];
    (*ClassMap)[*className].erase(*methodName);
}

extern void whitelist_startup() {
    // use a static buffer because for some odd reason this is the only way to stick a hash map on the BSS without a crash. LAME.
    static std::tr1::unordered_map<std::string, std::tr1::unordered_map<std::string, unsigned int> > WhitelistClassMap;
    static BreakpointMap_t Breakpoints;

    ispy_log_debug(LOG_GENERAL, "[Whitelist] initializing the pointers and whatnot.");

    // Set the singleton pointers to the hashmaps. 
    [[iSpy sharedInstance] setClassWhitelist:&WhitelistClassMap];
    [iSpy sharedInstance]->breakpoints = &Breakpoints;
}

extern void whitelist_add_hardcoded_interesting_calls() {
    ispy_log_debug(LOG_GENERAL, "[Whitelist] Initializing the interesting functions");
    struct interestingCall *call = interestingCalls;

    while(call->classification) {
        ispy_log_debug(LOG_GENERAL, "call = %p", call);
        whitelist_add_method(&std::string(call->className), &std::string(call->methodName), (unsigned int)call);
        call++;
    }
}

extern void whitelist_clear_whitelist() {
    ClassMap_t *whitelist = [[iSpy sharedInstance] classWhitelist];
    whitelist->clear();
}

void whitelist_add_app_classes() {
    int i, numClasses, m, numMethods;

    // Get a list of all the classes in the app
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
    		std::string *classNameString = new std::string([name UTF8String]);
    		std::string *methodNameString = new std::string([methodName UTF8String]);
    		if(!classNameString || !methodNameString) {
    			if(methodNameString)
    				delete methodNameString;
    			if(classNameString)
    				delete classNameString;
    			continue;
    		}
    		//ispy_log_debug(LOG_GENERAL, "[Whitelist adding [%s %s]", classNameString->c_str(), methodNameString->c_str());
            whitelist_add_method(classNameString, methodNameString, WHITELIST_PRESENT);
    		[methodName release];
    		delete methodNameString;
    		delete classNameString;
    	}
    	[name release];
    	[methods release];
    }
    [classes release];

    ispy_log_debug(LOG_GENERAL, "[whitelist] Added %d of %d classes to the whitelist.", i, numClasses);   
}

