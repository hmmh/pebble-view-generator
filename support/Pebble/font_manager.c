//
// FontManager for Pebble
//
// Created by Florian Schaper on 16.04.14.
// Copyright (c) 2014 hmmh multimediahaus AG.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software
// and associated documentation files (the "Software"), to deal in the Software without restriction,
// including without limitation the rights to use, copy, modify, merge, publish, distribute,
// sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or
// substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
// NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#include "font_manager.h"

#include <pebble_fonts.h>

typedef struct FontResource {
	GFont font;
	uint32_t resource_id;
	uint16_t reference_count;
	struct FontResource * next;
} __attribute__((__packed__)) FontResource;

// head of a linked list of font resource entries
static FontResource *gs_font_list_head = { 0 };

// find an entry inside the linked list based on it's resource id
static FontResource * find_entry_by_resource_id( uint32_t resource_id ) 
{
	FontResource * return_value = gs_font_list_head;
	while( return_value ) {
		if( return_value->resource_id == resource_id ) {
			break;
		}
		return_value = return_value->next;
	}
	return return_value;	
}

// find an entry inside the linked list based on it's font pointer
static FontResource * find_entry_by_font( GFont font ) 
{
	FontResource * return_value = gs_font_list_head;
	while( return_value ) {
		if( return_value->font == font ) {
			break;
		}
		return_value = return_value->next;
	}
	return return_value;	
}

// finds the end of the linked list and returns a pointer to it's pointer
static FontResource ** get_end_of_list() 
{
	FontResource ** return_value = &gs_font_list_head;
	while( *return_value ) {
		return_value = &(*return_value)->next;
	}
	return return_value;
}

// unlinks an entry from the linked list
static void unlink_from_list( FontResource * entry_to_unlink ) 
{
	if ( ! entry_to_unlink ) {
		return;
	}

	// check to see if we need to unlink the head entry
	if ( gs_font_list_head == entry_to_unlink ) {
		gs_font_list_head = gs_font_list_head->next;
		return;
	}

	// unlink the element somewhere deeper down the list
	FontResource * link = gs_font_list_head;
	while ( link->next != entry_to_unlink ) {
		link = link->next;
	}
	link->next = link->next->next;
}

GFont fonts_load_custom_font_ex( uint32_t resource_id ) 
{
    // try to find the font within the list of already known fonts
	FontResource * lookup_result = find_entry_by_resource_id( resource_id );

    // if found, raise the reference count and return it
	if ( lookup_result ) {
		lookup_result->reference_count++;
		return lookup_result->font;
	}

    // the font is as of yet unknown to the font manager
    // so we have to create a new book keeping entry and
    // load the font via the pebble resource handler
    
    // get a pointer to the pointer at the end of our
    // linked list and allocate a new entry
	FontResource **new_entry = get_end_of_list();
	*new_entry = (FontResource*)calloc( 1, sizeof(FontResource) );

    // abort in case no memory could be allocated
	if ( ! *new_entry ) {
		return NULL;
	}

    // initialize our new font-entry
	(*new_entry)->reference_count = 1;
	(*new_entry)->resource_id = resource_id;
	(*new_entry)->font = fonts_load_custom_font( resource_get_handle( resource_id ) );

    // check if the pebble font manager actually returned us a
    // new font object. otherwise free the memory and abort
    // by returning NULL to the caller
	if ( ! (*new_entry)->font ) {
        APP_LOG( APP_LOG_LEVEL_DEBUG, "fonts_load_custom_font did not return a valid font handle." );
		free( *new_entry );
		return NULL;
	}

	return (*new_entry)->font;
}

void fonts_unload_custom_font_ex( GFont font ) 
{
    // sanity check against null pointers
	if ( ! font ) {
        APP_LOG( APP_LOG_LEVEL_DEBUG, "NULL pointer passed to fonts_unload_custom_font_ex." );
		return;
	}

    // find the book keeping entry in our linked list for the
    // passed font pointer
	FontResource *entry = find_entry_by_font( font );

    // no entry was found so we abort here.
    // this smells like a programming error however so we log
    // the call via APP_LOG.
	if ( ! entry ) {
        APP_LOG( APP_LOG_LEVEL_DEBUG, "tried to free an unmanaged font object via fonts_unload_custom_font_ex." );
		return;
	}
	
    // lower the reference counter
	entry->reference_count--;

    // once the reference counter for an entry reaches zero we
    // free the pebble font and release the book keeping entry
    // after unlinking it from the rest of the list.
	if ( entry->reference_count == 0 ) {
		unlink_from_list( entry );
		fonts_unload_custom_font( entry->font );
		free( entry );
	}
}
