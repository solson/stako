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
                        s := builder call(primitives["StakoString_new"], [builder globalStringPtr(str string, ""), Value constInt(sizeType, str string size, false)], "str")
                        obj := builder call(primitives["StakoObject_new"], [Value constInt(Type int32(), 1, false), s], "obj")
                        val := builder call(primitives["StakoValue_fromStakoObject"], [obj], "val")
                        push(builder, stack, val)
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
        "\33[1;32m[DONE]\33[m" println()
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
        addPrimitive("StakoValue_fromStakoObject", sizeType, [Type pointer(Type int8())])
        addPrimitive("StakoObject_new", Type pointer(Type int8()), [Type int32(), Type pointer(Type int8())])
        addPrimitive("StakoObject_getData", Type pointer(Type int8()), [Type pointer(Type int8())])
        addPrimitive("StakoString_new", Type pointer(Type int8()), [Type pointer(Type int8()), sizeType])
        addPrimitive("StakoString_newWithoutLength", Type pointer(Type int8()), [Type pointer(Type int8())])
        addPrimitive("StakoString_toCString", Type pointer(Type int8()), [Type pointer(Type int8())])
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
	            fn = addCFunc(defn)
            case "word" =>
                fn = module addFunction("Stako_" + defn name, wordFuncType)
        }
        fn args[0] setName("stack")
        fn
    }

    addCFunc: func (defn: Definition) -> Function {
	    fn: Function
	    
        output: Type
        outputSigned? := false
        if(defn stackEffect outputs size == 0) {
	        output = Type void_()
        } else if(defn stackEffect outputs size == 1) {
	        // Odd hack here to avoid odd rock bug.
	        (output1, outputSigned1?) := translateCType(defn stackEffect outputs[0])
	        output = output1
	        outputSigned? = outputSigned1?
        } else {
	        Exception new("cfuncs should have zero or one output!") throw()
        }
        
        inputs := ArrayList<Type> new()
        signs := ArrayList<Bool> new()
        for(input in defn stackEffect inputs) {
	        (type, signed?) := translateCType(input)
	        inputs add(type)
	        signs add(signed?)
        }
        cfunc := module addFunction(defn name, Type function(output, inputs))
        
        fn = module addFunction("Stako_" + defn name, wordFuncType)
        fn build(|builder, args|
	        // --- Aquire arguments from datastack ---
	        callArgs := ArrayList<Value> new()
	        i := 0
	        for(arg in cfunc args backward()) {
		        signed? := signs[i]
	            popped := builder call(primitives["StakoArray_pop"], [args[0]])
	            if(arg type() == Type pointer(Type int8())) {
	                obj := builder call(primitives["StakoValue_toStakoObject"], [popped])
	                // TODO: Check if it's actually a StakoString.
	                str := builder call(primitives["StakoObject_getData"], [obj])
	                cstr := builder call(primitives["StakoString_toCString"], [str])
	                callArgs add(cstr)
	            } else {
	                converted := builder call(primitives["StakoValue_toInt"], [popped])
	                callArgs add(castCInt(builder, converted, arg type(), signed?))
	            }
	            i += 1
	        }
	        if(callArgs size > 0) callArgs reverse!() // workaround, reverse! is broken on empty lists
	        
	        // --- Call the C function ---
	        ret := builder call(cfunc, callArgs)
	        
	        // -- Deal with the return value ---
	        if(ret type() == Type pointer(Type int8())) {
	            s := builder call(primitives["StakoString_newWithoutLength"], [ret], "str")
	            obj := builder call(primitives["StakoObject_new"], [Value constInt(Type int32(), 1, false), s], "obj")
	            val := builder call(primitives["StakoValue_fromStakoObject"], [obj], "val")
	            builder call(primitives["StakoArray_push"], [args[0], val])
	        } else if(ret type() != Type void_()) {
		        castedInt := castCInt(builder, ret, sizeType, outputSigned?)
	            convertedRet := builder call(primitives["StakoValue_fromInt"], [castedInt])
	            builder call(primitives["StakoArray_push"], [args[0], convertedRet])
	        }
	        builder ret()
        )
        fn
    }

    castCInt: func (builder: Builder, value: Value, targetType: Type, signed?: Bool) -> Value {
        origWidth := value type() getIntTypeWidth()
	    targetWidth := targetType getIntTypeWidth()
	    if(origWidth == targetWidth) {
		    value
	    } else if(origWidth > targetWidth) {
		    builder trunc(value, targetType, "")
	    } else {
		    if(signed?)
			    builder sext(value, targetType, "")
		    else
			    builder zext(value, targetType, "")
	    }
    }

    translateCType: func (ctype: String) -> (Type, Bool) {
	    signed? := true
	    split := ctype indexOf('-')
	    if(split != -1) {
	        modifier := ctype[0..split]
	        ctype = ctype[split+1..-1]
	        match modifier {
		        case "signed"   => signed? = true
		        case "unsigned" => signed? = false
		        case => Exception new("Invalid c-type modifier '%s'." format(modifier))
		    }
	    }
	    
        pointerDepth := 0
        for(c in ctype backward()) {
            if(c == '*')
                pointerDepth += 1
            else
                break
        }
        baseType := ctype[0..-pointerDepth-1]
        llvmType := match baseType {
            case "char"   => signed? = false; Type int8()
            case "short"  => Type int16()
            case "int"    => Type int32()
            case "long"   => Type int64()
            case "size_t" => signed? = false; sizeType
            case "void"   => Type void_()
        }
        pointerDepth times(|| llvmType = Type pointer(llvmType))
        return (llvmType, signed?)
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
