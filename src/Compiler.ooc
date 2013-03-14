import ast/[Node, Vocab, Definition, WordType, StackEffect, Quotation, Word, NumberLiteral, StringLiteral], Resolver
use llvm
import llvm/[Core, Target]
import structs/[List, ArrayList, HashMap], os/Process, io/File

Compiler: class {
    vocab: Vocab
    module: LModule
    target: LTarget

    sizeType, objType, arrayType, wordType, strType, fixnumType, alienType,
        wordFuncType, voidPtrType: LType
    
    outputFile: String
    stakoLib: String

    primitives := HashMap<String, LFunction> new()

    init: func (=vocab, =outputFile, =stakoLib) {
        module = LModule new("stako")
        target = LTarget new(module getTarget())
    }

    compile: func {
        addPrimitives()
        
        Resolver new(vocab) resolve()

        fns := HashMap<String, LFunction> new()
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
                        push(builder, stack, newFixnum(builder, num number))
                    case str: StringLiteral =>
	                    push(builder, stack, newString(builder, str string))
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

        baseFile := "stako_tmp/" + outputFile
        bitcodeFile := baseFile + ".bc"
        objectFile := baseFile + ".o"

        module writeBitcode(bitcodeFile)

        Process new(["llvmc", "-clang", "-c", bitcodeFile, "-o", objectFile]) execute()
        Process new(["clang", stakoLib, objectFile, "-lpthread", "src/runtime/linux64/libgc.a", "-o", outputFile]) execute()
        "\33[1;32m[DONE]\33[m" println()
    }
    
    addPrimitives: func {
	    sizeType     = target intPointerType()
        voidPtrType  = LType pointer(LType int8()) // C's void*
        objType      = LType pointer(LType struct_([LType int32(), voidPtrType]))
        arrayType    = LType pointer(LType struct_([LType pointer(objType), sizeType, sizeType]))
        strType      = LType pointer(LType struct_([sizeType, LType pointer(LType int8())]))
        wordFuncType = LType function(LType void_(), [arrayType])
        wordType     = LType pointer(LType struct_([strType, LType pointer(wordFuncType), arrayType]))
        fixnumType   = sizeType
        alienType    = LType pointer(voidPtrType)

        /*module addTypeName("StakoObject", objType)
        module addTypeName("StakoString", strType)
        module addTypeName("StakoWord", wordType)
        module addTypeName("StakoWordFunc", wordFuncType)
        module addTypeName("StakoArray", arrayType)*/
        
        addPrimitive("StakoObject_new",              objType,      [LType int32(), voidPtrType])
        addPrimitive("StakoObject_isType",           Type int32(), [objType, LType int32()])
        addPrimitive("StakoObject_getData",          voidPtrType,  [objType])
        addPrimitive("StakoObject_getType",          LType int32(), [objType])

        addPrimitive("StakoString_new",              strType,      [LType pointer(LType int8()), sizeType])
        addPrimitive("StakoString_newWithoutLength", voidPtrType,  [LType pointer(LType int8())])
        addPrimitive("StakoString_toCString",        Type pointer(LType int8()), [strType])
        addPrimitive("StakoString_copyToCString",    Type pointer(LType int8()), [strType])
        
        addPrimitive("StakoArray_new",               arrayType,    [sizeType])
        addPrimitive("StakoArray_push",              LType void_(), [arrayType, objType])
        addPrimitive("StakoArray_pop",               objType,    [arrayType])
    }

    addPrimitive: func (name: String, ret: Type, args: Type[]) {
        primitives[name] = module addFunction(name, ret, args)
    }

    primitivizeName: func (name: String) -> String {
        name replaceAll("*", "__MULT__")  replaceAll("+", "__PLUS__")  \
             replaceAll("/", "__DIV__")   replaceAll("-", "__MINUS__") \
             replaceAll("?", "__QUEST__") replaceAll("!", "__BANG__")
    }

    callPrimitive: func (builder: LBuilder, name: String, args: Value[]) -> Value {
	    builder call(primitives[name], args)
    }

    addWordFunc: func (defn: Definition) -> LFunction {
        fn: LFunction
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
        
        inputs := ArrayList<LType> new()
        signs := ArrayList<Bool> new()
        for(input in defn stackEffect inputs) {
	        (type, signed?) := translateCType(input)
	        inputs add(type)
	        signs add(signed?)
        }
        cfunc := module addFunction(defn name, LType function(output, inputs))
        
        fn = module addFunction("Stako_" + defn name, wordFuncType)
        fn build(|builder, args|
	        stack := args[0]
	        // --- Aquire arguments from datastack ---
	        callArgs := ArrayList<Value> new()
	        i := 0
	        for(arg in cfunc args backward()) {
		        signed? := signs[i]
		        obj := callPrimitive(builder, "StakoArray_pop", [stack])
		        data := callPrimitive(builder, "StakoObject_getData", [obj])
	            if(arg type() == Type pointer(Type int8())) {
	                // TODO: Check if it's actually a StakoString.
		            str := builder pointerCast(data, strType, "")
		            cstr := callPrimitive(builder, "StakoString_toCString", [str])
	                callArgs add(cstr)
	            } else {
		            fixnum := builder ptrtoint(data, sizeType, "")
	                callArgs add(builder intCast(fixnum, arg type(), ""))
	            }
	            i += 1
	        }
	        if(callArgs size > 0) callArgs reverse!() // workaround, reverse! is broken on empty lists
	        
	        // --- Call the C function ---
	        ret := builder call(cfunc, callArgs)
	        
	        // -- Deal with the return value ---
	        if(ret type() == LType pointer(LType int8())) {
	            push(builder, stack, newString(builder, ret))
	        } else if(ret type() != LType void_()) {
	            push(builder, stack, newFixnum(builder, ret))
	        }
	        builder ret()
        )
        fn
    }

/*    castCInt: func (builder: Builder, value: Value, targetType: Type, signed?: Bool) -> Value {
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
*/

    translateCType: func (ctype: String) -> (Type, Bool) {
	    modifier: String
	    signed? := true
	    split := ctype indexOf('-')
	    if(split != -1) {
	        modifier := ctype[0..split]
	        ctype = ctype[split+1..-1]
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
        
        if(split != -1) {
	        match modifier {
	            case "signed"   => signed? = true
	            case "unsigned" => signed? = false
	            case => Exception new("Invalid c-type modifier '%s'." format(modifier))
	        }
        }
        
        return (llvmType, signed?)
    }

    addWordCall: func (builder: Builder, stack: Value, fn: Function) {
        builder call(fn, [stack])
    }

/*    push: func (builder: Builder, stack: Value, num: LLong) {
	    callPrimitive(builder, "StakoArray_push", [stack, Value constInt(valueType, num, false)])
    }
*/

    push: func ~stakoObject (builder: Builder, stack: Value, obj: Value) {
	    callPrimitive(builder, "StakoArray_push", [stack, obj])
    }

    addMainFunc: func (mainFn: Function) {
        module addFunction("main", Type int32(),
            [Type int32(), Type pointer(Type pointer(Type int8()))],
            ["argc", "argv"]
        ) build(|builder, args|
	        stack := callPrimitive(builder, "StakoArray_new", [Value constInt(sizeType, 100, false)])
            builder call(mainFn, [stack])
            builder ret(Value constInt(Type int32(), 0, false))
        )
    }

    newObject: func (builder: Builder, type: StakoType, data: Value) -> Value {
	    voidPtrData := builder pointerCast(data, voidPtrType, "")
        callPrimitive(builder, "StakoObject_new", [type llvmValue(), voidPtrData])
    }

    newString: func (builder: Builder, text: Value) -> Value {
        str := callPrimitive(builder, "StakoString_newWithoutLength", [text])
        newObject(builder, StakoType string, str)
    }

    newString: func ~literal (builder: Builder, text: String) -> Value {
        str := callPrimitive(builder, "StakoString_new", [builder globalStringPtr(text, ""),
		        Value constInt(sizeType, text size, false)])
        newObject(builder, StakoType string, str)
    }

    newFixnum: func (builder: Builder, number: Value) -> Value {
	    ptr := builder inttoptr(number, voidPtrType, "")
        newObject(builder, StakoType fixnum, ptr)
    }

    newFixnum: func ~literal (builder: Builder, number: LLong) -> Value {
	    fixnum := Value constInt(sizeType, number, false)
	    ptr := builder inttoptr(fixnum, voidPtrType, "")
        newObject(builder, StakoType fixnum, ptr)
    }
}

StakoType: enum {
	word = 0, string, array, fixnum, alien
}

extend StakoType {
	llvmValue: func -> Value {
		Value constInt(Type int32(), this as ULLong, false)
	}
}
