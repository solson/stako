import Node

CharLiteral: class extends Data {
    chr: Char

    init: func (=chr) {}

    toString: func -> String {
        "'%s'" format(escape(chr, '\''))
    }

    escape: static func (c, delimiter: Char) -> String {
        if(c == delimiter) {
            "\\" + delimiter
        } else if(c printable?()) {
            c toString()
        } else match(c) {
            case '\a' => "\\a"
            case '\b' => "\\b"
            case '\t' => "\\t"
            case '\n' => "\\n"
            case '\v' => "\\v"
            case '\f' => "\\f"
            case '\r' => "\\r"
            case 0c33 => "\\e"
            case => "\\x%02hhX" format(c)
        }
    }
}
