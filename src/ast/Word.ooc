import Node, Definition

Word: class extends Data {
    name: String
    definition: Definition = null
    
    init: func (=name, =definition) {}

    init: func ~withoutDefinition (=name) {}

    toString: func -> String {
        name
    }
}