import Node

Wrapper: class extends Data {
    data: Data

    init: func (=data) {}

    toString: func -> String {
        '\\' + data toString()
    }
}
