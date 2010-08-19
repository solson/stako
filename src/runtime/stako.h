#ifndef STAKO_H
#define STAKO_H

#include <stddef.h>
#include <stdlib.h>

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
} StakoStack;

typedef void (*StakoWordFunc)(StakoStack *stack);

typedef enum {
    STAKO_WORD
} StakoType;

typedef struct {
    char *name;
    StakoWordFunc body;
} StakoWord;

typedef struct {
    StakoType type;
    union {
        StakoWord word;
    } data;
} StakoObject;

int StakoValue_isFixnum(StakoValue val);
size_t StakoValue_toFixnum(StakoValue val);
StakoObject *StakoValue_toStakoObject(StakoValue val);

StakoStack *StakoStack_new(size_t capacity);
void StakoStack_ensureCapacity(StakoStack *this, size_t newSize);
void StakoStack_push(StakoStack *this, StakoValue element);
StakoValue StakoStack_pop(StakoStack *this);
void StakoStack_delete(StakoStack *this);

#endif // STAKO_H
