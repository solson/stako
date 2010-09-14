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

/* Operations on StakoStacks */
StakoStack *StakoStack_new(size_t capacity) {
    StakoStack *this = malloc(sizeof(StakoStack));
    this->data = malloc(sizeof(StakoValue) * capacity);
    this->capacity = capacity;
    this->size = 0;
    return this;
}

void StakoStack_ensureCapacity(StakoStack *this, size_t newSize) {
    if(newSize > this->capacity) {
        this->capacity = newSize * 2;
        this->data = realloc(this->data, this->capacity * sizeof(StakoValue));
    }
}

void StakoStack_push(StakoStack *this, StakoValue element) {
    StakoStack_ensureCapacity(this, this->size + 1);
    this->data[this->size] = element;
    this->size++;
}

StakoValue StakoStack_pop(StakoStack *this) {
    this->size--;
    return this->data[this->size];
}

StakoValue StakoStack_peek(StakoStack *this) {
    return this->data[this->size - 1];
}

StakoValue StakoStack_peek_index(StakoStack *this, size_t index) {
    return this->data[this->size - 1 - index];
}

void StakoStack_delete(StakoStack *this) {
    free(this->data);
    free(this);
}

/* Stako builtins */
// ( x -- )
void StakoPrimitive_drop(StakoStack *stack) {
    StakoStack_pop(stack);
}

// ( x y -- )
void StakoPrimitive_2drop(StakoStack *stack) {
    StakoStack_pop(stack);
    StakoStack_pop(stack);
}

// ( x y z -- )
void StakoPrimitive_3drop(StakoStack *stack) {
    StakoStack_pop(stack);
    StakoStack_pop(stack);
    StakoStack_pop(stack);
}

// ( x -- x x )
void StakoPrimitive_dup(StakoStack *stack) {
    StakoStack_push(stack, StakoStack_peek(stack));
}

// ( x y -- x y x y )
void StakoPrimitive_2dup(StakoStack *stack) {
    StakoStack_push(stack, StakoStack_peek_index(stack, 1));
    StakoStack_push(stack, StakoStack_peek_index(stack, 1));
}

// ( x y z -- x y z x y z )
void StakoPrimitive_3dup(StakoStack *stack) {
    StakoStack_push(stack, StakoStack_peek_index(stack, 2));
    StakoStack_push(stack, StakoStack_peek_index(stack, 2));
    StakoStack_push(stack, StakoStack_peek_index(stack, 2));
}

// ( x y -- x x y )
void StakoPrimitive_dupd(StakoStack *stack) {
    StakoValue y = StakoStack_pop(stack);
    StakoPrimitive_dup(stack);
    StakoStack_push(stack, y);
}

// ( x y -- y )
void StakoPrimitive_nip(StakoStack *stack) {
    StakoValue y = StakoStack_pop(stack);
    StakoStack_pop(stack);
    StakoStack_push(stack, y);
}

// ( x y z -- z )
void StakoPrimitive_2nip(StakoStack *stack) {
    StakoValue z = StakoStack_pop(stack);
    StakoStack_pop(stack);
    StakoStack_pop(stack);
    StakoStack_push(stack, z);
}

// ( x y -- x y x )
void StakoPrimitive_over(StakoStack *stack) {
    StakoStack_push(stack, StakoStack_peek_index(stack, 1));
}

// ( x y z -- x y z x )
void StakoPrimitive_pick(StakoStack *stack) {
    StakoStack_push(stack, StakoStack_peek_index(stack, 2));
}

// ( x y z -- y z x )
void StakoPrimitive_rot(StakoStack *stack) {
    StakoValue z = StakoStack_pop(stack);
    StakoValue y = StakoStack_pop(stack);
    StakoValue x = StakoStack_pop(stack);
    StakoStack_push(stack, y);
    StakoStack_push(stack, z);
    StakoStack_push(stack, x);
}

// ( x y z -- z x y )
void StakoPrimitive___MINUS__rot(StakoStack *stack) {
    StakoValue z = StakoStack_pop(stack);
    StakoValue y = StakoStack_pop(stack);
    StakoValue x = StakoStack_pop(stack);
    StakoStack_push(stack, z);
    StakoStack_push(stack, x);
    StakoStack_push(stack, y);
}

// ( x y -- y x )
void StakoPrimitive_swap(StakoStack *stack) {
    StakoValue y = StakoStack_pop(stack);
    StakoValue x = StakoStack_pop(stack);
    StakoStack_push(stack, y);
    StakoStack_push(stack, x);
}

// ( x y z -- y x z )
void StakoPrimitive_swapd(StakoStack *stack) {
    StakoValue z = StakoStack_pop(stack);
    StakoValue y = StakoStack_pop(stack);
    StakoValue x = StakoStack_pop(stack);
    StakoStack_push(stack, y);
    StakoStack_push(stack, x);
    StakoStack_push(stack, z);
}

// ( n -- )
void StakoPrimitive_pp(StakoStack *stack) {
    size_t x = StakoValue_toInt(StakoStack_pop(stack));
    printf("%zi\n", x);
}

// ( x y -- x*y )
void StakoPrimitive_fixnum__MULT__(StakoStack *stack) {
    size_t y = StakoValue_toInt(StakoStack_pop(stack));
    size_t x = StakoValue_toInt(StakoStack_pop(stack));
    StakoStack_push(stack, StakoValue_fromInt(x * y));
}

// ( x y -- x+y )
void StakoPrimitive_fixnum__PLUS__(StakoStack *stack) {
    size_t y = StakoValue_toInt(StakoStack_pop(stack));
    size_t x = StakoValue_toInt(StakoStack_pop(stack));
    StakoStack_push(stack, StakoValue_fromInt(x + y));
}

// ( x y -- x-y )
void StakoPrimitive_fixnum__MINUS__(StakoStack *stack) {
    size_t y = StakoValue_toInt(StakoStack_pop(stack));
    size_t x = StakoValue_toInt(StakoStack_pop(stack));
    StakoStack_push(stack, StakoValue_fromInt(x - y));
}

// ( x y -- x/y )
void StakoPrimitive_fixnum__DIV__i(StakoStack *stack) {
    size_t y = StakoValue_toInt(StakoStack_pop(stack));
    size_t x = StakoValue_toInt(StakoStack_pop(stack));
    StakoStack_push(stack, StakoValue_fromInt(x / y));
}

// ( x y -- x%y )
void StakoPrimitive_fixnum__MINUS__mod(StakoStack *stack) {
    size_t y = StakoValue_toInt(StakoStack_pop(stack));
    size_t x = StakoValue_toInt(StakoStack_pop(stack));
    StakoStack_push(stack, StakoValue_fromInt(x % y));
}
