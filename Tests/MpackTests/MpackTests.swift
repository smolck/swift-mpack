import XCTest
@testable import Mpack

final class MpackTests: XCTestCase {
    func testExample() {
        /* let msgpack: [UInt8] = [168, 116, 101, 115, 116, 105, 110, 103, 45]
        print(Value.from(bytes: msgpack))

        let msgpackv2: [UInt8] = [221, 0, 0, 0, 4, 164, 106, 117, 115, 116, 4,
        167, 116, 101, 115, 116, 105, 110, 103, 203,
        64, 23, 51, 51, 51, 51, 51, 51]
        print(Value.from(bytes: msgpackv2)) */

        // let msgpack: [UInt8] = [223, 0, 0, 0, 1, 165, 104, 101, 108, 108, 111, 165, 116, 104, 101, 114, 101]
        // print(Value.from(bytes: msgpack))

        let values: Value = Value.array([
          Value.map([
            (Value.string("Hello"), Value.string("world!")),
            (Value.integer(5), Value.string("that's a number, yup"))
          ]),
          Value.boolean(true),
          Value.boolean(false),
          Value.array([
            Value.integer(1),
            Value.integer(2),
            Value.integer(3)
          ])
        ])
        print(values.toBytes())
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
