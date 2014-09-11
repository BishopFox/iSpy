#ifndef ___ISPY_MSGSEND_COMMON___
#define ___ISPY_MSGSEND_COMMON___

// this is private and not for consumption
struct objc_selector
{
  void *sel_id;
  const char *sel_types; 
};

struct objc_callState {
	char *json;
	char *returnType;
};

// uncomment this for /tmp/bf.log - be aware this will basically grind your app to a halt. Use only in coding emergencies.
//#define DO_SUPER_DEBUG_MODE 1

#ifdef DO_SUPER_DEBUG_MODE
#define __log__(stuff) ___log___(stuff)
#else
#define __log__(stuff) {}
#endif

#define ISPY_MAX_RECURSION 128 // crazy big

extern "C" USED int is_valid_pointer(void *ptr);
extern "C" USED const char *get_param_value(id x);
extern "C" USED void *print_args_v(id self, SEL _cmd, std::va_list va);
extern "C" USED char *parameter_to_JSON(char *typeCode, void *paramVal);
extern "C" unsigned int is_this_method_on_whitelist(id Cls, SEL selector);
extern "C" USED void interesting_call_postflight_check(struct objc_callState *callState, struct interestingCall *call);
extern "C" void breakpoint_wait_until_release(struct interestingCall *call);
void breakpoint_release_breakpoint(const char *className, const char *methodName);
void ___log___(const char *jank);

#endif