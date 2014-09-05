#ifndef __ISPY_OBJC_MSGSEND_WHITELIST__
#define __ISPY_OBJC_MSGSEND_WHITELIST__

typedef std::tr1::unordered_map<std::string, int> MethodMap_t;
//typedef std::tr1::unordered_map<std::string, MethodMap_t> ClassMap_t;
typedef std::tr1::unordered_map<std::string, std::tr1::unordered_map<std::string, int> > ClassMap_t;
typedef std::pair<std::string, MethodMap_t> ClassPair_t;

// Helper functions
void bf_objc_msgSend_whitelist_startup();
void whitelist_add_method(std::string *className, std::string *methodName);
void whitelist_remove_method(std::string *className, std::string *methodName);

#define WHITELIST_PRESENT		0xbadc0ded
#define WHITELIST_NOT_PRESENT	0

#endif // __ISPY_OBJC_MSGSEND_WHITELIST__
