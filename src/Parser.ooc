import io/[File, FileReader, Reader], text/Buffer, structs/ArrayList
import ast/[Node, Module, Definition, Word, StackEffect, Quotation]

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
            return Word new(parseWord())
        } else if(c == '[') {
            reader read()
            return Quotation new(parseUntil(']'))
        } else {
            ParsingError new("Unexpected character: '%c', expected a word or quotation." format(c)) throw()
            return null
        }
    }

    parseDefinition: func -> Definition {
        word := parseWord()
        skipWhitespace()
        
        assertHasMore("Unexpected end of file, expected ':'.")
        
        assertChar(reader read(), ':')
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

    assertChar: func (c, expected: Char) {
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
            // # comments extend to the end of the line.
            if(c == '#') {
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
