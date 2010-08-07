import io/[File, FileReader, Reader], text/Buffer, structs/ArrayList
import ast/[Node, Module, Definition, Word, StackEffect, Quotation, CharLiteral, StringLiteral]

Parser: class {
    module: Module
    reader: Reader
    
    init: func (=module, =reader) {}

    init: func ~withFileName (=module, fileName: String) {
        reader = FileReader new(fileName)
    }

    parse: func {
        while(reader hasNext?()) {
            c := reader peek()
            if(c whitespace?() || c == '#') {
                skipWhitespace()
            } else if(wordChar?(c)) {
                module definitions add(parseDefinition())
            } else {
                ParsingError new("Unexpected character: '%c', expected a word definition." format(c)) throw()
            }
        }
    }

    parseData: func -> Data {
        c := reader peek()
        if(wordChar?(c)) {
            Word new(parseWord())
        } else if(c == '[') {
            reader read()
            Quotation new(parseUntil(']'))
        } else if(c == '\'') {
            parseCharLiteral()
        } else if(c == '"') {
            parseStringLiteral()
        } else {
            ParsingError new("Unexpected character: '%c', expected a word or quotation." format(c)) throw()
            null
        }
    }

    parseCharLiteral: func -> CharLiteral {
        reader read() // skip opening single quote
        assertHasMore("Unterminated character literal met end of file.")
        chr := parseChar()
        assertChar('\'')
        reader read() // skip ending single quote
        CharLiteral new(chr)
    }

    parseStringLiteral: func -> StringLiteral {
        buf := Buffer new()
        reader read() // skip opening double quote
        while(true) {
            assertHasMore("Unterminated string literal met end of file.")
            if(reader peek() == '"')
                break
            buf append(parseChar())
        }
        reader read() // skip ending double quote
        StringLiteral new(buf toString())
    }

    parseChar: func -> Char {
        c := reader read()
        if(c == '\\') {
            assertHasMore("Backslash escape met end of file.")
            next := reader read()
            if(next digit?()) {
                // `next` is part of the octal number
                reader rewind(1)
                parseCharOctalEscape()
            } else {
                match next {
                    case 'a' => '\a'
                    case 'b' => '\b'
                    case 't' => '\t'
                    case 'n' => '\n'
                    case 'v' => '\v'
                    case 'f' => '\f'
                    case 'r' => '\r'
                    case 'e' => 0c33 as Char
                    case 'x' => parseCharHexEscape()
                    case => next
                }
            }
        } else {
            c
        }
    }

    parseCharHexEscape: func -> Char {
        reader read()
    }

    parseCharOctalEscape: func -> Char {
        reader read()
    }

    parseDefinition: func -> Definition {
        word := parseWord()
        skipWhitespace()
        
        assertChar(':')
        reader read()
        
        skipWhitespace()
        
        assertHasMore("Unexpected end of file, expected stack effect or word body.")
        stackEffect := parseStackEffect()
        skipWhitespace()

        body := Quotation new(parseUntil('.'))

        Definition new(word, stackEffect, body)
    }

    parseUntil: func (end: Char) -> ArrayList<Data> {
        datas := ArrayList<Data> new()
        while(true) {
            skipWhitespace()
            assertHasMore("Unexpected end of file, expected '%c'." format(end))
            if(reader peek() == end) {
                reader read()
                break
            }
            datas add(parseData())
        }
        return datas
    }

    parseStackEffect: func -> StackEffect {
        stackEffect := StackEffect new()
        
        // The stack effect, if omitted in the source code, is
        // assumed to be (--), ie. a word that takes no inputs and
        // leaves no outputs.
        if(reader peek() != '(') {
            return stackEffect
        }
        reader read()

        gotDivider? := false

        while(true) {
            skipWhitespace()
            assertHasMore("Stack effect met end of file, expected ')'.")
            
            c := reader peek()
            if(wordChar?(c)) {
                word := parseWord()
                if(word == "--") {
                    gotDivider? = true
                } else if(!gotDivider?) {
                    stackEffect inputs add(word)
                } else {
                    stackEffect outputs add(word)
                }
            } else if(c == ')') {
                reader read()
                break
            } else {
                ParsingError new("Unexpected character: '%c', expected a word or ')'." format(c)) throw()
            }
        }
        if(!gotDivider?) {
            ParsingError new("Stack effect had no divider '--'.") throw()
        }
        return stackEffect
    }
    
    parseWord: func -> String {
        word := Buffer new()
        while(reader hasNext?()) {
            if(wordChar?(reader peek())) {
                word append(reader read())
            } else {
                break
            }
        }
        word toString()
    }

    assertChar: func (expected: Char) {
        assertHasMore("Unexpected end of file, expected: '%c'." format(expected))
        c := reader peek()
        if(c != expected) {
            ParsingError new("Unexpected character: '%c', expected '%c'." format(c, expected)) throw()
        }
    }

    assertHasMore: func (msg: String) {
        if(!reader hasNext?()) {
            ParsingError new(msg) throw()
        }
    }

    wordChar?: func (c: Char) -> Bool {
        c alphaNumeric?() || "`~!@$%^&*-_=+|;,/?" contains?(c)
    }

    skipWhitespace: func {
        while(reader hasNext?()) {
            c := reader peek()
            if(c == '#') {
                // # comments extend to the end of the line.
                reader skipUntil('\n')
            } else if(!c whitespace?()) {
                return
            } else {
                reader read()
            }
        }
    }
}

ParsingError: class extends Exception {
    init: super func ~originMsg
    init: super func ~noOrigin
}
