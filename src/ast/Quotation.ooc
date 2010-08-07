import Node
import text/Buffer, structs/ArrayList

Quotation: class extends Data {
    body := ArrayList<Data> new()

    init: func (=body) {}

    init: func ~default {}

    toString: func -> String {
        buf := Buffer new()
        buf append('[')
        for(i in 0..body size()) {
            buf append(body[i] toString())
            if(i != body size() - 1)
                buf append(' ')
        }
        buf append(']')
        buf toString()
    }
}