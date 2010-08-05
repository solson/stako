import Node
import structs/ArrayList, text/Buffer

StackEffect: class extends Node {
    inputs  := ArrayList<String> new()
    outputs := ArrayList<String> new()

    init: func (=inputs, =outputs) {}

    init: func ~default {}

    toString: func -> String {
        buf := Buffer new()
        buf append('(')
        for(word in inputs) {
            buf append(word) .append(' ')
        }
        buf append("--")
        for(word in outputs) {
            buf append(' ') .append(word)
        }
        buf append(')')
        buf toString()
    }
}
