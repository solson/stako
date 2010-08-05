import structs/ArrayList, text/StringReader, io/File
import Parser, ast/Module

main: func (args: ArrayList<String>) {
    if(args size() != 2) {
        "stako takes exactly one argument." println()
        return 1
    }

    fileName := args[1]
    fileName println()
    
    module := Module new(fileName)

    source := File new(fileName) read()
    reader := StringReader new(source)
    Parser new(module, reader) parse()

    module toString() println()
}
