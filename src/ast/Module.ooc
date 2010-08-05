import Definition
import structs/ArrayList, text/Buffer

Module: class {
    name: String
    definitions := ArrayList<Definition> new()

    init: func (=name) {}

    toString: func -> String {
        buf := Buffer new()
        for(i in 0..definitions size()) {
            buf append(definitions[i] toString())
            if(i != definitions size() - 1)
                buf append('\n')
        }
        buf toString()
    }
}
