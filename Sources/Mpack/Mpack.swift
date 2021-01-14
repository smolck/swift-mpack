import Foundation

struct Mpack {
  var text = "Hello, World!"
}

enum Value {
  case null
  case boolean(Bool)
  case integer(Int)
  case float32(Float)
  case float64(Double)
  case string(String)
  case binary([UInt8])
  case array([Value])
  case map([(Value, Value)])
  case ext(Int, [UInt8])

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

  private static func privFrom(bytes: [UInt8]) -> (Value, [UInt8]) {
    let startingByte = bytes[0]

    if (startingByte & 0xE0) == 0xA0 {
      // fixstr
      let len = Int(startingByte & 0x1F)
      let stringBytes = bytes[1..<len + 1]
      if let x = String(bytes: stringBytes, encoding: .utf8) {
        return (Value.string(x), [UInt8](bytes[(len+1)...]))
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
    } else if (startingByte & 0xE0) == 0xE0 {
      // Negative fixnum
      return (Value.integer(Int(startingByte) - 256), [UInt8](bytes[1...]))
    } else if startingByte <= Int8.max {
      // Positive fixnum
      return (Value.integer(Int(startingByte)), [UInt8](bytes[1...]))
    }

    switch startingByte {
    case 0xcc, 0xd0:  // UInt8, Int8
      return (Value.integer(Int(bytes[1])), [UInt8](bytes[2...]))
    case 0xcd, 0xd1:  // UInt16, Int16
      return (deserializeNum16([UInt8](bytes[1..<3])), [UInt8](bytes[4...]))
    case 0xce, 0xd2: // UInt32, Int32
      return (deserializeNum32([UInt8](bytes[1..<5])), [UInt8](bytes[5...]))
    case 0xcf, 0xd3: // UInt64, Int64
      return (deserializeNum64([UInt8](bytes[1..<9])), [UInt8](bytes[9...]))
    case 0xca: // Float32
      // https://stackoverflow.com/a/41163620
      let float = Float(bitPattern: UInt32(bigEndian: Data(bytes[1..<5]).withUnsafeBytes { $0.load(as: UInt32.self) }))
      return (Value.float32(float), [UInt8](bytes[5...]))
    case 0xcb: // Float64
      // See above
      let double = Double(bitPattern: UInt64(bigEndian: Data(bytes[1..<9]).withUnsafeBytes { $0.load(as: UInt64.self) }))
      return (Value.float64(double), [UInt8](bytes[9...]))
    case 0xdc: // Array16
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
    case 0xdd: // Array32
      if case .integer(let len) = deserializeNum32([UInt8](bytes[1..<5])) {
        var arr = Array(repeating: Value.null, count: len)
        var currBytes = [UInt8](bytes[5...])
        for i in 0..<len {
          print("start, \(currBytes)")
          let x = privFrom(bytes: currBytes)
          print("end")

          arr[i] = x.0
          currBytes = x.1
        }

        // TODO(smolck): I *think* this is always true . . .
        assert(currBytes == [])

        return (Value.array(arr), [])
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
}
