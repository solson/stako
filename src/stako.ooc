import structs/ArrayList, text/StringReader, io/File
import ast/Module, Parser, Interpreter, Compiler

main: func (args: ArrayList<String>) {
    if(args size() != 2) {
        "stako takes exactly one argument." println()
        return 1
    }

    fileName := args[1]
    module := Module new(fileName)

    Parser new(module, fileName, File new(fileName) read()) parse()

//    Interpreter new() run(module)
//    compiler := Compiler new(module)
    compiler := Compiler new()
    compiler compile()
}
