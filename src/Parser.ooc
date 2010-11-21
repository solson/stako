import io/[File, FileReader, Reader, StringReader], structs/ArrayList
import ast/[Node, Vocab, Definition, Word, WordType, StackEffect, Quotation, NumberLiteral, CharLiteral, StringLiteral, Wrapper]

Parser: class {
    vocab: Vocab
    source: String
    reader: Reader

    fileName := "(no-file)"
    line     := 1
    column   := 0

    init: func (=vocab, =fileName) {
        source = File new(fileName) read()
        reader = StringReader new(source)
    }

    init: func ~withSource (=vocab, =fileName, =source) {
        reader = StringReader new(source)
    }

    parse: func {
        while(reader hasNext?()) {
            c := reader peek()
            if(c whitespace?() || c == '#') {
                skipWhitespace()
            } else if(wordChar?(c)) {
                definition := parseDefinition()
                vocab definitions put(definition name, definition)
            } else {
                error("Unexpected character: '%s', expected a word definition.", c)
            }
        }
    }

    parseDefinition: func -> Definition {
        word := parseWord()
        skipWhitespace()
        
        assertChar(':')
        skipWhitespace()
        
        assertHasMore("Unexpected end of file, expected type, stack effect or word body.")
        type := parseType()
        skipWhitespace()

        assertHasMore("Unexpected end of file, expected stack effect or word body.")
        stackEffect := parseStackEffect()
        skipWhitespace()

        body := Quotation new(parseUntil('.'))

        Definition new(word, type, stackEffect, body)
    }

    parseType: func -> WordType {
        type := WordType new()

        // The word type, if omitted in the source code, is
        // assumed to be <word>, a normal function word.
        if(reader peek() != '<') {
            type words add("word")
            return type
        }
        read()

        while(true) {
            skipWhitespace()
            assertHasMore("Word type met end of file, expected '>'.")
            
            c := reader peek()
            if(c == '>') {
                read()
                break
            } else if(wordChar?(c)) {
                word := Buffer new()
                while(reader hasNext?()) {
                    c := read()
                    if(wordChar?(c) && c != '>') {
                        word append(c)
                    } else {
                        rewind(1)
                        break
                    }
                }
                type words add(word toString())
            } else {
                error("Unexpected character: '%s', expected a word or '>'.", c)
            }
        }
        type
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
                error("Unexpected character: '%s', expected a word or ')'.", c)
            }
        }
        stackEffect
    }

    parseUntil: func (end: Char) -> ArrayList<Data> {
        datas := ArrayList<Data> new()
        while(true) {
            skipWhitespace()
            assertHasMore("Unexpected end of file, expected '%s'." format(escape(end)))
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
                error("Unexpected character: '%s', expected a word or literal.", c)
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
                match(c1) {
                    case 'x' => return parseNumberWithBase(16, |c| c hexDigit?())
                    case 'c' => return parseNumberWithBase(8,  |c| c octalDigit?())
                    case 'b' => return parseNumberWithBase(2,  |c| "01" contains?(c))
                }
            }
        }
        reset(mark_, lineMark, columnMark)
        parseNumberWithBase(10, |c| c digit?())
    }

    parseNumberWithBase: func (baseNumber: Int, pred: Func (Char) -> Bool) -> NumberLiteral {
        num := Buffer new()
        while(reader hasNext?()) {
            c := read()
            if(pred(c)) {
                num append(c)
            } else if(!wordChar?(c)) {
                rewind(1)
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
            c := read()
            if(wordChar?(c)) {
                word append(c)
            } else {
                rewind(1)
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
                rewind(1) // `next` is part of the octal number
                parseCharOctalEscape()
            } else match(next) {
                case 'a' => '\a'
                case 'b' => '\b'
                case 't' => '\t'
                case 'n' => '\n'
                case 'v' => '\v'
                case 'f' => '\f'
                case 'r' => '\r'
                case 'e' => 0c33 as Char
                case 'x' => parseCharHexEscape()
                case     => next
            }
        } else {
            c
        }
    }

    parseCharHexEscape: func -> Char {
        num := Buffer new(2)
        for(i in 0..2) {
            assertHasMore("Unexpected end of file in hexadecimal escape, expected hexadecimal digit.")
            c := read()
            if(!c hexDigit?())
                error("Invalid hexadecimal digit in escape: '%s'.", c)
            num[i] = c
        }
        num toString() toLong(16) as Char
    }

    parseCharOctalEscape: func -> Char {
        num := Buffer new(3)
        for(i in 0..3) {
            assertHasMore("Unexpected end of file in octal escape, expected octal digit.")
            c := read()
            if(!c octalDigit?())
                error("Invalid octal digit in escape: '%s'.", c)
            num[i] = c
        }
        x := num toString() toLong(8)
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
        column -= offset
    }

    mark: func -> (Long, Int, Int) {
        (reader mark(), line, column)
    }

    reset: func (mark: Long, =line, =column) {
        reader reset(mark)
    }

    assertChar: func (expected: Char) {
        expected_ := escape(expected)
        assertHasMore("Unexpected end of file, expected: '%s'." format(expected_))
        c := reader peek()
        if(c != expected)
            error("Unexpected character: '%s', expected '%s'." format(escape(c), expected_))
        read()
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
        
        error append(msg). append('\n').
              append(errLine). append('\n').
              append(" " times(column)). append('^')
        ParsingError new(fileName, line, column, error toString()) throw()
    }

    error: func ~withEscapedChar (msg: String, chr: Char) {
        error(msg format(escape(chr)))
    }

    escape: static func (chr: Char) -> String {
        CharLiteral escape(chr, '\'')
    }

    wordChar?: static func (c: Char) -> Bool {
        c alphaNumeric?() || "`~!@$%^&*-_=+|;,<>/?" contains?(c)
    }
}

ParsingError: class extends Exception {
    init: super func
    init: super func ~noOrigin

    init: func ~withPosition (fileName: String, line, column: Int, message: String) {
        this message = "%s:%i:%i %s" format(fileName, line, column, message)
    }
}
