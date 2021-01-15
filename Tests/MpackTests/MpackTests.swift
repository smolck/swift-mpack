import XCTest

@testable import Mpack

final class MpackTests: XCTestCase {
  func testSerializesSimpleTypes() {
    let int8 = Value.integer(5)
    let int16 = Value.integer(128)  // 127 == Int8.max
    let int32 = Value.integer(32768)  // 32767 == Int16.max
    let int64 = Value.integer(2_147_483_648)  // 2147483647 == Int32.max

    // 9223372036854775807 == Int64.max
    let massive = Value.integer(9_223_372_036_854_775_807)

    XCTAssert(int8.toBytes() == [5])
    XCTAssert(int16.toBytes() == [204, 128])
    XCTAssert(int32.toBytes() == [205, 128, 0])
    XCTAssert(int64.toBytes() == [206, 128, 0, 0, 0])
    XCTAssert(massive.toBytes() == [207, 127, 255, 255, 255, 255, 255, 255, 255])

    let float32 = Value.float32(15.5)
    let float64 = Value.float64(12345678.987654321)

    print(float32.toBytes())
    XCTAssert(float32.toBytes() == [203, 64, 47, 0, 0, 0, 0, 0, 0])
    XCTAssert(float64.toBytes() == [203, 65, 103, 140, 41, 223, 154, 221, 60])

    let boolTrue = Value.boolean(true)
    let boolFalse = Value.boolean(false)

    XCTAssert(boolTrue.toBytes() == [195])
    XCTAssert(boolFalse.toBytes() == [194])

    let str = Value.string("Just a string")

    XCTAssert(str.toBytes() == [173, 74, 117, 115, 116, 32, 97, 32, 115, 116, 114, 105, 110, 103])
  }

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
        (Value.integer(5), Value.string("that's a number, yup")),
      ]),
      Value.boolean(true),
      Value.boolean(false),
      Value.array([
        Value.integer(1),
        Value.integer(2),
        Value.integer(3),
      ]),
    ])
    print(values.toBytes())
  }

  static var allTests = [
    ("testSerializesSimpleTypes", testSerializesSimpleTypes),
    // ("testExample", testExample),
  ]
}
