import ast/[Node, Vocab, Definition, WordType, StackEffect, Quotation, Word, NumberLiteral, StringLiteral], Resolver
use llvm
import llvm/[Core, Target]
import structs/[List, ArrayList, HashMap], os/Process, io/File

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
        addPrimitive("StakoArray_pop", valueType, [arrayType])
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
        fn: Function
        match(defn type words[0]) {
            case "primitive" => 
                fn = module addFunction("StakoPrimitive_" + primitivizeName(defn name), wordFuncType)
            case "cfunc" =>
                output: Type
                match(defn stackEffect outputs size) {
                    case 0 => output = Type void_()
                    case 1 => output = translateCType(defn stackEffect outputs[0])
                    case => Exception new("cfuncs should have zero or one output!") throw()
                }
                inputs := ArrayList<Type> new()
                for(input in defn stackEffect inputs) {
                    inputs add(translateCType(input))
                }
                fnType := Type function(output, inputs toArray() as Type*, inputs size as UInt, false as Int)
                cfunc := module addFunction(defn name, fnType)
                fn = module addFunction("Stako_" + defn name, wordFuncType)
                fn build(|builder, args|
                    callArgs := ArrayList<Value> new()
                    for(arg in cfunc args backward()) {
                        popped := builder call(primitives["StakoArray_pop"], [args[0]], "")
                        converted := builder call(primitives["StakoValue_toInt"], [popped], "")
                        callArgs add(builder truncOrBitcast(converted, arg type(), ""))
                    }
                    if(callArgs size > 0) callArgs reverse!() // workaround, reverse! is broken on empty lists
                    ret := builder call(cfunc, callArgs toArray() as Value*, callArgs size as UInt, "")
                    if(ret type() != Type void_()) {
                        convertedRet := builder call(primitives["StakoValue_fromInt"], [builder zextOrBitcast(ret, sizeType, "")], "")
                        builder call(primitives["StakoArray_push"], [args[0], convertedRet], "")
                    }
                    builder ret()
                )
            case "word" =>
                fn = module addFunction("Stako_" + defn name, wordFuncType)
        }
        fn args[0] setName("stack")
        fn
    }

    translateCType: func (ctype: String) -> Type {
        pointerDepth := 0
        for(c in ctype backward()) {
            if(c == '*')
                pointerDepth += 1
            else
                break
        }
        baseType := ctype[0..-pointerDepth-1]
        llvmType := match baseType {
            case "char" => Type int8()
            case "short" => Type int16()
            case "int" => Type int32()
            case "long" => Type int64()
            case "size_t" => sizeType
            case "void" => Type void_()
        }
        pointerDepth times(|| llvmType = Type pointer(llvmType))
        llvmType
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
