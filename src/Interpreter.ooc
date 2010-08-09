import structs/[Stack, ArrayList, HashMap]
import ast/[Node, Module, Definition, Word, Quotation, NumberLiteral, CharLiteral, StringLiteral, Wrapper], Resolver

Interpreter: class {
    datastack := Stack<Data> new()

    call: func (quot: Quotation) {
        for(data in quot body) {
            match(data class) {
                case Word =>
                    wordDef := data as Word definition
                    if(wordDef primitive?) {
                        wordDef primitiveBody(datastack)
                    } else {
                        this call(wordDef body)
                    }
                case Wrapper =>
                    wrapper := data as Wrapper
                    datastack push(wrapper data)
                case =>
                    datastack push(data)
            }
        }
    }

    run: func (module: Module) {
        module vocab["dup"] = Definition new("dup", |stack|
            stack push(stack peek())
        )
        module vocab["*"] = Definition new("*", |stack|
            y := stack pop() as NumberLiteral number
            x := stack pop() as NumberLiteral number
            stack push(NumberLiteral new(x * y))
        )
        module vocab["write1"] = Definition new("write1", |stack|
            stack pop() as CharLiteral chr print()
        )
        module vocab["each"] = Definition new("each", |stack|
            quot := stack pop() as Quotation
            seq := stack pop() as StringLiteral
            for(x in seq string) {
                stack push(CharLiteral new(x))
                this call(quot)
            }
        )
        module vocab["inspect"] = Definition new("inspect", |stack|
            stack push(StringLiteral new(stack pop() toString()))
        )
        module vocab["see"] = Definition new("see", |stack|
            stack pop() as Word definition toString() println()
        )
        
        Resolver new(module) resolve()

        if(!module vocab contains?("main"))
            Exception new(This, "No 'main' function in program.") throw()
        mainQuot := module vocab["main"] body
        this call(mainQuot)
    }
}
