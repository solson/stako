#ifndef STAKO_H
#define STAKO_H

#include <stddef.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "gc/gc.h"

typedef enum {
	STAKO_WORD,    // data is StakoWord*
	STAKO_STRING,  // data is StakoString*
	STAKO_ARRAY,   // data is StakoArray*
	STAKO_FIXNUM,  // data is size_t
	STAKO_ALIEN    // data is void*
} StakoType;

typedef struct {
    StakoType type;
    void *data;
} StakoObject;

typedef struct {
    StakoObject **data;
    size_t capacity;
    size_t size;
} StakoArray;

typedef struct {
    size_t length;
    char *text;
} StakoString;

typedef void (*StakoWordFunc)(StakoArray *stack);

typedef struct {
    StakoString *name;
    StakoWordFunc primitiveFunc;
    StakoArray *body;
} StakoWord;

StakoObject *StakoObject_new(StakoType type, void *data);
int StakoObject_isType(StakoObject* obj, StakoType type);
void *StakoObject_getData(StakoObject *obj);
StakoType StakoObject_getType(StakoObject *obj);

StakoString *StakoString_new(char *text, size_t length);
StakoString *StakoString_newWithoutLength(char *text);
char *StakoString_toCString(StakoString *str);
char *StakoString_copyToCString(StakoString *str);

StakoArray *StakoArray_new(size_t capacity);
StakoObject *StakoArray_toStakoObject(StakoArray *this);
void StakoArray_ensureCapacity(StakoArray *this, size_t newSize);
void StakoArray_push(StakoArray *this, StakoObject *element);
StakoObject *StakoArray_pop(StakoArray *this);
StakoObject *StakoArray_peek(StakoArray *this);
StakoObject *StakoArray_peek_index(StakoArray *this, size_t index);
void StakoArray_delete(StakoArray *this);

#endif // STAKO_H
