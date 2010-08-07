import Node, CharLiteral
import text/Buffer

StringLiteral: class extends Data {
    string: String

    init: func (=string) {}

    toString: func -> String {
        buf := Buffer new()
        buf append('"')
        for(chr in string) {
            buf append(CharLiteral escape(chr, '"'))
        }
        buf append('"')
        buf toString()
    }
}
