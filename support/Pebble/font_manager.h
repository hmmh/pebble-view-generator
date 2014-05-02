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

#ifndef font_manager_h
#define font_manager_h

#include <pebble.h>

/**
 * will return a GFont handle for the passed resource or NULL in case an error occured.
 *
 * every call to fonts_load_custom_font_ex has to be matched by a later call to 
 * fonts_unload_custom_font_ex.
 *
 * the font manager uses reference counting and will return the same font pointer in case
 * the same resource ID is passed multiple times.
 */
GFont fonts_load_custom_font_ex( uint32_t resource_id );

/**
 * will unload a custom font object.
 *
 * every call to fonts_load_custom_font_ex has to be matched by a corresponding call
 * to fonts_unload_custom_font_ex. this function decreases the reference counter for
 * a font entry. the resource won't actually be freed until the reference counter reaches
 * zero.
 */
void fonts_unload_custom_font_ex( GFont entry );

#endif
