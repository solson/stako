import structs/[Stack, ArrayList, HashMap]
import ast/[Node, Module, Definition, Word, Quotation, NumberLiteral, CharLiteral, StringLiteral], Resolver

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
        module vocab["*"] = Definition new(|stack|
            y := stack pop() as NumberLiteral number
            x := stack pop() as NumberLiteral number
            stack push(NumberLiteral new(x * y))
        )
        module vocab["putc"] = Definition new(|stack|
            stack pop() as CharLiteral chr print()
        )
        module vocab["each"] = Definition new(|stack|
            quot := stack pop() as Quotation
            seq := stack pop() as StringLiteral
            for(x in seq string) {
                stack push(CharLiteral new(x))
                this call(quot)
            }
        )
        module vocab["inspect"] = Definition new(|stack|
            stack push(StringLiteral new(stack pop() toString()))
        )
        
        Resolver new(module) resolve()

        if(!module vocab contains?("main"))
            Exception new(This, "No 'main' function in program.") throw()
        mainQuot := module vocab["main"] body
        this call(mainQuot)
    }
}
