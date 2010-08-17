import structs/[Stack, ArrayList, HashMap]
import ast/[Node, Vocab, Definition, Word, Quotation, NumberLiteral, CharLiteral, StringLiteral, Wrapper], Resolver

Interpreter: class {
    datastack := Stack<Data> new()

    call: func (quot: Quotation) {
        for(data in quot body) {
            match(data) {
                case word: Word =>
                    wordDef := word definition
                    if(wordDef primitive?) {
                        wordDef primitiveBody(datastack)
                    } else {
                        this call(wordDef body)
                    }
                case wrapper: Wrapper =>
                    datastack push(wrapper data)
                case =>
                    datastack push(data)
            }
        }
    }

    run: func (vocab: Vocab) {
        vocab definitions["dup"] = Definition new("dup", |stack|
            stack push(stack peek())
        )
        vocab definitions["*"] = Definition new("*", |stack|
            y := stack pop() as NumberLiteral number
            x := stack pop() as NumberLiteral number
            stack push(NumberLiteral new(x * y))
        )
        vocab definitions["write1"] = Definition new("write1", |stack|
            stack pop() as CharLiteral chr print()
        )
        vocab definitions["each"] = Definition new("each", |stack|
            quot := stack pop() as Quotation
            seq := stack pop() as StringLiteral
            for(x in seq string) {
                stack push(CharLiteral new(x))
                this call(quot)
            }
        )
        vocab definitions["inspect"] = Definition new("inspect", |stack|
            stack push(StringLiteral new(stack pop() toString()))
        )
        vocab definitions["see"] = Definition new("see", |stack|
            stack pop() as Word definition toString() println()
        )
        
        Resolver new(vocab) resolve()

        if(!vocab definitions contains?("main"))
            Exception new(This, "No 'main' function in program.") throw()
        mainQuot := vocab definitions["main"] body
        this call(mainQuot)
    }
}
