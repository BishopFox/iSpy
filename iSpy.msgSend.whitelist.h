#ifndef __ISPY_OBJC_MSGSEND_WHITELIST__
#define __ISPY_OBJC_MSGSEND_WHITELIST__

#define INTERESTING_CALL 1
#define INTERESTING_BREAKPOINT 2

struct interestingCall {
    const char *classification;
    const char *className;
    const char *methodName;
    const char *description;
    const char *risk;
    int type;
};

typedef std::tr1::unordered_map<std::string, unsigned int> MethodMap_t;
typedef std::tr1::unordered_map<unsigned int, unsigned int> BreakpointMap_t;
//typedef std::tr1::unordered_map<std::string, MethodMap_t> ClassMap_t;
typedef std::tr1::unordered_map<std::string, MethodMap_t > ClassMap_t;
typedef std::pair<std::string, MethodMap_t> ClassPair_t;

// Helper functions
void whitelist_startup();
void whitelist_add_app_classes();
void whitelist_add_hardcoded_interesting_calls();
void whitelist_add_method(std::string *className, std::string *methodName, unsigned int type);
void whitelist_remove_method(std::string *className, std::string *methodName);
void breakpoint_release_breakpoint(const char *className, const char *methodName);
void whitelist_clear_whitelist();

#define WHITELIST_PRESENT		1
#define WHITELIST_NOT_PRESENT	0

#endif // __ISPY_OBJC_MSGSEND_WHITELIST__
