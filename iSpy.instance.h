#ifndef __BEEFHOOK_INSTANCE__
#define __BEEFHOOK_INSTANCE__

struct bf_instance {
	id instance;	// pointer to the instance
	char *name;		// human friendly name of class
	struct bf_instance *next;
	struct bf_instance *prev;
};

// Hooks
id bf_class_createInstance(Class cls, size_t extraBytes);
id bf_object_dispose(id obj);

// Helper functions
void bf_init_instance_tracker();
struct bf_instance *bf_get_instance_list_ptr();
struct bf_instance *bf_alloc_instance_entry();
void bf_add_instance_entry(id instance);
void bf_remove_instance_entry(id instance);

#endif // __BEEFHOOK_INSTANCE__
