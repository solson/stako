OOC?=rock

all:
	${OOC} $(shell llvm-config --ldflags --libs core executionengine jit interpreter native bitwriter) -v -g -linker=g++ +-DNDEBUG +-D_GNU_SOURCE +-D__STDC_LIMIT_MACROS +-D__STDC_CONSTANT_MACROS +-O0 +-fPIC +-fomit-frame-pointer src/stako.ooc

clean:
	rm -rf *_tmp .libs stako

.PHONY: clean
