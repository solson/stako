import ast/[Node, Vocab, Definition]
use llvm
import llvm/[Core, Target]
import structs/ArrayList

Compiler: class {
    vocab: Vocab
    module: Module
    target: Target
    sizeType: Type

    init: func (=vocab) {
        module = Module new(vocab name)
        target = Target new(module getTarget())
        sizeType = target intPointerType()
    }

    compile: func {
        compileCore()

        module dump()
    }

    compileCore: func {
        module addFunction("is_fixnum", Type int1(),
            [sizeType],
            ["val"   ]
        ) build(|builder, args|
            fixnumBit := builder trunc(args[0], Type int1(), "fixnum_bit")
            builder ret(fixnumBit)
        )
        
        module addFunction("value_to_int", sizeType,
            [sizeType],
            ["val"   ]
        ) build(|builder, args|
            int_ := builder lshr(args[0], LLVMConstInt(sizeType, 1, 0), "int")
            builder ret(int_)
        )
        
        module addFunction("value_to_ptr", Type pointer(Type int_(1337), 0),
            [sizeType],
            ["val"   ]
        ) build(|builder, args|
//            Value constInt(sizeType, 1)
            mask := builder not(LLVMConstInt(sizeType, 1, 0), "mask")
            int_ := builder and(args[0], mask, "int")
            ptr := builder inttoptr(int_, Type pointer(Type int_(1337), 0), "ptr")
            builder ret(ptr)
        )
    }
}

LLVMConstInt: extern func (Type, ULLong, UInt) -> Value

// The down-low of StakoValues
// If the Least Significant Bit (LSB) is 1, the value is a literal fixnum.
// If the LSB is 0, the value is a pointer to an object.
// If all bits are 0, the value is the special object `f` (Stako's false/nil)
