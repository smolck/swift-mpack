import XCTest
@testable import Mpack

final class MpackTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Mpack().text, "Hello, World!")

        let msgpack: [UInt8] = [168, 116, 101, 115, 116, 105, 110, 103, 45]
        print(Value.from(bytes: msgpack))

        let msgpackv2: [UInt8] = [221, 0, 0, 0, 4, 164, 106, 117, 115, 116, 4,
        167, 116, 101, 115, 116, 105, 110, 103, 203,
        64, 23, 51, 51, 51, 51, 51, 51]
        print(Value.from(bytes: msgpackv2))
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
