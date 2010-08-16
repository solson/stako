import structs/ArrayList, text/StringReader, io/File
import ast/Vocab, Parser, Interpreter, Compiler

main: func (args: ArrayList<String>) {
    if(args size() != 2) {
        "stako takes exactly one argument." println()
        return 1
    }

    fileName := args[1]
    vocab := Vocab new(fileName)

    Parser new(vocab, fileName, File new(fileName) read()) parse()

//    vocab toString() println()

//    Interpreter new() run(module)
//    compiler := Compiler new(module)
    compiler := Compiler new()
    compiler compile()
}
