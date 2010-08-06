import Node, StackEffect, Quotation
import text/Buffer, structs/ArrayList

Definition: class extends Node {
    name: String
    stackEffect: StackEffect
    body: Quotation

    init: func (=name, =stackEffect, =body) {}

    toString: func -> String {
        buf := Buffer new()
        buf append(name). append(": ").
            append(stackEffect toString()). append(' ')
        words := body body
        for(i in 0..words size()) {
            buf append(words[i] toString())
            if(i != words size() - 1)
                buf append(' ')
        }
        buf append('.')
        buf toString()
    }
}
