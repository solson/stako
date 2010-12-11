#include "stako.h"

/* Operations on StakoObjects */
int StakoValue_isType(StakoObject *obj, StakoType type) {
    return obj->type == type;
}

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
    text[str->length] = '\0';
    return text;
}

/* Operations on StakoArrays */
StakoArray *StakoArray_new(size_t capacity) {
    StakoArray *this = GC_MALLOC(sizeof(StakoArray));
    this->data = GC_MALLOC(sizeof(StakoObject *) * capacity);
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
        this->data = GC_REALLOC(this->data, this->capacity * sizeof(StakoObject *));
    }
}

void StakoArray_push(StakoArray *this, StakoObject *element) {
    StakoArray_ensureCapacity(this, this->size + 1);
    this->data[this->size] = element;
    this->size++;
}

StakoObject *StakoArray_pop(StakoArray *this) {
    this->size--;
    return this->data[this->size];
}

StakoObject *StakoArray_peek(StakoArray *this) {
    return this->data[this->size - 1];
}

StakoObject *StakoArray_peek_index(StakoArray *this, size_t index) {
    return this->data[this->size - 1 - index];
}

/* Stako builtins */
// ( size -- address )
void StakoPrimitive_gc__MINUS__malloc(StakoArray *stack) {
	size_t size = (size_t) StakoArray_pop(stack)->data;
    StakoArray_push(stack, StakoObject_new(STAKO_ALIEN, GC_MALLOC(size)));
}

// ( address size -- address )
void StakoPrimitive_gc__MINUS__realloc(StakoArray *stack) {
	size_t size = (size_t) StakoArray_pop(stack)->data;
	void *address = StakoArray_pop(stack)->data;
	StakoArray_push(stack, StakoObject_new(STAKO_ALIEN, GC_REALLOC(address, size)));
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
    StakoObject *y = StakoArray_pop(stack);
    StakoPrimitive_dup(stack);
    StakoArray_push(stack, y);
}

// ( x y -- y )
void StakoPrimitive_nip(StakoArray *stack) {
    StakoObject *y = StakoArray_pop(stack);
    StakoArray_pop(stack);
    StakoArray_push(stack, y);
}

// ( x y z -- z )
void StakoPrimitive_2nip(StakoArray *stack) {
    StakoObject *z = StakoArray_pop(stack);
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
    StakoObject *z = StakoArray_pop(stack);
    StakoObject *y = StakoArray_pop(stack);
    StakoObject *x = StakoArray_pop(stack);
    StakoArray_push(stack, y);
    StakoArray_push(stack, z);
    StakoArray_push(stack, x);
}

// ( x y z -- z x y )
void StakoPrimitive___MINUS__rot(StakoArray *stack) {
    StakoObject *z = StakoArray_pop(stack);
    StakoObject *y = StakoArray_pop(stack);
    StakoObject *x = StakoArray_pop(stack);
    StakoArray_push(stack, z);
    StakoArray_push(stack, x);
    StakoArray_push(stack, y);
}

// ( x y -- y x )
void StakoPrimitive_swap(StakoArray *stack) {
    StakoObject *y = StakoArray_pop(stack);
    StakoObject *x = StakoArray_pop(stack);
    StakoArray_push(stack, y);
    StakoArray_push(stack, x);
}

// ( x y z -- y x z )
void StakoPrimitive_swapd(StakoArray *stack) {
    StakoObject *z = StakoArray_pop(stack);
    StakoObject *y = StakoArray_pop(stack);
    StakoObject *x = StakoArray_pop(stack);
    StakoArray_push(stack, y);
    StakoArray_push(stack, x);
    StakoArray_push(stack, z);
}

static void prettyPrint(StakoObject *obj) {
	StakoArray *array;
	switch(obj->type) {
	case STAKO_WORD:
		puts(((StakoWord*) obj->data)->name->text);
		break;
	case STAKO_STRING:
		printf("\"%s\"", ((StakoString *) obj->data)->text);
		break;
	case STAKO_ARRAY:
		array = (StakoArray *) obj->data;
		putchar('[');
		for(int i = 0; i < array->size; i++) {
			prettyPrint(array->data[i]);
		}
		putchar(']');
		break;
	case STAKO_FIXNUM:
		printf("%ld", (ssize_t) obj->data);
		break;
	case STAKO_ALIEN:
		printf("#<alien:%p>", obj->data);
		break;
	default:
		printf("#<unknown-type:%i>", obj->type);
	}
	putchar('\n');
}

// ( n -- )
void StakoPrimitive_pp(StakoArray *stack) {
	prettyPrint(StakoArray_pop(stack));
}

#define STAKO_MATH_OP(name, op) \
	void name(StakoArray *stack) { \
	    size_t y = (size_t) StakoArray_pop(stack)->data; \
	    size_t x = (size_t) StakoArray_pop(stack)->data; \
	    StakoArray_push(stack, StakoObject_new(STAKO_FIXNUM, (void*) (x op y))); \
	}

// ( x y -- x*y )
STAKO_MATH_OP(StakoPrimitive_fixnum__MULT__, *)

// ( x y -- x+y )
STAKO_MATH_OP(StakoPrimitive_fixnum__PLUS__, +)

// ( x y -- x-y )
STAKO_MATH_OP(StakoPrimitive_fixnum__MINUS__, -)

// ( x y -- x/y )
STAKO_MATH_OP(StakoPrimitive_fixnum__DIV__i, /)

// ( x y -- x%y )
STAKO_MATH_OP(StakoPrimitive_fixnum__MINUS__mod, %)

#undef STAKO_MATH_OP
