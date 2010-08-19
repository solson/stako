import ast/[Node, Vocab, Definition, Quotation, Word], Resolver
use llvm
import llvm/[Core, Target]
import structs/[ArrayList, HashMap]

Compiler: class {
    vocab: Vocab
    module: Module
    target: Target
    
    sizeType: Type
    stackType: Type
    wordFuncType: Type

    init: func (=vocab) {
        module = Module new(vocab name)
        target = Target new(module getTarget())
        
        sizeType = target intPointerType()
        stackType = Type pointer(Type struct_([Type pointer(sizeType), sizeType, sizeType]))
        wordFuncType = Type function(Type void_(), [stackType])
    }

    compile: func {
        Resolver new(vocab) resolve()
        
        addPrimitives()

        fns := HashMap<String, Function> new()
        for(defn in vocab definitions) {
            fns[defn name] = addWordFunc(defn name)
        }

        for(defn in vocab definitions) {
            builder := fns[defn name] builder()
            
            for(data in defn body body) {
                match(data) {
                    case word: Word =>
                        addWordCall(builder, fns[word definition name])
//                    case wrapper: Wrapper =>
//                    case =>
//                        push(data)
                }
            }

            builder ret()
        }

        addMainFunc(fns["main"])

        module dump()
    }

    primitives := HashMap<String, Function> new()
    
    addPrimitives: func {
        module addTypeName("StakoStack", stackType)
        addPrimitive("StakoValue_isFixnum", Type int32(), [sizeType])
        addPrimitive("StakoValue_toFixnum", sizeType, [sizeType])
        addPrimitive("StakoValue_toStakoObject", Type pointer(Type int8()), [sizeType])
        addPrimitive("StakoStack_new", stackType, [sizeType])
    }

    addPrimitive: func (name: String, ret: Type, args: Type[]) {
        primitives[name] = module addFunction(name, ret, args)
    }

    addWordFunc: func (name: String) -> Function {
        fn := module addFunction("Stako_" + name, wordFuncType)
        fn args[0] setName("stack")
        fn
    }

    addWordCall: func (builder: Builder, fn: Function) {
        builder call(fn, [fn args[0]], "")
    }

    addMainFunc: func (mainFn: Function) {
        module addFunction("main", Type void_(),
            [Type int32(), Type pointer(Type pointer(Type int8()))],
            ["argc", "argv"]
        ) build(|builder, args|
            stack := builder call(primitives["StakoStack_new"], [LLVMConstInt(sizeType, 10, 0)], "stack")
            builder call(mainFn, [stack], "")
            builder ret()
        )
    }
}

LLVMConstInt: extern func (Type, ULLong, UInt) -> Value

// The down-low of StakoValues
// If the Least Significant Bit (LSB) is 1, the value is a literal fixnum.
// If the LSB is 0, the value is a pointer to an object.
// If all bits are 0, the value is the special object `f` (Stako's false/nil)
