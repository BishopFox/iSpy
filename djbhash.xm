
#include <substrate.h>
#include <sys/types.h>
#include <dirent.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/param.h>
#include <sys/mount.h>
#include <sys/ioctl.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <mach-o/dyld.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdarg.h>
#include <unistd.h>
#include <string.h>
#include <stdarg.h>
#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFStream.h>
#import <CFNetwork/CFNetwork.h>
#include <pthread.h>
#include <CFNetwork/CFProxySupport.h>
#import <Security/Security.h>
#include <Security/SecCertificate.h>
#include <dlfcn.h>
#include <stdbool.h>
#include <objc/objc.h>
#include "iSpy.common.h"
#include "iSpy.class.h"
#include "iSpy.msgSend.whitelist.h"
#include <stack>
#include <pthread.h>
#include "djbhash.h"
#include <stdlib.h>

// Convert an integer to string.
unsigned char *djbhash_int_to_a( int number )
{
  unsigned char *ascii;
  ascii = (unsigned char *)calloc( 32, sizeof( unsigned char ) );
  sprintf( (char *)ascii, "%d", number );
  return ascii;
}

// Convert a double into a string.
unsigned char *djbhash_double_to_a( double number )
{
  unsigned char *ascii;
  ascii = (unsigned char *)calloc( 32, sizeof( unsigned char ) );
  sprintf( (char *)ascii, "%f", number );
  return ascii;
}

// Return a JSON formated array string.
unsigned char *djbhash_json_array( void *array, int count )
{
  int i, j;
  unsigned char *json;
  unsigned char *part;
  unsigned int length, pos, size;
  struct djbhash **argData = (struct djbhash **)array;

  json = (unsigned char *)calloc( 3, sizeof( unsigned char ) );
  json[0] = '[';
  pos = 1;
  size = 1;
  for ( i = 0; i < count; i++ )
  {
    part = djbhash_to_json(argData[i]);
    //part = djbhash_int_to_a( array[i] );
    length = strlen( (char *)part );
    size += length + 2;
    json = (unsigned char *)realloc( json, sizeof( unsigned char ) * size );
    for ( j = pos; j < size; j++ )
      json[j] = '\0';

    for ( j = 0; j < length; j++ )
      json[j + pos] = part[j];
    pos += length;

    if ( i < count - 1 )
      json[pos++] = ',';
    free( part );
    part = NULL;
  }
  json[pos] = ']';
  return json;
}

// Return an escaped version of a string.
unsigned char *djbhash_escaped( unsigned char *data )
{
  unsigned char *escaped;
  unsigned char *ptr;
  int iter;

  escaped = (unsigned char *)calloc( strlen( (char *)data ) * 2 + 2, sizeof( unsigned char ) );
  escaped[0] = '"';
  iter = 1;
  ptr = data;
  while ( *ptr != '\0' )
  {
    switch ( *ptr )
    {
      case '\n':
        escaped[iter++] = '\\';
        escaped[iter++] = 'n';
        break;
      case '\t':
        escaped[iter++] = '\\';
        escaped[iter++] = 't';
        break;
      case '\r':
        escaped[iter++] = '\\';
        escaped[iter++] = 'r';
        break;
      case '\f':
        escaped[iter++] = '\\';
        escaped[iter++] = 'f';
        break;
      case '"':
        escaped[iter++] = '\\';
        escaped[iter++] = '"';
        break;
      case '\\':
        escaped[iter++] = '\\';
        escaped[iter++] = '\\';
        break;
      default:
        escaped[iter++] = *ptr;
        break;
    }
    ptr++;
  }
  escaped[iter] = '"';
  return escaped;
}

// Print an item in JSON format.
unsigned char *djbhash_value_to_json( struct djbhash_node *item )
{
  unsigned char *json, *str;
  int length;

  switch ( item->data_type )
  {
    case DJBHASH_INT:
      json = djbhash_int_to_a( *( int * )item->value );
      break;
    case DJBHASH_DOUBLE:
      json = djbhash_double_to_a( *( double * )item->value );
      break;
    case DJBHASH_CHAR:
      str = (unsigned char *)calloc( 2, sizeof( unsigned char ) );
      str[0] = *( unsigned char * )item->value;
      json = djbhash_escaped( str );
      free( str );
      str = NULL;
      break;
    case DJBHASH_STRING:
      json = djbhash_escaped( ( unsigned char * )item->value );
      break;
    case DJBHASH_ARRAY:
      json = djbhash_json_array( ( void * )item->value, item->count );
      break;
    case DJBHASH_HASH:
      json = djbhash_to_json( ( struct djbhash * )item->value );
      break;
    default:
      length = strlen( "UNKNOWN" );
      json = (unsigned char *)calloc( length + 1, sizeof( unsigned char ) );
      memcpy( json, "UNKNOWN", length );
  }
  return json;
}

// Return a JSON formatted string containing the hash.
unsigned char *djbhash_to_json( struct djbhash *hash )
{
  int j;
  unsigned char *json;
  unsigned char *key, *value;
  unsigned int length, pos, size;
  struct djbhash_node *iter;

  json = (unsigned char *)calloc( 3, sizeof( unsigned char ) );
  json[0] = '{';
  pos = 1;
  size = 1;
  djbhash_reset_iterator( hash );
  iter = djbhash_iterate( hash );
  while ( iter )
  {
    key = djbhash_escaped( (unsigned char *)iter->key );
    length = strlen( (char *)key );

    // Reallocate memory and set it to null.
    size += length + 3;
    json = (unsigned char *)realloc( json, sizeof( unsigned char ) * size );
    for ( j = pos; j < size; j++ )
      json[j] = '\0';

    // Add the key in quotes to the string.
    for ( j = 0; j < length; j++ )
      json[j + pos] = key[j];
    pos += length;

    // Now the value:
    value = djbhash_value_to_json( iter );
    length = strlen( (char *)value );
    size += length + 1;
    json = (unsigned char *)realloc( json, sizeof( unsigned char ) * size );
    for ( j = pos; j < size; j++ )
      json[j] = '\0';
    json[pos++] = ':';

    for ( j = 0; j < length; j++ )
      json[j + pos] = value[j];
    pos += length;
    iter = djbhash_iterate( hash );
    if ( iter != NULL )
      json[pos++] = ',';

    free( key );
    key = NULL;
    free( value );
    value = NULL;
  }
  djbhash_reset_iterator( hash );
  json[pos] = '}';
  return json;
}

// Print an items' data.
void djbhash_print_value( struct djbhash_node *item )
{
  // String containing JSON formatted value.
  unsigned char *json;

  json = djbhash_value_to_json( item );
  printf( "%s", json );
  if ( json != NULL )
  {
    free( json );
    json = NULL;
  }
  printf( "\n" );
}

// Print the key value pair.
void djbhash_print( struct djbhash_node *item )
{
  printf( "%s => ", item->key );
  djbhash_print_value( item );
}

// Initialize the hash table.
void djbhash_init( struct djbhash *hash )
{
  int i;
  hash->buckets = (struct djbhash_bucket *)malloc( sizeof( struct djbhash_bucket ) * DJBHASH_MAX_BUCKETS );
  hash->active = (int *)malloc( sizeof( int ) * DJBHASH_MAX_BUCKETS );
  hash->active_count = 0;
  hash->iter.node = NULL;
  hash->iter.last = NULL;
  hash->iter.id = 0;
  for ( i = 0; i < DJBHASH_MAX_BUCKETS; i++ )
  {
    hash->buckets[i].id = i;
    hash->buckets[i].list = NULL;
  }
}

// DJB Hash function.
unsigned int djb_hash( char *key, int length )
{
  unsigned int i;
  unsigned int hash;

  hash = 5381;
  for ( i = 0; i < length; key++, i++ )
    hash = ( ( hash << 5 ) + hash ) + ( *key );
  return hash % DJBHASH_MAX_BUCKETS;
}

// Find the bucket for the element.
struct djbhash_search djbhash_bin_search( struct djbhash *hash, unsigned int min, unsigned int max, unsigned int bucket_id, char *key, int length )
{
  // Mid-point for search.
  unsigned int mid;
  // Linked list iterator and parent node.
  struct djbhash_node *iter, *parent;
  // Return variable.
  struct djbhash_search pos;

  // If max is less than min, we didn't find it.
  if ( max < min )
  {
    pos.bucket_id = min;
    pos.found = false;
    pos.item = NULL;
    pos.parent = NULL;
    return pos;
  }

  mid = ( min + max ) / 2;
  if ( hash->buckets[mid].id > bucket_id )
    return djbhash_bin_search( hash, min, mid - 1, bucket_id, key, length );
  else if ( hash->buckets[mid].id < bucket_id )
    return djbhash_bin_search( hash, mid + 1, max, bucket_id, key, length );

  // Point our iterator to the first element in this bucket.
  iter = hash->buckets[mid].list;
  parent = iter;
  while ( iter )
  {
    // We want to return if the key in the linked list actually matches.
    if ( strncmp( iter->key, key, length ) == 0 )
    {
      pos.bucket_id = mid;
      pos.found = true;
      pos.item = iter;
      pos.parent = parent;
      return pos;
    }
    parent = iter;
    iter = iter->next;
  }

  // If we got here, there the item doesn't actually exist, it's just a hash collision.
  pos.bucket_id = mid;
  pos.found = false;
  pos.item = NULL;
  pos.parent = parent;
  return pos;
}

// Create our own memory for the item value so we don't have to worry about local values and such.
void *djbhash_value( void *value, int data_type, int count )
{
  int i;
  int *temp, *iter;
  double *temp2;
  unsigned char *temp3;
  void *ptr;
  struct djbhash *temp4;
  struct djbhash_node *item;
  unsigned char *str;
  int length;

  switch( data_type )
  {
    case DJBHASH_INT:
      temp = (int *)malloc( sizeof( int ) );
      *temp = *( int * )value;
      ptr = temp;
      break;
    case DJBHASH_DOUBLE:
      temp2 = (double *)malloc( sizeof( double ) );
      *temp2 = *( double * )value;
      ptr = temp2;
      break;
    case DJBHASH_CHAR:
      temp3 = (unsigned char *)malloc( sizeof( unsigned char ) );
      *temp3 = *( unsigned char * )value;
      ptr = temp3;
      break;
    case DJBHASH_STRING:
      length = strlen( ( char * )value );
      str = (unsigned char *)calloc( length + 1, sizeof( unsigned char ) );
      memcpy( str, ( char * )value, length );
      ptr = str;
      break;
    case DJBHASH_ARRAY:
      temp = (int *)malloc( sizeof( int ) * count );
      iter = (int *)value;
      for ( i = 0; i < count; i++ )
        temp[i] = iter[i];
      ptr = temp;
      break;
    case DJBHASH_HASH:
      temp4 = (struct djbhash *)malloc( sizeof( struct djbhash ) );
      djbhash_init( temp4 );
      item = djbhash_iterate( ( struct djbhash * )value );
      while ( item )
      {
        djbhash_set( temp4, item->key, item->value, item->data_type, item->count );
        item = djbhash_iterate( ( struct djbhash * )value );
      }
      djbhash_reset_iterator( ( struct djbhash * )value );
      ptr = temp4;
      break;
    default:
      ptr = value;
  }
  return ptr;
}

// Set the value for an item in the hash table using array hash table.
int djbhash_set( struct djbhash *hash, char *key, void *value, int data_type, ... )
{
  struct djbhash_search search;
  unsigned int bucket_id;
  int length;
  va_list arg_ptr;
  struct djbhash_node *temp;
  int count;

  // Default invalid data types.
  if ( data_type < DJBHASH_INT || data_type > DJBHASH_OTHER_MALLOCD )
    data_type = DJBHASH_STRING;

  // If the data type is an array, track how many items the array has.
  if ( data_type == DJBHASH_ARRAY )
  {
    va_start( arg_ptr, data_type );
    count = va_arg( arg_ptr, int );
    va_end( arg_ptr );
  }

  // Calculate the key length and bucket ID.
  length = strlen( key );
  bucket_id = djb_hash( key, length );

  // Find our insert/update/append position.
  search = djbhash_bin_search( hash, 0, DJBHASH_MAX_BUCKETS - 1, bucket_id, key, length );

  // If we found the item with this key, we need to just update it.
  if ( search.found )
  {
    free( search.item->value );
    search.item->value = djbhash_value( value, data_type, count );
    return true;
  }

  // Create our hash item.
  temp = (struct djbhash_node *)malloc( sizeof( struct djbhash_node ) );
  temp->key = (char *)calloc( length + 1, sizeof( unsigned char ) );
  memcpy( temp->key, key, length );
  temp->value = djbhash_value( value, data_type, count );
  temp->data_type = data_type;
  temp->count = count;
  temp->next = NULL;

  if ( search.parent == NULL )
  {
    hash->buckets[search.bucket_id].list = temp;
    hash->active_count++;
    hash->active[hash->active_count - 1] = search.bucket_id;
  } else
  {
    search.parent->next = temp;
  }
  return false;
}

// Find an item in the hash table using linked lists.
struct djbhash_node *djbhash_find( struct djbhash *hash, char *key )
{
  int length;
  int bucket_id;
  struct djbhash_search search;

  length = strlen( key );
  bucket_id = djb_hash( key, length );
  search = djbhash_bin_search( hash, 0, DJBHASH_MAX_BUCKETS - 1, bucket_id, key, length );
  return search.item;
}

// Remove an item from the hash.
int djbhash_remove( struct djbhash *hash, char *key )
{
  int i, offset;
  int length;
  int bucket_id;
  struct djbhash_search search;
  struct djbhash_node *item, *parent, *next;

  length = strlen( key );
  bucket_id = djb_hash( key, length );
  search = djbhash_bin_search( hash, 0, DJBHASH_MAX_BUCKETS - 1, bucket_id, key, length );

  // If we don't find the item, we obviously can't remove it.
  if ( !search.found )
    return false;

  // Otherwise, free the item, and set the parent node's next to the item's next.
  item = search.item;
  parent = search.parent;
  next = search.item->next;

  if ( parent == item )
  {
    hash->buckets[search.bucket_id].list = next;
    if ( hash->buckets[search.bucket_id].list == NULL )
    {
      offset = 0;
      // Remove this from active buckets.
      for ( i = 0; i < hash->active_count; i++ )
      {
        if ( hash->active[i] == search.bucket_id )
          offset = 1;
        else
          hash->active[i - offset] = hash->active[i];
      }
      hash->active_count--;
    }
  } else
  {
    parent->next = next;
  }

  djbhash_free_node( search.item );
  return true;
}

// Dump all data in the hash table using linked lists.
void djbhash_dump( struct djbhash *hash )
{
  int i;
  struct djbhash_node *iter;

  for ( i = 0; i < hash->active_count; i++ )
  {
    iter = hash->buckets[hash->active[i]].list;
    while ( iter )
    {
      djbhash_print( iter );
      iter = iter->next;
    }
  }
}

// Iterate through all hash items one at a time.
struct djbhash_node *djbhash_iterate( struct djbhash *hash )
{
  if ( hash->iter.node == NULL && hash->iter.last == NULL )
  {
    if ( hash->active_count > 0 )
    {
      hash->iter.node = hash->buckets[hash->active[0]].list;
      return hash->iter.node;
    }
    return NULL;
  } else if ( hash->iter.node == NULL )
    return NULL;

  hash->iter.last = hash->iter.node;
  hash->iter.node = hash->iter.node->next;
  if ( hash->iter.node == NULL )
  {
    if ( hash->iter.id == hash->active_count - 1 )
      return NULL;
    hash->iter.id++;
    hash->iter.node = hash->buckets[hash->active[hash->iter.id]].list;
  }
  return hash->iter.node;
}

// Reset iterator.
void djbhash_reset_iterator( struct djbhash *hash )
{
  hash->iter.id = 0;
  hash->iter.node = NULL;
  hash->iter.last = NULL;
}

// Free memory used by a node.
void djbhash_free_node( struct djbhash_node *item )
{
  if ( item->key != NULL )
  {
    free( item->key );
    item->key = NULL;
  }
  if ( item->value != NULL && item->data_type != DJBHASH_OTHER && item->data_type != DJBHASH_HASH )
  {
    free( item->value );
    item->value = NULL;
  } else if ( item->data_type == DJBHASH_HASH )
  {
    djbhash_destroy( ( struct djbhash * )item->value );
    free( item->value );
    item->value = NULL;
  }
  free( item );
  item = NULL;
}

// Remove all elements from the hash table.
void djbhash_empty( struct djbhash *hash )
{
  int i;
  struct djbhash_node *iter;
  struct djbhash_node *next;
  for ( i = 0; i < DJBHASH_MAX_BUCKETS; i++ )
  {
    iter = hash->buckets[i].list;
    while ( iter )
    {
      next = iter->next;
      djbhash_free_node( iter );
      iter = next;
    }
  }
  hash->active_count = 0;
}

// Remove all elements and frees memory used by the hash table.
void djbhash_destroy( struct djbhash *hash )
{
  djbhash_empty( hash );
  free( hash->buckets );
  hash->buckets = NULL;
  free( hash->active );
  hash->active = NULL;
}
