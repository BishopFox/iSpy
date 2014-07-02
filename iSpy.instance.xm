#include <pthread.h>
#include "iSpy.common.h"
#include "iSpy.class.h"
#include "iSpy.instance.h"

static struct bf_instance *instanceList;

// We need the original class instantiation / destruction functions declared in Tweak.xm
id (*orig_class_createInstance)(Class cls, size_t extraBytes);
id (*orig_object_dispose)(id obj);

static pthread_once_t key_once = PTHREAD_ONCE_INIT;
static pthread_key_t thr_key;
static pthread_mutex_t mutex_create = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t mutex_dispose = PTHREAD_MUTEX_INITIALIZER;
static bool instanceTrackingIsEnabled = false;

extern void bf_MSHookFunction(void *func, void *repl, void **orig); // Tweak.xm

// guaranteed to run only once
static void make_key() {
	pthread_key_create(&thr_key, NULL);
	ispy_log_debug(LOG_GENERAL, "Hooking Objective-C class create/dispose functions...");
	bf_MSHookFunction((void *)class_createInstance, (void *)bf_class_createInstance, (void **)&orig_class_createInstance);
	bf_MSHookFunction((void *)object_dispose, (void *)bf_object_dispose, (void **)&orig_object_dispose);
	ispy_log_debug(LOG_GENERAL, "Done. Instance tracking is not yet enabled...");
}

extern void bf_init_instance_tracker() {
	pthread_once(&key_once, make_key);
}

EXPORT void bf_enable_instance_tracker() {
	ispy_log_debug(LOG_GENERAL, "Enabling instance tracker");
	instanceTrackingIsEnabled = true;
}

EXPORT void bf_disable_instance_tracker() {
	ispy_log_debug(LOG_GENERAL, "Disabling instance tracker");
	instanceTrackingIsEnabled = false;
}

EXPORT bool bf_get_instance_tracking_state() {
	return instanceTrackingIsEnabled;
}

struct bf_instance *bf_get_instance_list_ptr() {
	return instanceList;
}

// Hook the Objective-C runtime class instantiator and record all of the newly instantiated objects
id bf_class_createInstance(Class cls, size_t extraBytes) {
	id newInstance = orig_class_createInstance(cls, extraBytes);
	if(instanceTrackingIsEnabled) {
		// there has to be a better  way...
		pthread_mutex_lock(&mutex_create);
		
		bf_add_instance_entry(newInstance);
		
		// ...than fucking pthread mutexes...
		pthread_mutex_unlock(&mutex_create);
	}
	return newInstance;
}

// Hook the Objective-C object destroyer and remove instantiated objects from our list
id bf_object_dispose(id obj) {
	if(instanceTrackingIsEnabled) {
		// ...because they slow shit down...
		pthread_mutex_lock(&mutex_dispose);
		
		bf_remove_instance_entry(obj);
		
		// ...like a motherfucker...
		pthread_mutex_unlock(&mutex_dispose);
	}
	// ...but without them we're not thread safe and we die...
	orig_object_dispose(obj);

	// ...so fuck it. yay pthreads.
	return nil;
}

// Allocate and inialize a new list entry for a single instance
struct bf_instance *bf_alloc_instance_entry() {
	struct bf_instance *list;

	list = (struct bf_instance *)malloc((size_t)sizeof(struct bf_instance));
	if( ! list )
		return NULL;
	
	list->next = NULL;
	list->name = NULL;
	list->instance = NULL;

	return list;
}



// Add an entry to our list that records a class instance
void bf_add_instance_entry(id instance) {
	struct bf_instance *l;

	// allocate a new list entry
	l = bf_alloc_instance_entry();
	if( ! l )
		return;

	// set the properties for this class instance
	l->name = (char *)object_getClassName(instance);
	l->instance = instance;
	l->next = NULL;
	l->prev = NULL;

	// If this is the first entry we've made, create a new list
	if(instanceList == NULL) {
		instanceList = l;
	// otherwise just insert this node at the head of the list.
	} else {
		instanceList->prev = l;
		l->next = instanceList;
		instanceList = l;
	}
}

// Remove an instance from our records
void bf_remove_instance_entry(id instance) {
	struct bf_instance *tmp, *tmpNext, *tmpPrev;

	// Yeesh... initialize your pointers, sheeple.
	if(instanceList == NULL)
		return;

	if(instance == nil)
		return;

	// save a pointer to the head of the list
	tmp = instanceList;

	// Search the linked list for the specified entry
	while(tmp) {
		if(tmp->instance && (tmp->instance == instance))
			break;
		tmp = tmp->next;
	}

	// return if we didn't find the instance
	if(tmp == NULL)
		return;

	// remove the node from the list by juggling pointers
	tmpNext = tmp->next;
	tmpPrev = tmp->prev;
	if(tmpNext)
		tmpNext->prev = tmpPrev;
	if(tmpPrev)
		tmpPrev->next = tmpNext;

	// If we're deleting the first node in the list then point the list pointer at the next node.
	if(instanceList == tmp)
		instanceList = tmpNext;
	
	// so long and thanks for all the phish
	free(tmp);
}
