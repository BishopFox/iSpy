#ifndef __ISPY_OBJC_MSGSEND_WHITELIST__
#define __ISPY_OBJC_MSGSEND_WHITELIST__

typedef std::tr1::unordered_map<std::string, int> MethodMap_t;
//typedef std::tr1::unordered_map<std::string, MethodMap_t> ClassMap_t;
typedef std::tr1::unordered_map<std::string, std::tr1::unordered_map<std::string, int> > ClassMap_t;
typedef std::pair<std::string, MethodMap_t> ClassPair_t;

// Helper functions
void bf_objc_msgSend_whitelist_startup();


#endif // __ISPY_OBJC_MSGSEND_WHITELIST__
