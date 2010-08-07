import structs/ArrayList, text/StringReader, io/File
import ast/Module, Parser, Interpreter

main: func (args: ArrayList<String>) {
    if(args size() != 2) {
        "stako takes exactly one argument." println()
        return 1
    }

    fileName := args[1]
    module := Module new(fileName)

    source := File new(fileName) read()
    reader := StringReader new(source)
    Parser new(module, reader) parse()

    module toString() println()

    interpreter := Interpreter new()
    interpreter run(module)
}
