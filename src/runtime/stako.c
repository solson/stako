#include "stako.h"

/* Operations on StakoValues */
int StakoValue_isFixnum(StakoValue val) {
    return val & 1;
}

size_t StakoValue_toFixnum(StakoValue val) {
    return val >> 1;
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

void StakoStack_delete(StakoStack *this) {
    free(this->data);
    free(this);
}
