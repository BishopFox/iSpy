#ifndef ___ISPY_MSGSEND_COMMON___
#define ___ISPY_MSGSEND_COMMON___

// this is private and not for consumption
struct objc_selector
{
  void *sel_id;
  const char *sel_types; 
};

// uncomment this for /tmp/bf.log - be aware this will basically grind your app to a halt. Use only in coding emergencies.
//#define DO_SUPER_DEBUG_MODE 1

#ifdef DO_SUPER_DEBUG_MODE
#define __log__(stuff) ___log___(stuff)
#else
#define __log__(stuff) {}
#endif

#define ISPY_MAX_RECURSION 32

extern "C" USED int is_valid_pointer(void *ptr);
extern "C" USED const char *get_param_value(id x);
extern "C" USED void print_args_v(id self, SEL _cmd, std::va_list va);
void ___log___(const char *jank);

#endif