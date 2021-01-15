import Foundation

// See https://github.com/smolck/uivonim/blob/a622bc0b1e8b3582f9bb364b3eccc8ff4f31463a/src/messaging/msgpack-encoder.ts#L6-L13
fileprivate let int8Max =
  NSDecimalNumber(decimal: pow(2, 8) - 1).intValue
fileprivate let int16Max =
  NSDecimalNumber(decimal: pow(2, 16) - 1).intValue
fileprivate let int32Max =
  NSDecimalNumber(decimal: pow(2, 32) - 1).intValue
fileprivate let negativeFixintMin =
  NSDecimalNumber(decimal: pow(2, 5) * -1).intValue
fileprivate let u8Max =
  NSDecimalNumber(decimal: pow(2, 8 - 1) - 1).intValue
fileprivate let u8Min =
  NSDecimalNumber(decimal: -1 * pow(2, 8 - 1)).intValue
fileprivate let u16Min =
  NSDecimalNumber(decimal: -1 * pow(2, 16 - 1)).intValue
fileprivate let u32Min =
  NSDecimalNumber(decimal: -1 * pow(2, 16 - 1)).intValue

enum Value {
  case null
  case boolean(Bool)
  case integer(Int)
  case float32(Float)
  case float64(Double)
  case string(String)
  case array([Value])
  case map([(Value, Value)])

  // TODO(smolck)
  // case binary([UInt8])
  // case ext(Int, [UInt8])

  private static func deserializeNum16(_ bytes: [UInt8]) -> Value {
    return Value.integer(Int(bytes[0] << 8 | bytes[1]))
  }

  private static func deserializeNum32(_ bytes: [UInt8]) -> Value {
    return Value.integer(Int(bytes[0] << 24 | bytes[1] << 16 | bytes[2] << 8 | bytes[3]))
  }

  private static func deserializeNum64(_ bytes: [UInt8]) -> Value {
    // Get error about compiler type checking taking too much time w/out this
    // intermediate value.
    let x =
      bytes[0] << 56 | bytes[1] << 48 | bytes[2] << 40 | bytes[3] << 32 | bytes[4] << 24
      | bytes[5] << 16 | bytes[6] << 8 | bytes[7]

    return Value.integer(Int(x))
  }

  private static func deserializeMap(len: Int, bytes: [UInt8]) -> Value {
    var arr = Array(repeating: (Value.null, Value.null), count: len)
    var currBytes = bytes

    for i in 0..<len * 2 {
      let x = privFrom(bytes: currBytes)

      if i % 2 == 0 {
        arr[i].0 = x.0
      } else {
        arr[i - 1].1 = x.0
      }

      currBytes = x.1
    }
    assert(currBytes == [])

    return Value.map(arr)
  }

  private static func privFrom(bytes: [UInt8]) -> (Value, [UInt8]) {
    let startingByte = bytes[0]

    if (startingByte & 0xE0) == 0xA0 {
      // fixstr
      let len = Int(startingByte & 0x1F)
      let stringBytes = bytes[1..<len + 1]
      if let x = String(bytes: stringBytes, encoding: .utf8) {
        return (Value.string(x), [UInt8](bytes[(len + 1)...]))
      }
      return (Value.null, [])

    } else if (startingByte & 0xF0) == 0x90 {
      // fixarray
      let len = Int(startingByte & 0xF)

      var arr = Array(repeating: Value.null, count: len)
      var currBytes = [UInt8](bytes[1...])
      for i in 0..<len {
        let x = privFrom(bytes: currBytes)
        arr[i] = x.0
        currBytes = x.1
      }

      // TODO(smolck): I *think* this should always be true.
      assert(currBytes == [])

      return (Value.array(arr), [])
    } else if startingByte >= 0x80
      && startingByte <= 0x8f  // TODO(smolck): Verify these are correct conditions
    {
      // fixmap

      // TODO(smolck): Make sure this is right.
      let len = Int(startingByte - 0x80)

      return (deserializeMap(len: len, bytes: [UInt8](bytes[1...])), [])
    } else if (startingByte & 0xE0) == 0xE0 {
      // Negative fixnum
      return (Value.integer(Int(startingByte) - 256), [UInt8](bytes[1...]))
    } else if startingByte <= Int8.max {
      // Positive fixnum
      return (Value.integer(Int(startingByte)), [UInt8](bytes[1...]))
    }

    switch startingByte {
    case 0xc2:  // false
      return (Value.boolean(false), [UInt8](bytes[1...]))
    case 0xc3:  // true
      return (Value.boolean(true), [UInt8](bytes[1...]))
    case 0xcc, 0xd0:  // UInt8, Int8
      return (Value.integer(Int(bytes[1])), [UInt8](bytes[2...]))
    case 0xcd, 0xd1:  // UInt16, Int16
      return (deserializeNum16([UInt8](bytes[1..<3])), [UInt8](bytes[4...]))
    case 0xce, 0xd2:  // UInt32, Int32
      return (deserializeNum32([UInt8](bytes[1..<5])), [UInt8](bytes[5...]))
    case 0xcf, 0xd3:  // UInt64, Int64
      return (deserializeNum64([UInt8](bytes[1..<9])), [UInt8](bytes[9...]))
    case 0xca:  // Float32
      // https://stackoverflow.com/a/41163620
      let float = Float(
        bitPattern: UInt32(
          bigEndian: Data(bytes[1..<5]).withUnsafeBytes { $0.load(as: UInt32.self) }))
      return (Value.float32(float), [UInt8](bytes[5...]))
    case 0xcb:  // Float64
      // See above
      let double = Double(
        bitPattern: UInt64(
          bigEndian: Data(bytes[1..<9]).withUnsafeBytes { $0.load(as: UInt64.self) }))
      return (Value.float64(double), [UInt8](bytes[9...]))
    case 0xdc:  // Array16
      if case .integer(let len) = deserializeNum16([UInt8](bytes[1..<3])) {
        var arr = Array(repeating: Value.null, count: len)
        var currBytes = [UInt8](bytes[3...])
        for i in 0..<len {
          let x = privFrom(bytes: currBytes)
          arr[i] = x.0
          currBytes = x.1
        }

        // TODO(smolck): I *think* this is always true . . .
        assert(currBytes == [])

        return (Value.array(arr), [])
      }

      // TODO(smolck): Should never get here I don't think.
      assert(false)
    case 0xdd:  // Array32
      if case .integer(let len) = deserializeNum32([UInt8](bytes[1..<5])) {
        var arr = Array(repeating: Value.null, count: len)
        var currBytes = [UInt8](bytes[5...])
        for i in 0..<len {
          let x = privFrom(bytes: currBytes)

          arr[i] = x.0
          currBytes = x.1
        }

        // TODO(smolck): I *think* this is always true . . .
        assert(currBytes == [])

        return (Value.array(arr), [])
      }

      // TODO(smolck): Should never get here I don't think.
      assert(false)
    case 0xde:  // Map16
      if case .integer(let len) = deserializeNum16([UInt8](bytes[1..<3])) {
        return (deserializeMap(len: len, bytes: [UInt8](bytes[3...])), [])
      }
    case 0xdf:  // Map32
      if case .integer(let len) = deserializeNum32([UInt8](bytes[1..<5])) {
        return (deserializeMap(len: len, bytes: [UInt8](bytes[5...])), [])
      }

      // TODO(smolck): Should never get here I don't think.
      assert(false)
    default:
      NSLog("Deserialization for type not implemented: \(startingByte), \(bytes)")
      return (Value.null, [])
    }

    return (Value.null, [])
  }

  static func from(bytes: [UInt8]) -> Value {
    return privFrom(bytes: bytes).0
  }

  func toBytes() -> [UInt8] {
    var bytes = [UInt8]()

    switch self {
    case .null:
      bytes.append(0xc0)
      return bytes
    case .boolean(let x):
      if x {
        bytes.append(0xc3)
      } else {
        bytes.append(0xc2)
      }

      return bytes
    case .integer(let x):
      let pos = x.signum() > 0

      // See
      // https://github.com/smolck/uivonim/blob/a622bc0b1e8b3582f9bb364b3eccc8ff4f31463a/src/messaging/msgpack-encoder.ts#L43

      // fixint
      if pos && x <= u8Max {
        bytes.append(UInt8(x & 0xFF))
      }

      // uint8
      else if pos && x <= int8Max {
        bytes.append(0xcc)
        bytes.append(UInt8(x))
      }

      // uint16
      else if pos && x <= int16Max {
        bytes.append(0xcd)
        bytes.append(contentsOf: withUnsafeBytes(of: x, Array.init)[0..<2].reversed())
      }

      // uint32
      else if pos && x <= int32Max {
        bytes.append(0xce)
        bytes.append(contentsOf: withUnsafeBytes(of: x, Array.init)[0..<4].reversed())
      }

      // uint64
      else if pos {
        bytes.append(0xcf)
        bytes.append(contentsOf: withUnsafeBytes(of: x, Array.init).reversed())
      }

      // (negative) int8
      else if !pos && x >= u8Min {
        bytes.append(0xd0)

        // TODO(smolck): Check this
        bytes.append(UInt8(x & 0xFF))
      }

      // (negative) int16
      else if !pos && x >= u16Min {
        bytes.append(0xd1)
        bytes.append(contentsOf: withUnsafeBytes(of: x, Array.init)[0..<2].reversed())
      }

      // (negative) int32
      else if !pos && x >= u32Min {
        bytes.append(0xd2)
        bytes.append(contentsOf: withUnsafeBytes(of: x, Array.init)[0..<4].reversed())
      }

      // (negative) int64
      else if !pos {
        bytes.append(0xd2)
        bytes.append(contentsOf: withUnsafeBytes(of: x, Array.init).reversed())
      }

      return bytes
    // TODO(smolck): For some reason it seems like msgpack libraries always
    // serialize float32s as float64s? Even with the `Try!` serializer at
    // msgpack.org it never seems to create a float32 (which start with 0xca
    // according to the spec) . . .  so just do the same, for now at least.
    //
    // For future ref for float32 serialization:
    // bytes.append(0xca)
    // bytes.append(contentsOf: withUnsafeBytes(of: x, Array.init)[0..<4].reversed())
    // return bytes
    case .float32(let x):
      bytes.append(0xcb)
      bytes.append(contentsOf: withUnsafeBytes(of: Double(x), Array.init).reversed())
      return bytes
    case .float64(let x):
      bytes.append(0xcb)
      bytes.append(contentsOf: withUnsafeBytes(of: x, Array.init).reversed())
      return bytes
    case .string(let str):
      if str.count < 31 {
        // fixstr
        bytes.append(UInt8(0xa0 | str.count))
      } else if str.count <= UInt8.max {
        // str8
        bytes.append(0xd9)
        bytes.append(UInt8(str.count))
      } else if str.count <= UInt16.max {
        // str16
        bytes.append(0xda)
        bytes.append(UInt8((str.count >> 8) & 0xFF))
        bytes.append(UInt8(str.count & 0xFF))
      } else {
        // str32
        bytes.append(0xdb)
        bytes.append(contentsOf: withUnsafeBytes(of: str.count, Array.init).reversed()[0..<4])
      }

      bytes.append(contentsOf: Array(str.utf8))
      return bytes
    case .array(let arr):
      if arr.count <= 15 {
        // fixarray
        bytes.append(UInt8(0x90 | arr.count))
      } else if arr.count <= UInt16.max {
        // array16
        bytes.append(0xdc)
        bytes.append(UInt8((arr.count >> 8) & 0xFF))
        bytes.append(UInt8(arr.count & 0xFF))
      } else {
        // array32
        bytes.append(0xdd)
        bytes.append(contentsOf: withUnsafeBytes(of: arr.count, Array.init).reversed()[0..<4])
      }

      bytes.append(contentsOf: arr.flatMap { $0.toBytes() })
      return bytes
    case .map(let map):
      if map.count <= 15 {
        // fixmap
        bytes.append(UInt8(0x80 | map.count))
      } else if map.count <= UInt16.max {
        // map16
        bytes.append(0xde)
        bytes.append(UInt8((map.count >> 8) & 0xFF))
        bytes.append(UInt8(map.count & 0xFF))
      } else {
        // map32
        bytes.append(0xdf)
        bytes.append(contentsOf: withUnsafeBytes(of: map.count, Array.init).reversed()[0..<4])
      }

      for (key, val) in map {
        bytes.append(contentsOf: key.toBytes())
        bytes.append(contentsOf: val.toBytes())
      }
      return bytes
    }
  }
}
