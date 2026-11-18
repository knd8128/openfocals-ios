import Foundation

/// Base-128 varints (LEB128), the length prefix used by both the frame layer and protobuf.
public enum Varint {

    public enum Error: Swift.Error, Equatable {
        /// The buffer ended in the middle of a varint. More bytes may complete it.
        case truncated
        /// More than ten continuation bytes, or a value wider than the requested type.
        case overflow
    }

    /// The largest number of bytes a 64-bit varint can occupy.
    public static let maxByteCount = 10

    public static func encode(_ value: UInt64) -> [UInt8] {
        var remaining = value
        var out: [UInt8] = []
        repeat {
            var byte = UInt8(remaining & 0x7F)
            remaining >>= 7
            if remaining != 0 { byte |= 0x80 }
            out.append(byte)
        } while remaining != 0
        return out
    }

    public static func encode(_ value: Int) -> [UInt8] {
        precondition(value >= 0, "varints are unsigned")
        return encode(UInt64(value))
    }

    /// Reads one varint starting at `index`, returning the value and how many bytes it used.
    public static func decode<C: Collection>(
        _ bytes: C, from index: C.Index
    ) throws -> (value: UInt64, byteCount: Int) where C.Element == UInt8 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        var count = 0
        var cursor = index
        while cursor < bytes.endIndex {
            let byte = bytes[cursor]
            count += 1
            if shift > 63 { throw Error.overflow }
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { return (result, count) }
            shift += 7
            if count >= maxByteCount { throw Error.overflow }
            cursor = bytes.index(after: cursor)
        }
        throw Error.truncated
    }

    /// Same, constrained to 32 bits — the width the glasses use for every length prefix.
    public static func decode32<C: Collection>(
        _ bytes: C, from index: C.Index
    ) throws -> (value: UInt32, byteCount: Int) where C.Element == UInt8 {
        let (value, count) = try decode(bytes, from: index)
        guard value <= UInt64(UInt32.max) else { throw Error.overflow }
        return (UInt32(value), count)
    }
}
