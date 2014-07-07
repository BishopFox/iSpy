#ifndef ___ISPY_MSGSEND_COMMON___
#define ___ISPY_MSGSEND_COMMON___

// this is private and not for consumption
struct objc_selector
{
  void *sel_id;
  const char *sel_types; 
};


extern "C" USED int is_valid_pointer(void *ptr);
extern "C" USED const char *get_param_value(id x);
void __log__(const char *jank);

#endif