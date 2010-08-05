import Node, StackEffect, Quotation
import text/Buffer

Definition: class extends Node {
    name: String
    stackEffect: StackEffect
    body: Quotation

    init: func (=name, =stackEffect, =body) {}

    toString: func -> String {
        buf := Buffer new()
        buf append(name). append(": ").
            append(stackEffect toString()). append(' ').
            append(body toString())
        buf toString()
    }
}
