//import ast/[Node, Module, Definition]
use llvm
import llvm/[Core, Target]
import structs/ArrayList

Compiler: class {
//    module: Module

//    init: func (=module) {}

    compile: func {
        llvmModule := Module new("bob")
        
        compileCore(llvmModule)

        llvmModule dump()
    }

    compileCore: func (llvmModule: Module) {
        target := Target new(llvmModule getTarget())
        stakoType := target intPointerType()
        funcType := Type function(Type int1(), [stakoType] as ArrayList<Type>)
        
        isFixnum := llvmModule addFunction(funcType, "is_fixnum")
        isFixnum args[0] setName("val")

        builder := Builder new(isFixnum appendBasicBlock("entry"))

        fixnumBit := builder trunc(isFixnum args[0], Type int1(), "fixnum_bit")
        builder ret(fixnumBit)
    }
}

// The down-low of StakoValues
// If the Least Significant Bit (LSB) is 1, the value is a literal fixnum.
// If the LSB is 0, the value is a pointer to an object.
// If all bits are 0, the value is the special object `f` (Stako's false/nil)
