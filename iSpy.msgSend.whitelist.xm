#include "iSpy.common.h"
#include "iSpy.class.h"
#include "iSpy.msgSend.whitelist.h"

static struct bf_objc_msgSend_captured_class *objc_msgSendWhitelist = NULL;

// Typically we will want to ignore this crap, although we can turn it back on if we really want it.
// It's basically a bunch of methods inherited from NSObject. 
// Yes, it's hardcoded but this isn't the place to change it:
// Do so by creating a new list and changing the pointer (bf_objc_msgSend_captured_class->uninterestingMethods) on a per-class basis.
const char *bf_msgSend_uninterestingList = "|retain|dealloc|alloc|init|release|class|load|initialize|allocWithZone:|copy|copyWithZone:|mutableCopy|mutableCopyWithZone:|new|class|superclass|isSubClassOfClass:|instancesRespondToSelector|";


// Add a class to our whitelist
void bf_objc_msgSend_whitelist_add_class(const char *className, int logAllMethods, char *uninterestingMethods, char *whitelistedMethods) {
	struct bf_objc_msgSend_captured_class *l;

	// allocate a new list entry
	l = bf_objc_msgSend_whitelist_alloc_entry();
	if( ! l )
		return;

	// set the properties for this class instance
	l->name = (char *)className;
	l->logAllMethods = logAllMethods;
	l->uninterestingMethods = uninterestingMethods;
	l->whitelistedMethods = whitelistedMethods;

	// If this is the first entry we've made, create a new list
	if(objc_msgSendWhitelist == NULL) {
		objc_msgSendWhitelist = l;
	// otherwise just insert this node at the head of the list.
	} else {
		objc_msgSendWhitelist->prev = l;
		l->next = objc_msgSendWhitelist;
		objc_msgSendWhitelist = l;
	}
}


// Erase the whitelist
void bf_objc_msgSend_whitelist_clear() {
	struct bf_objc_msgSend_captured_class *tmp;

	// Yeesh... initialize your pointers, sheeple.
	if(objc_msgSendWhitelist == NULL)
		return;

	// save a pointer to the head of the list
	tmp = objc_msgSendWhitelist;

	// Clear the list
	while(tmp) {
		tmp = tmp->next;
		free(tmp->prev);
	}
}


// Answers the question: is the supplied class::method combination in scope for logging?
int bf_objc_msgSend_whitelist_entry_exists(const char *className, const char *methodName) {
	struct bf_objc_msgSend_captured_class *l = objc_msgSendWhitelist;
	char *searchMethodName = NULL;
	int len = -1;

	if(!className || !methodName)
		return NO;

	len = strlen(methodName);
	if((searchMethodName = (char *)malloc((size_t)len + 3)) == NULL)
		return NO;

	while(l) {
		// is this class on the whitelist?
		if(l->name && strcmp(l->name, className) == 0) {
			// yes! are we logging all methods for this class?
			if(l->logAllMethods) {
				// yes! ok, but is there an explicit blacklist for this class?
				if(l->uninterestingMethods) {	
					*searchMethodName = '|';
					searchMethodName[len+1] = '|';
					searchMethodName[len+2] = (char)0;
					memcpy(searchMethodName + 1, methodName, len);
					
					// Ignore anything on the blacklist
					if(strstr(l->uninterestingMethods, searchMethodName) != NULL) {
						goto shitNo; // this class::method was found on the blacklist
					}

					// the method wasn't found on the blacklist. Good to go!
					goto hellYes;

				// there's no blacklist, so we're good to go.
				} else {
					goto hellYes;
				}

			// if we're not logging all methods, we need to search for this exact method
			} else {
				if(l->whitelistedMethods && (strcmp(methodName, l->whitelistedMethods) == 0)) {
					goto hellYes; // this method is on the whitelist
				} 
			}
			goto shitNo; // fall through to a default deny policy
		}

		// try the next class on the whitelist
		l = l->next;
	}

shitNo:
	free(searchMethodName);
	return NO;

hellYes:
	free(searchMethodName);
	return YES;
}

int bf_objc_msgSend_whitelist_startup() {
    int i, numClasses;
    
    NSArray *classes = [[iSpy sharedInstance] classes];
	numClasses = [classes count];
    
    // Iterate through all the class names, adding each one to our lookup table
    for(i = 0; i < numClasses; i++) {
    	NSString *name = [classes objectAtIndex:i];
        bf_objc_msgSend_whitelist_add_class([name UTF8String], YES, (char *)bf_msgSend_uninterestingList, NULL);
        ispy_log_debug(LOG_GENERAL, "[Whitelist] adding %s", [name UTF8String]);
    }

    ispy_log_debug(LOG_GENERAL, "[whitelist] Added %d classes to the whitelist. All done!", i);

    return true; 
}


struct bf_objc_msgSend_captured_class *bf_objc_msgSend_whitelist_get_list_ptr() {
	return objc_msgSendWhitelist;
}


// Allocate and inialize a new list entry for a single class
struct bf_objc_msgSend_captured_class *bf_objc_msgSend_whitelist_alloc_entry() {
	struct bf_objc_msgSend_captured_class *list;

	list = (struct bf_objc_msgSend_captured_class *)malloc((size_t)sizeof(struct bf_objc_msgSend_captured_class));
	if( ! list )
		return NULL;
	
	list->next = NULL;
	list->prev = NULL;
	list->name = NULL;
	list->whitelistedMethods = NULL;
	list->uninterestingMethods = (char *)bf_msgSend_uninterestingList;
	list->logAllMethods = NO;

	return list;
}

