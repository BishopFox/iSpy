#ifndef __ISPY_OBJC_MSGSEND_WHITELIST__
#define __ISPY_OBJC_MSGSEND_WHITELIST__

typedef std::tr1::unordered_map<std::string, int> MethodMap_t;
typedef std::tr1::unordered_map<std::string, MethodMap_t> ClassMap_t;
//typedef std::pair<std::string, int> MethodPair_t;
typedef std::pair<std::string, MethodMap_t> ClassPair_t;

struct bf_objc_msgSend_captured_class {
	char *name;						// human-friendly name of class
	int logAllMethods;				// don't even bother with a whitelist if we're logging all the things
	char *uninterestingMethods;		// if not NULL then ignore any methods on this list. Will normally point to bf_msgSend_uninterestingList)
	char *whitelistedMethods;		// if not NULL then include any methods on this list (e.g. "|method1Name|method2Name|etc|etc|")
	struct bf_objc_msgSend_captured_class *next;	// this is a double-linked list
	struct bf_objc_msgSend_captured_class *prev;	// this is a double-linked list
};

// Helper functions
void bf_objc_msgSend_whitelist_clear();
void bf_objc_msgSend_whitelist_add_class(const char *className, int logAllMethods, char *uninterestingMethods, char *whitelistedMethods);
int bf_objc_msgSend_whitelist_entry_exists(const char *className, const char *methodName);
void bf_objc_msgSend_whitelist_startup();

struct bf_objc_msgSend_captured_class *bf_objc_msgSend_whitelist_get_list_ptr();
struct bf_objc_msgSend_captured_class *bf_objc_msgSend_whitelist_alloc_entry();

#endif // __ISPY_OBJC_MSGSEND_WHITELIST__
