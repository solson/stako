import structs/[ArrayList, HashMap]
import ast/[Node, Module, Definition, Word, Quotation]

Resolver: class {
    module: Module

    init: func (=module) {}

    resolve: func {
        for(def in module definitions) {
            module vocab[def name] = def
        }
        
        for(def in module definitions) {
            resolveOne(def body)
        }
    }

    resolveOne: func (data: Data) {
        match(data class) {
            case Word =>
                word := data as Word
                if(!module vocab contains?(word name))
                    Exception new(This, "Encountered undefined word: '%s'." format(word name)) throw()
                word definition = module vocab[word name]
            case Quotation =>
                for(data_ in data as Quotation body) {
                    resolveOne(data_)
                }
        }
    }
}