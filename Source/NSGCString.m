/* Implementation for GNUStep of NSStrings with C-string backing
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: March 1995

   This file is part of the GNU Objective C Class Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/ 

#include <objects/stdobjects.h>
#include <foundation/NSString.h>
#include <objects/NSString.h>
#include <objects/IndexedCollection.h>
#include <objects/IndexedCollectionPrivate.h>
#include <objects/MallocAddress.h>
/* memcpy(), strlen(), strcmp() are gcc builtin's */

@implementation NSCString

/* This is the designated initializer for this class. */
- (id) initWithCStringNoCopy: (char*)byteString
   length: (unsigned int)length
   freeWhenDone: (BOOL)flag
{
  assert(!flag);	/* xxx need to make a subclass to handle this. */
  _count = length;
  _contents_chars = byteString;
  return self;
}

- (Class) classForConnectedCoder: aRmc
{
  /* Make sure that Connection's always send us bycopy,
     i.e. as our own class, not a Proxy class. */
  return [self class];
}

- (void) encodeWithCoder: aCoder
{
  [aCoder encodeValueOfType:@encode(char*) at:&_contents_chars 
	  withName:"Concrete String content_chars"];
}

+ newWithCoder: aCoder
{
  NSCString *n = [super newWithCoder:aCoder];
  [aCoder decodeValueOfType:@encode(char*) at:&(n->_contents_chars)
	  withName:NULL];
  n->_count = strlen(n->_contents_chars);
  return n;
}

/* Empty copy must empty an allocCopy'ed version of self */
- emptyCopy
{
  NSCString *copy = [super emptyCopy];
  OBJC_MALLOC(copy->_contents_chars, char, _count+1);
  copy->_count = 0;
  copy->_contents_chars[0] = '\0';
  return copy;
}

- (const char *) cString
{
  char *r;

  OBJC_MALLOC(r, char, _count);
  memcpy(r, _contents_chars, _count);
  r[_count] = '\0';
  [[[MallocAddress alloc] initWithAddress:r] autorelease];
  return r;
}

- (const char *) _cStringContents
{
  return _contents_chars;
}

- (unsigned) count
{
  return _count;
}

- (unsigned int) cStringLength
{
  return _count;
}

- (unichar) characterAtIndex: (unsigned int)index
{
  /* xxx This should raise an NSException. */
  CHECK_INDEX_RANGE_ERROR(index, _count);
  return (unichar) _contents_chars[index];
}

// FOR IndexedCollection SUPPORT;

- (elt) elementAtIndex: (unsigned)index
{
  elt ret_elt;
  CHECK_INDEX_RANGE_ERROR(index, _count);
  ret_elt.char_u = _contents_chars[index];
  return ret_elt;
}

@end


@implementation NSMutableCString

+ (void) initialize
{
  if ([self class] == [NSMutableCString class])
    {
      class_add_behavior(self, [NSCString class]);
    }
}

typedef struct {
  @defs(NSMutableCString)
} NSMutableCStringStruct;

static inline void
stringIncrementCountAndMakeHoleAt(NSMutableCStringStruct *self, 
				  int index, int size)
{
#ifndef STABLE_MEMCPY
  {
    int i;
    for (i = self->_count; i >= index; i--)
      self->_contents_chars[i+size] = self->_contents_chars[i];
  }
#else
  memcpy(self->_contents_chars + index, 
	 self->_contents_chars + index + size,
	 self->_count - index);
#endif /* STABLE_MEMCPY */
  (self->_count) += size;
}

static inline void
stringDecrementCountAndFillHoleAt(NSMutableCStringStruct *self, 
				  int index, int size)
{
  (self->_count) -= size;
#ifndef STABLE_MEMCPY
  {
    int i;
    for (i = index; i <= self->_count; i++)
      self->_contents_chars[i] = self->_contents_chars[i+size];
  }
#else
  memcpy(self->_contents_chars + index + size,
	 self->_contents_chars + index, 
	 self->_count - index);
#endif /* STABLE_MEMCPY */
}

/* This is the designated initializer for this class */
- initWithCapacity: (unsigned)capacity
{
  _count = 0;
  _capacity = capacity;
  OBJC_MALLOC(_contents_chars, char, _capacity+1);
  _contents_chars[0] = '\0';
  return self;
}

- (void) deleteCharactersInRange: (NSRange)range
{
  stringDecrementCountAndFillHoleAt((NSMutableCStringStruct*)self, 
				    range.location, range.length);
}

- (void) insertString: (NSString*)aString atIndex:(unsigned)index
{
  unsigned c = [aString cStringLength];
  if (_count + c >= _capacity)
    {
      _capacity = MAX(_capacity*2, _count+c);
      OBJC_REALLOC(_contents_chars, char, _capacity);
    }
  stringIncrementCountAndMakeHoleAt((NSMutableCStringStruct*)self, index, c);
  memcpy(_contents_chars + index, [aString _cStringContents], c);
  _contents_chars[_count] = '\0';
}

/* xxx This method may be removed in future. */
- (void) setCString: (const char *)byteString length: (unsigned)length
{
  if (_capacity < length+1)
    {
      _capacity = length+1;
      OBJC_REALLOC(_contents_chars, char, _capacity);
    }
  memcpy(_contents_chars, byteString, length);
  _contents_chars[length] = '\0';
  _count = length;
}

/* Override NSString's designated initializer for CStrings. */
- (id) initWithCStringNoCopy: (char*)byteString
   length: (unsigned int)length
   freeWhenDone: (BOOL)flag
{
  [self initWithCapacity:length];
  [self setCString:byteString length:length];
  return self;
}


/* For IndexedCollecting Protocol and other GNU libobjects conformity. */

/* xxx This should be made to return void, but we need to change
   IndexedCollecting and its conformers */
- removeRange: (IndexRange)range
{
  stringDecrementCountAndFillHoleAt((NSMutableCStringStruct*)self, 
				    range.location, range.length);
  return self;
}

- (void) encodeWithCoder: aCoder
{
  [aCoder encodeValueOfType:@encode(unsigned) at:&_capacity
	  withName:"String capacity"];
  [aCoder encodeValueOfType:@encode(char*) at:&_contents_chars 
	  withName:"String content_chars"];
}

+ newWithCoder: aCoder
{
  NSMutableCString *n;
  unsigned cap;
  
  [aCoder decodeValueOfType:@encode(unsigned) at:&cap withName:NULL];
  n = [[NSMutableCString alloc] initWithCapacity:cap];
  [aCoder decodeValueOfType:@encode(char*) at:&(n->_contents_chars)
	  withName:NULL];
  n->_count = strlen(n->_contents_chars);
  n->_capacity = cap;
  return n;
}

/* For IndexedCollecting protocol */

/* Empty copy must empty an allocCopy'ed version of self */
- emptyCopy
{
  NSMutableCString *copy = [super emptyCopy];
  OBJC_MALLOC(copy->_contents_chars, char, _count+1);
  copy->_count = 0;
  copy->_contents_chars[0] = '\0';
  return copy;
}

- (char) charAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  return _contents_chars[index];
}

- insertElement: (elt)newElement atIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count+1);
  // one for the next char, one for the '\0';
  if (_count+1 >= _capacity)
    {
      _capacity *= 2;
      OBJC_REALLOC(_contents_chars, char, _capacity);
    }
  stringIncrementCountAndMakeHoleAt((NSMutableCStringStruct*)self, index, 1);
  _contents_chars[index] = newElement.char_u;
  _contents_chars[_count] = '\0';
  return self;
}

- (elt) removeElementAtIndex: (unsigned)index
{
  elt ret;

  CHECK_INDEX_RANGE_ERROR(index, _count);
  ret = _contents_chars[index];
  stringDecrementCountAndFillHoleAt((NSMutableCStringStruct*)self, index, 1);
  _contents_chars[_count] = '\0';
  return ret;
}

- (elt) elementAtIndex: (unsigned)index
{
  elt ret_elt;
  CHECK_INDEX_RANGE_ERROR(index, _count);
  ret_elt.char_u = _contents_chars[index];
  return ret_elt;
}

@end
