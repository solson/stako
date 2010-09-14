import ast/[Node, Vocab, Definition, Quotation, Word, NumberLiteral], Resolver
use llvm
import llvm/[Core, Target]
import structs/[ArrayList, HashMap], os/Process, io/File

Compiler: class {
    vocab: Vocab
    module: Module
    target: Target
    
    sizeType: Type
    valueType: Type
    stackType: Type
    wordFuncType: Type
    
    outputFile: String
    stakoLib: String

    primitives := HashMap<String, Function> new()

    init: func (=vocab, =outputFile, =stakoLib) {
        module = Module new(vocab name)
        target = Target new(module getTarget())
    }

    compile: func {
        addPrimitives()
        
        Resolver new(vocab) resolve()

        fns := HashMap<String, Function> new()
        for(defn in vocab definitions) {
            fns[defn name] = addWordFunc(defn)
        }

        for(defn in vocab definitions) {
            if(!defn primitive?) {
                fn := fns[defn name]
                builder := fn builder()
                stack := fn args[0]
            
                for(data in defn body body) {
                    match(data) {
                        case word: Word =>
                            addWordCall(builder, stack, fns[word definition name])
                        case num: NumberLiteral =>
                            push(builder, stack, (num number << 1) | 1)
//                    case wrapper: Wrapper =>
//                    case =>
//                        push(data)
                    }
                }

                builder ret()
            }
        }

        addMainFunc(fns["main"])

        File new("stako_tmp") mkdir()

        baseFile := "stako_tmp/" + vocab name
        bitcodeFile := baseFile + ".bc"
        objectFile := baseFile + ".o"
        exeFile := vocab name

        module writeBitcode(bitcodeFile)

        Process new(["llvmc", "-clang", "-c", bitcodeFile, "-o", objectFile]) execute()
        Process new(["clang", stakoLib, objectFile, "-o", outputFile]) execute()
        "[DONE]" println()
    }
    
    addPrimitives: func {
        sizeType = target intPointerType()
        valueType = sizeType
        stackType = Type pointer(Type struct_([Type pointer(sizeType), sizeType, sizeType]))
        wordFuncType = Type function(Type void_(), [stackType])
        
        module addTypeName("StakoStack", stackType)
        
        addPrimitive("StakoValue_isFixnum", Type int32(), [valueType])
        addPrimitive("StakoValue_toInt", sizeType, [valueType])
        addPrimitive("StakoValue_fromInt", valueType, [sizeType])
        addPrimitive("StakoValue_toStakoObject", Type pointer(Type int8()), [sizeType])
        addPrimitive("StakoStack_new", stackType, [sizeType])
        addPrimitive("StakoStack_push", Type void_(), [stackType, valueType])

        addPrimitiveWord("drop")
        addPrimitiveWord("2drop")
        addPrimitiveWord("3drop")
        addPrimitiveWord("dup")
        addPrimitiveWord("2dup")
        addPrimitiveWord("3dup")
        addPrimitiveWord("nip")
        addPrimitiveWord("2nip")
        addPrimitiveWord("pp")
        addPrimitiveWord("fixnum*")
        addPrimitiveWord("fixnum+")
        addPrimitiveWord("fixnum/i")
        addPrimitiveWord("fixnum-mod")
        addPrimitiveWord("fixnum-")
    }

    addPrimitive: func (name: String, ret: Type, args: Type[]) {
        primitives[name] = module addFunction(name, ret, args)
    }

    addPrimitiveWord: func (name: String) {
        externName := "StakoPrimitive_" +
             name replaceAll("*", "__MULT__") replaceAll("+", "__PLUS__") \
                  replaceAll("/", "__DIV__") replaceAll("-", "__MINUS__")
        vocab definitions[name] = Definition new(name, externName)
    }

    addWordFunc: func (defn: Definition) -> Function {
        if(defn primitive?) {
            module addFunction(defn externName, wordFuncType)
        } else {
            fn := module addFunction("Stako_" + defn name, wordFuncType)
            fn args[0] setName("stack")
            fn
        }
    }

    addWordCall: func (builder: Builder, stack: Value, fn: Function) {
        builder call(fn, [stack], "")
    }

    push: func (builder: Builder, stack: Value, num: LLong) {
        builder call(primitives["StakoStack_push"], [stack, LLVMConstInt(valueType, num, 0)], "")
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
