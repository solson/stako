import Node, WordType, StackEffect, Quotation
import structs/[ArrayList, Stack]

Definition: class extends Node {
    name: String
    type: WordType
    stackEffect: StackEffect
    body: Quotation
    primitive? := false
    externName: String

    init: func (=name, =type, =stackEffect, =body) {}

    init: func ~primitive (=name, =externName) {
        primitive? = true
    }

    toString: func -> String {
        buf := Buffer new()
        buf append(name). append(": ")
        if(type words[0] != "word")
            buf append(type toString()) .append(" ")
        if(primitive?) {
            buf append("(primitive "). append(externName). append(')')
        } else {
	        buf append(stackEffect toString()). append(' ')
            words := body body
            for(i in 0..words size) {
                buf append(words[i] toString())
                if(i != words size - 1)
                    buf append(' ')
            }
        }
        buf append('.')
        buf toString()
    }
}
