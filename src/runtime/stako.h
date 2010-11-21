#ifndef STAKO_H
#define STAKO_H

#include <stddef.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "gc/gc.h"

/* StakoValues can hold either a plain integer or a pointer to a
   StakoObject. To allow this, Stako Values reserve the Least
   Significant Bit to tell what the rest of the bits mean. If the LSB
   is a 1, the other 31 or 63 bits (depending on platform) are a
   fixnum. If the LSB is 0, all 32 or 64 bits are a pointer to a
   StakoObject. The pointer must be aligned by 2 (because the LSB will
   always be 0).
 */
typedef size_t StakoValue;

typedef struct {
    StakoValue *data;
    size_t capacity;
    size_t size;
} StakoArray;

typedef void (*StakoWordFunc)(StakoArray *stack);

typedef enum {
    STAKO_WORD,
    STAKO_STRING,
    STAKO_ARRAY
} StakoType;

typedef struct {
    StakoType type;
    void *data;
} StakoObject;

typedef struct {
    char *name;
    StakoWordFunc primitiveFunc;
    StakoArray *body;
} StakoWord;

typedef struct {
    size_t length;
    char *text;
} StakoString;

int StakoValue_isFixnum(StakoValue val);
size_t StakoValue_toFixnum(StakoValue val);
StakoObject *StakoValue_toStakoObject(StakoValue val);

StakoArray *StakoArray_new(size_t capacity);
void StakoArray_ensureCapacity(StakoArray *this, size_t newSize);
void StakoArray_push(StakoArray *this, StakoValue element);
StakoValue StakoArray_pop(StakoArray *this);
void StakoArray_delete(StakoArray *this);

#endif // STAKO_H
