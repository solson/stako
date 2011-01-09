import Node
import structs/ArrayList

WordType: class extends Node {
    words := ArrayList<String> new()

    init: func {}

    toString: func -> String {
        buf := Buffer new()
        for(i in 0..words size) {
            buf append(words[i])
            if(i != words size - 1)
                buf append(' ')
        }
        buf toString()
    }
}

