import io/[File, FileReader, Reader], text/[Buffer, StringReader], structs/ArrayList
import ast/[Node, Module, Definition, Word, StackEffect, Quotation, NumberLiteral, CharLiteral, StringLiteral, Wrapper]

Parser: class {
    module: Module
    source: String
    reader: Reader

    fileName := "(no-file)"
    line     := 1
    column   := 0

    init: func (=module, =fileName) {
        source = File new(fileName) read()
        reader = StringReader new(source)
    }

    init: func ~withSource (=module, =fileName, =source) {
        reader = StringReader new(source)
    }

    parse: func {
        while(reader hasNext?()) {
            c := reader peek()
            if(c whitespace?() || c == '#') {
                skipWhitespace()
            } else if(wordChar?(c)) {
                module definitions add(parseDefinition())
            } else {
                error("Unexpected character: '%c', expected a word definition." format(c))
            }
        }
    }

    parseDefinition: func -> Definition {
        word := parseWord()
        skipWhitespace()
        
        assertChar(':')
        skipWhitespace()
        
        assertHasMore("Unexpected end of file, expected stack effect or word body.")
        stackEffect := parseStackEffect()
        skipWhitespace()

        body := Quotation new(parseUntil('.'))

        Definition new(word, stackEffect, body)
    }

    parseStackEffect: func -> StackEffect {
        stackEffect := StackEffect new()
        
        // The stack effect, if omitted in the source code, is
        // assumed to be (--), ie. a word that takes no inputs and
        // leaves no outputs.
        if(reader peek() != '(')
            return stackEffect
        read()

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
                if(!gotDivider?)
                    error("Stack effect had no divider ('--').")
                read()
                break
            } else {
                error("Unexpected character: '%c', expected a word or ')'." format(c))
            }
        }
        stackEffect
    }

    parseUntil: func (end: Char) -> ArrayList<Data> {
        datas := ArrayList<Data> new()
        while(true) {
            skipWhitespace()
            assertHasMore("Unexpected end of file, expected '%c'." format(end))
            if(reader peek() == end) {
                read()
                break
            }
            datas add(parseData())
        }
        datas
    }

    parseData: func -> Data {
        c := read()
        if(wordChar?(c)) {
            rewind(1)
            column -= 1
            (mark_, lineMark, columnMark) := mark()
            num := parseNumber()
            if(num != null) {
                num
            } else {
                reset(mark_, lineMark, columnMark)
                Word new(parseWord())
            }
        } else match(c) {
            case '\\' => parseWrapper()
            case '['  => Quotation new(parseUntil(']'))
            case '\'' => parseCharLiteral()
            case '"'  => parseStringLiteral()
            case =>
                error("Unexpected character: '%c', expected a word or literal." format(c))
                null
        }
    }

    parseNumber: func -> NumberLiteral {
        (mark_, lineMark, columnMark) := mark()
        c := reader peek()
        if(!c digit?())
            return null
        if(c == '0') {
            read()
            assertHasMore("Unexpected end of file in number or word literal.")
            c1 := read()
            if(!c1 digit?()) {
                return match(c1) {
                    case 'x' => parseNumberWithBase(16, |c| c hexDigit?())
                    case 'c' => parseNumberWithBase(8,  |c| c octalDigit?())
                    case 'b' => parseNumberWithBase(2,  |c| "01" contains?(c))
                    case => null
                }
            }
        }
        reset(mark_, lineMark, columnMark)
        parseNumberWithBase(10, |c| c digit?())
    }

    parseNumberWithBase: func (baseNumber: Int, pred: Func (Char) -> Bool) -> NumberLiteral {
        num := Buffer new()
        while(reader hasNext?()) {
            c := reader peek()
            if(pred(c)) {
                num append(read())
            } else if(!wordChar?(c)) {
                break
            } else {
                return null
            }
        }
        NumberLiteral new(num toString() toLLong(baseNumber))
    }
    
    parseWord: func -> String {
        word := Buffer new()
        while(reader hasNext?()) {
            if(wordChar?(reader peek())) {
                word append(read())
            } else {
                break
            }
        }
        word toString()
    }

    parseWrapper: func -> Wrapper {
        skipWhitespace()
        assertHasMore("Unexpected end of file after wrapper ('\\'), expected word.")
        Wrapper new(parseData())
    }

    parseCharLiteral: func -> CharLiteral {
        assertHasMore("Unterminated character literal met end of file.")
        if(reader peek() == '\'')
            error("Encountered empty character literal.")
        chr := parseChar()
        assertChar('\'')
        CharLiteral new(chr)
    }

    parseStringLiteral: func -> StringLiteral {
        buf := Buffer new()
        while(true) {
            assertHasMore("Unterminated string literal met end of file.")
            if(reader peek() == '"')
                break
            buf append(parseChar())
        }
        read() // skip ending double quote
        StringLiteral new(buf toString())
    }

    parseChar: func -> Char {
        c := read()
        if(c == '\\') {
            assertHasMore("Backslash escape in character or string met end of file.")
            next := read()
            if(next digit?()) {
                // `next` is part of the octal number
                rewind(1)
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
        num := String new(2)
        for(i in 0..2) {
            assertHasMore("Unexpected end of file in hexadecimal escape, expected hexadecimal digit.")
            c := read()
            if(!c hexDigit?())
                error("Invalid hexadecimal digit in escape: '%c'." format(c))
            num[i] = c
        }
        num toLong(16) as Char
    }

    parseCharOctalEscape: func -> Char {
        num := String new(3)
        for(i in 0..3) {
            assertHasMore("Unexpected end of file in octal escape, expected octal digit.")
            c := read()
            if(!c octalDigit?())
                error("Invalid octal digit in escape: '%c'." format(c))
            num[i] = c
        }
        x := num toLong(8)
        if(x > 0c377)
            error("Invalid number in octal escape: '%s'. Numbers larger than 0c377 cannot fit in a single character (byte)." format(num))
        x as Char
    }

    skipWhitespace: func {
        while(reader hasNext?()) {
            c := reader peek()
            if(c == '#') {
                // # comments extend to the end of the line.
                reader skipUntil('\n')
                line += 1
                column = 0
            } else if(!c whitespace?()) {
                return
            } else {
                read()
            }
        }
    }

    read: func -> Char {
        c := reader read()
        if(c == '\n') {
            line += 1
            column = 0
        } else {
            column += 1
        }
        return c
    }

    rewind: func (offset: Int) {
        reader rewind(offset)
        column -= 1
    }

    mark: func -> (Long, Int, Int) {
        return (reader mark(), line, column)
    }

    reset: func (mark: Long, =line, =column) {
        reader reset(mark)
    }

    assertChar: func (expected: Char) {
        assertHasMore("Unexpected end of file, expected: '%c'." format(expected))
        c := read()
        if(c != expected)
            error("Unexpected character: '%c', expected '%c'." format(c, expected))
    }

    assertHasMore: func (msg: String) {
        if(!reader hasNext?())
            error(msg)
    }

    error: func (msg: String) {
        error := Buffer new()
        
        sourceReader := StringReader new(source)
        (line - 1) times(|| sourceReader skipLine())
        errLine := sourceReader readLine()
        
        error append(msg). append('\n'). append(errLine). append('\n').
              append(" " * column). append("^")
        ParsingError new(fileName, line, column, error toString()) throw()
    }

    wordChar?: static func (c: Char) -> Bool {
        c alphaNumeric?() || "`~!@$%^&*-_=+|;,/?" contains?(c)
    }
}

ParsingError: class extends Exception {
    init: super func ~originMsg
    init: super func ~noOrigin

    init: func ~withPosition (fileName: String, line, column: Int, message: String) {
        this msg = "%s:%i:%i %s" format(fileName, line, column, message)
    }
}
