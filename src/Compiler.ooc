import ast/[Node, Vocab, Definition, WordType, StackEffect, Quotation, Word, NumberLiteral, StringLiteral], Resolver
use llvm
import llvm/[Core, Target]
import structs/[ArrayList, HashMap], os/Process, io/File

Compiler: class {
    vocab: Vocab
    module: Module
    target: Target
    
    sizeType: Type
    valueType: Type
    arrayType: Type // Also used for stacks and quotations.
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
            if(defn type words[0] == "word") {
            fn := fns[defn name]
            builder := fn builder()
            stack := fn args[0]
            
            for(data in defn body body) {
                match(data) {
                    case word: Word =>
                        addWordCall(builder, stack, fns[word definition name])
                    case num: NumberLiteral =>
                        push(builder, stack, (num number << 1) | 1)
                    case str: StringLiteral =>
                        s := builder call(primitives["StakoString_new"], [Value constString(str string), Value constInt(sizeType, str string size, false)], "s")
                        obj := builder call(primitives["StakoObject_new"], [Value constInt(Type int32(), 1, false), s], "obj")
                        push(builder, stack, obj)
//                case wrapper: Wrapper =>
//                case =>
//                    push(data)
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

        module writeBitcode(bitcodeFile)

        Process new(["llvmc", "-clang", "-c", bitcodeFile, "-o", objectFile]) execute()
        Process new(["clang", stakoLib, objectFile, "-lpthread", "src/runtime/linux64/libgc.a", "-o", outputFile]) execute()
        "[DONE]" println()
    }
    
    addPrimitives: func {
        sizeType = target intPointerType()
        valueType = sizeType
        arrayType = Type pointer(Type struct_([Type pointer(sizeType), sizeType, sizeType]))
        wordFuncType = Type function(Type void_(), [arrayType])
        
        module addTypeName("StakoArray", arrayType)
        
        addPrimitive("StakoValue_isFixnum", Type int32(), [valueType])
        addPrimitive("StakoValue_toInt", sizeType, [valueType])
        addPrimitive("StakoValue_fromInt", valueType, [sizeType])
        addPrimitive("StakoValue_toStakoObject", Type pointer(Type int8()), [sizeType])
        addPrimitive("StakoObject_new", Type pointer(Type opaque()), [Type int32(), Type pointer(Type opaque())])
        addPrimitive("StakoString_new", Type pointer(Type struct_([sizeType, Type pointer(Type int8())])), [Type pointer(Type int8()), sizeType])
        addPrimitive("StakoArray_new", arrayType, [sizeType])
        addPrimitive("StakoArray_push", Type void_(), [arrayType, valueType])
    }

    addPrimitive: func (name: String, ret: Type, args: Type[]) {
        primitives[name] = module addFunction(name, ret, args)
    }

    primitivizeName: func (name: String) -> String {
        name replaceAll("*", "__MULT__")  replaceAll("+", "__PLUS__")  \
             replaceAll("/", "__DIV__")   replaceAll("-", "__MINUS__") \
             replaceAll("?", "__QUEST__") replaceAll("!", "__BANG__")
    }

    addWordFunc: func (defn: Definition) -> Function {
        if(defn type words[0] == "primitive") {
            fn := module addFunction("StakoPrimitive_" + primitivizeName(defn name), wordFuncType)
            fn
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
        builder call(primitives["StakoArray_push"], [stack, Value constInt(valueType, num, false)], "")
    }

    push: func ~stakoObject (builder: Builder, stack: Value, obj: Value) {
        builder call(primitives["StakoArray_push"], [stack, obj], "")
    }

    addMainFunc: func (mainFn: Function) {
        module addFunction("main", Type int32(),
            [Type int32(), Type pointer(Type pointer(Type int8()))],
            ["argc", "argv"]
        ) build(|builder, args|
            stack := builder call(primitives["StakoArray_new"], [Value constInt(sizeType, 100, false)], "stack")
            builder call(mainFn, [stack], "")
            builder ret(Value constInt(Type int32(), 0, false))
        )
    }
}

// The down-low of StakoValues
// If the Least Significant Bit (LSB) is 1, the value is a literal fixnum.
// If the LSB is 0, the value is a pointer to an object.
// If all bits are 0, the value is the special object `f` (Stako's false/nil)
