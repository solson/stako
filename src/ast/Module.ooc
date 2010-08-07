import Definition
import structs/[ArrayList, HashMap], text/Buffer

Module: class {
    name: String
    definitions := ArrayList<Definition> new()
    vocab := HashMap<String, Definition> new()

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
