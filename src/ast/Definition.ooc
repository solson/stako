import Node, StackEffect, Quotation
import text/Buffer, structs/[ArrayList, Stack]

Definition: class extends Node {
    name: String
    stackEffect: StackEffect
    body: Quotation
    primitive? := false
    primitiveBody: Func (Stack<Data>)

    init: func (=name, =stackEffect, =body) {}

    init: func ~primitive (=name, =primitiveBody) {
        primitive? = true
    }

    toString: func -> String {
        buf := Buffer new()
        buf append(name). append(": ")
        if(primitive?) {
            buf append("(primitive)")
        } else {
            if(stackEffect inputs size() > 0 || stackEffect outputs size() > 0)
                buf append(stackEffect toString()). append(' ')
            words := body body
            for(i in 0..words size()) {
                buf append(words[i] toString())
                if(i != words size() - 1)
                    buf append(' ')
            }
        }
        buf append('.')
        buf toString()
    }
}
