import structs/[Stack, ArrayList, HashMap]
import ast/[Node, Module, Definition, Word, Quotation], Resolver

DataString: class extends Data {
    string: String

    init: func (=string) {}

    toString: func -> String { string }
}

DataChar: class extends Data {
    chr: Char

    init: func (=chr) {}

    toString: func -> String { chr toString() }
}

Interpreter: class {
    datastack := Stack<Data> new()

    call: func (quot: Quotation) {
        for(data in quot body) {
            if(data class == Word) {
                wordDef := data as Word definition
                if(wordDef primitive?) {
                    wordDef primitiveBody(datastack)
                } else {
                    this call(wordDef body)
                }
            } else {
                datastack push(data)
            }
        }
    }

    run: func (module: Module) {
        module vocab["dup"] = Definition new(|stack|
            stack push(stack peek())
        )
        module vocab["putc"] = Definition new(|stack|
            stack pop() as DataChar chr print()
        )
        module vocab["each"] = Definition new(|stack|
            quot := stack pop() as Quotation
            seq := stack pop() as DataString
            for(x in seq string) {
                stack push(DataChar new(x))
                this call(quot)
            }
        )
        
        Resolver new(module) resolve()

        if(!module vocab contains?("main"))
            Exception new(This, "No 'main' function in program.") throw()
        mainQuot := module vocab["main"] body
        this call(mainQuot)
    }
}
