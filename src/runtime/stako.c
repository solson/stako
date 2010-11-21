#include "stako.h"

/* Operations on StakoValues */
int StakoValue_isFixnum(StakoValue val) {
    return val & 1;
}

size_t StakoValue_toInt(StakoValue val) {
    return val >> 1;
}

StakoValue StakoValue_fromInt(size_t val) {
    return (val << 1) | 1;
}

StakoObject *StakoValue_toStakoObject(StakoValue val) {
    return (StakoObject*)val;
}

StakoValue StakoValue_fromStakoObject(StakoObject *obj) {
    return (StakoValue)obj;
}

/* Operations on StakoObjects */
StakoObject *StakoObject_new(StakoType type, void *data) {
    StakoObject *obj = GC_MALLOC(sizeof(StakoObject));
    obj->type = type;
    obj->data = data;
    return obj;
}

void *StakoObject_getData(StakoObject *obj) {
    return obj->data;
}

StakoType StakoObject_getType(StakoObject *obj) {
    return obj->type;
}

/* Operations on StakoStrings */
StakoString *StakoString_new(char *text, size_t length) {
    StakoString *str = GC_MALLOC(sizeof(StakoString));
    str->length = length;
    str->text = text;
    return str;
}

StakoString *StakoString_newWithoutLength(char *text) {
    StakoString *str = GC_MALLOC(sizeof(StakoString));
    str->length = strlen(text);
    str->text = text;
    return str;
}

char *StakoString_toCString(StakoString *str) {
    return str->text;
}

char *StakoString_copyToCString(StakoString *str) {
    char *text = GC_MALLOC(str->length + 1);
    memcpy(text, str->text, str->length + 1);
    return text;
}

/* Operations on StakoArrays */
StakoArray *StakoArray_new(size_t capacity) {
    StakoArray *this = GC_MALLOC(sizeof(StakoArray));
    this->data = GC_MALLOC(sizeof(StakoValue) * capacity);
    this->capacity = capacity;
    this->size = 0;
    return this;
}

StakoObject *StakoArray_toStakoObject(StakoArray *this) {
    return StakoObject_new(STAKO_ARRAY, this);
}

void StakoArray_ensureCapacity(StakoArray *this, size_t newSize) {
    if(newSize > this->capacity) {
        this->capacity = newSize * 2;
        this->data = GC_REALLOC(this->data, this->capacity * sizeof(StakoValue));
    }
}

void StakoArray_push(StakoArray *this, StakoValue element) {
    StakoArray_ensureCapacity(this, this->size + 1);
    this->data[this->size] = element;
    this->size++;
}

StakoValue StakoArray_pop(StakoArray *this) {
    this->size--;
    return this->data[this->size];
}

StakoValue StakoArray_peek(StakoArray *this) {
    return this->data[this->size - 1];
}

StakoValue StakoArray_peek_index(StakoArray *this, size_t index) {
    return this->data[this->size - 1 - index];
}

/* Stako builtins */
// ( size -- address )
void StakoPrimitive_gc__MINUS__malloc(StakoArray *stack) {
    size_t size = StakoValue_toInt(StakoArray_pop(stack));
    StakoArray_push(stack, StakoValue_fromInt((size_t)GC_MALLOC(size)));
}

// ( address size -- address )
void StakoPrimitive_gc__MINUS__realloc(StakoArray *stack) {
    size_t size = StakoValue_toInt(StakoArray_pop(stack));
    size_t address = StakoValue_toInt(StakoArray_pop(stack));
    StakoArray_push(stack, StakoValue_fromInt((size_t)GC_REALLOC((void*)address, size)));
}

// ( x -- )
void StakoPrimitive_drop(StakoArray *stack) {
    StakoArray_pop(stack);
}

// ( x y -- )
void StakoPrimitive_2drop(StakoArray *stack) {
    StakoArray_pop(stack);
    StakoArray_pop(stack);
}

// ( x y z -- )
void StakoPrimitive_3drop(StakoArray *stack) {
    StakoArray_pop(stack);
    StakoArray_pop(stack);
    StakoArray_pop(stack);
}

// ( x -- x x )
void StakoPrimitive_dup(StakoArray *stack) {
    StakoArray_push(stack, StakoArray_peek(stack));
}

// ( x y -- x y x y )
void StakoPrimitive_2dup(StakoArray *stack) {
    StakoArray_push(stack, StakoArray_peek_index(stack, 1));
    StakoArray_push(stack, StakoArray_peek_index(stack, 1));
}

// ( x y z -- x y z x y z )
void StakoPrimitive_3dup(StakoArray *stack) {
    StakoArray_push(stack, StakoArray_peek_index(stack, 2));
    StakoArray_push(stack, StakoArray_peek_index(stack, 2));
    StakoArray_push(stack, StakoArray_peek_index(stack, 2));
}

// ( x y -- x x y )
void StakoPrimitive_dupd(StakoArray *stack) {
    StakoValue y = StakoArray_pop(stack);
    StakoPrimitive_dup(stack);
    StakoArray_push(stack, y);
}

// ( x y -- y )
void StakoPrimitive_nip(StakoArray *stack) {
    StakoValue y = StakoArray_pop(stack);
    StakoArray_pop(stack);
    StakoArray_push(stack, y);
}

// ( x y z -- z )
void StakoPrimitive_2nip(StakoArray *stack) {
    StakoValue z = StakoArray_pop(stack);
    StakoArray_pop(stack);
    StakoArray_pop(stack);
    StakoArray_push(stack, z);
}

// ( x y -- x y x )
void StakoPrimitive_over(StakoArray *stack) {
    StakoArray_push(stack, StakoArray_peek_index(stack, 1));
}

// ( x y z -- x y z x )
void StakoPrimitive_pick(StakoArray *stack) {
    StakoArray_push(stack, StakoArray_peek_index(stack, 2));
}

// ( x y z -- y z x )
void StakoPrimitive_rot(StakoArray *stack) {
    StakoValue z = StakoArray_pop(stack);
    StakoValue y = StakoArray_pop(stack);
    StakoValue x = StakoArray_pop(stack);
    StakoArray_push(stack, y);
    StakoArray_push(stack, z);
    StakoArray_push(stack, x);
}

// ( x y z -- z x y )
void StakoPrimitive___MINUS__rot(StakoArray *stack) {
    StakoValue z = StakoArray_pop(stack);
    StakoValue y = StakoArray_pop(stack);
    StakoValue x = StakoArray_pop(stack);
    StakoArray_push(stack, z);
    StakoArray_push(stack, x);
    StakoArray_push(stack, y);
}

// ( x y -- y x )
void StakoPrimitive_swap(StakoArray *stack) {
    StakoValue y = StakoArray_pop(stack);
    StakoValue x = StakoArray_pop(stack);
    StakoArray_push(stack, y);
    StakoArray_push(stack, x);
}

// ( x y z -- y x z )
void StakoPrimitive_swapd(StakoArray *stack) {
    StakoValue z = StakoArray_pop(stack);
    StakoValue y = StakoArray_pop(stack);
    StakoValue x = StakoArray_pop(stack);
    StakoArray_push(stack, y);
    StakoArray_push(stack, x);
    StakoArray_push(stack, z);
}

// ( n -- )
void StakoPrimitive_pp(StakoArray *stack) {
    size_t x = StakoValue_toInt(StakoArray_pop(stack));
    printf("%zi\n", x);
}

// ( x y -- x*y )
void StakoPrimitive_fixnum__MULT__(StakoArray *stack) {
    size_t y = StakoValue_toInt(StakoArray_pop(stack));
    size_t x = StakoValue_toInt(StakoArray_pop(stack));
    StakoArray_push(stack, StakoValue_fromInt(x * y));
}

// ( x y -- x+y )
void StakoPrimitive_fixnum__PLUS__(StakoArray *stack) {
    size_t y = StakoValue_toInt(StakoArray_pop(stack));
    size_t x = StakoValue_toInt(StakoArray_pop(stack));
    StakoArray_push(stack, StakoValue_fromInt(x + y));
}

// ( x y -- x-y )
void StakoPrimitive_fixnum__MINUS__(StakoArray *stack) {
    size_t y = StakoValue_toInt(StakoArray_pop(stack));
    size_t x = StakoValue_toInt(StakoArray_pop(stack));
    StakoArray_push(stack, StakoValue_fromInt(x - y));
}

// ( x y -- x/y )
void StakoPrimitive_fixnum__DIV__i(StakoArray *stack) {
    size_t y = StakoValue_toInt(StakoArray_pop(stack));
    size_t x = StakoValue_toInt(StakoArray_pop(stack));
    StakoArray_push(stack, StakoValue_fromInt(x / y));
}

// ( x y -- x%y )
void StakoPrimitive_fixnum__MINUS__mod(StakoArray *stack) {
    size_t y = StakoValue_toInt(StakoArray_pop(stack));
    size_t x = StakoValue_toInt(StakoArray_pop(stack));
    StakoArray_push(stack, StakoValue_fromInt(x % y));
}
