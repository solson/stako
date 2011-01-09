import Definition
import structs/[ArrayList, HashMap]

Vocab: class {
    definitions := HashMap<String, Definition> new()

    toString: func -> String {
        buf := Buffer new()
        values := definitions iterator() toList()
        for(i in 0..values size) {
            buf append(values[i] toString())
            if(i != values size - 1)
                buf append('\n')
        }
        buf toString()
    }
}
