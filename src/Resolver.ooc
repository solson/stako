import structs/[ArrayList, HashMap]
import ast/[Node, Vocab, Definition, Word, Quotation, Wrapper]

Resolver: class {
    vocab: Vocab

    init: func (=vocab) {}

    resolve: func {        
        for(def in vocab definitions) {
            resolveOne(def body)
        }
    }

    resolveOne: func (data: Data) {
        match(data class) {
            case Word =>
                word := data as Word
                if(!vocab definitions contains?(word name))
                    Exception new(This, "Encountered undefined word: '%s'." format(word name)) throw()
                word definition = vocab definitions[word name]
            case Wrapper =>
                wrapper := data as Wrapper
                resolveOne(wrapper data)
            case Quotation =>
                for(data_ in data as Quotation body) {
                    resolveOne(data_)
                }
        }
    }
}