import Node

NumberLiteral: class extends Data {
    number: LLong

    init: func (=number) {}

    toString: func -> String {
        number toString()
    }
}
