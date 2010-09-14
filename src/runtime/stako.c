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
    if(this->size == 0)
        puts("Tried to pop an empty Stako stack.");
    this->size--;
    return this->data[this->size];
}

StakoValue StakoStack_peek(StakoStack *this) {
    if(this->size == 0)
        puts("Tried to peek an empty Stako stack.");
    return this->data[this->size - 1];
}

void StakoStack_delete(StakoStack *this) {
    free(this->data);
    free(this);
}

/* Stako builtins */
void StakoPrimitive_drop(StakoStack *stack) {
    StakoStack_pop(stack);
}

void StakoPrimitive_dup(StakoStack *stack) {
    StakoStack_push(stack, StakoStack_peek(stack));
}

void StakoPrimitive_pp(StakoStack *stack) {
    size_t x = StakoValue_toInt(StakoStack_pop(stack));
    printf("%zi\n", x);
}

void StakoPrimitive_fixnum__MULT__(StakoStack *stack) {
    size_t y = StakoValue_toInt(StakoStack_pop(stack));
    size_t x = StakoValue_toInt(StakoStack_pop(stack));
    StakoStack_push(stack, StakoValue_fromInt(x * y));
}

void StakoPrimitive_fixnum__PLUS__(StakoStack *stack) {
    size_t y = StakoValue_toInt(StakoStack_pop(stack));
    size_t x = StakoValue_toInt(StakoStack_pop(stack));
    StakoStack_push(stack, StakoValue_fromInt(x + y));
}

void StakoPrimitive_fixnum__MINUS__(StakoStack *stack) {
    size_t y = StakoValue_toInt(StakoStack_pop(stack));
    size_t x = StakoValue_toInt(StakoStack_pop(stack));
    StakoStack_push(stack, StakoValue_fromInt(x - y));
}

void StakoPrimitive_fixnum__DIV__i(StakoStack *stack) {
    size_t y = StakoValue_toInt(StakoStack_pop(stack));
    size_t x = StakoValue_toInt(StakoStack_pop(stack));
    StakoStack_push(stack, StakoValue_fromInt(x / y));
}

void StakoPrimitive_fixnum__MINUS__mod(StakoStack *stack) {
    size_t y = StakoValue_toInt(StakoStack_pop(stack));
    size_t x = StakoValue_toInt(StakoStack_pop(stack));
    StakoStack_push(stack, StakoValue_fromInt(x % y));
}
