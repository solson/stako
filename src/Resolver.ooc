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
        match(data) {
            case word: Word =>
                if(!vocab definitions contains?(word name))
                    Exception new(This, "Encountered undefined word: '%s'." format(word name toCString())) throw()
                word definition = vocab definitions[word name]
            case wrapper: Wrapper =>
                resolveOne(wrapper data)
            case quot: Quotation =>
                for(data_ in quot body) {
                    resolveOne(data_)
                }
        }
    }
}