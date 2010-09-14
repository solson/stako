import structs/ArrayList, io/[StringReader, File]
import ast/Vocab, Parser, Compiler

main: func (args: ArrayList<String>) {
    if(args size != 4) {
        "Usage: stako <input> <output> <core-lib>" println()
        return 1
    }

    fileName := args[1]
    outputFile := args[2]
    coreLib := args[3]
    
    if(!fileName endsWith?(".stako")) {
        ("Unrecognized file format, expected .stako: " + fileName) println()
        return 2
    }

    // Strip the .stako off the end.
    vocab := Vocab new(fileName[0..-7])

    Parser new(vocab, fileName, File new(fileName) read()) parse()

    compiler := Compiler new(vocab, outputFile, coreLib)
    compiler compile()
}
