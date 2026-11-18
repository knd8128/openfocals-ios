import Foundation

/// A protobuf field read without a schema.
public struct ProtoField: Sendable, Equatable {
    public let number: Int
    public let value: ProtoValue

    public init(number: Int, value: ProtoValue) {
        self.number = number
        self.value = value
    }
}

public enum ProtoValue: Sendable, Equatable {
    case varint(UInt64)
    case fixed64(UInt64)
    case bytes(Data)
    case fixed32(UInt32)
}

/// Reads protobuf wire format with no `.proto` file.
///
/// The glasses' schema is large and only partly known, so the link decodes structurally and
/// names fields from `FocalsProtocol`'s tables. Nothing here needs regenerating when a new
/// message turns up; an unknown field still reads as a number and a value.
public enum ProtobufReader {

    public enum Error: Swift.Error, Equatable {
        case truncated
        case unsupportedWireType(Int)
        case invalidFieldNumber(Int)
    }

    public static func scan(_ data: Data) throws -> [ProtoField] {
        var fields: [ProtoField] = []
        var cursor = data.startIndex
        while cursor < data.endIndex {
            let (key, keyBytes) = try decodeVarint(data, at: &cursor, consumed: nil)
            _ = keyBytes
            let number = Int(key >> 3)
            let wireType = Int(key & 0x07)
            guard number > 0 else { throw Error.invalidFieldNumber(number) }

            switch wireType {
            case 0:
                let (value, _) = try decodeVarint(data, at: &cursor, consumed: nil)
                fields.append(ProtoField(number: number, value: .varint(value)))
            case 1:
                let value = try readFixed(data, at: &cursor, width: 8)
                fields.append(ProtoField(number: number, value: .fixed64(value)))
            case 2:
                let (length, _) = try decodeVarint(data, at: &cursor, consumed: nil)
                guard let end = data.index(cursor, offsetBy: Int(length), limitedBy: data.endIndex) else {
                    throw Error.truncated
                }
                fields.append(ProtoField(number: number, value: .bytes(Data(data[cursor..<end]))))
                cursor = end
            case 5:
                let value = try readFixed(data, at: &cursor, width: 4)
                fields.append(ProtoField(number: number, value: .fixed32(UInt32(truncatingIfNeeded: value))))
            default:
                // Groups (3, 4) were removed from proto2 long before this protocol existed.
                throw Error.unsupportedWireType(wireType)
            }
        }
        return fields
    }

    private static func decodeVarint(
        _ data: Data, at cursor: inout Data.Index, consumed: Int?
    ) throws -> (UInt64, Int) {
        do {
            let (value, count) = try Varint.decode(data, from: cursor)
            cursor = data.index(cursor, offsetBy: count)
            return (value, count)
        } catch Varint.Error.truncated {
            throw Error.truncated
        }
    }

    private static func readFixed(_ data: Data, at cursor: inout Data.Index, width: Int) throws -> UInt64 {
        guard let end = data.index(cursor, offsetBy: width, limitedBy: data.endIndex) else {
            throw Error.truncated
        }
        var value: UInt64 = 0
        for (offset, byte) in data[cursor..<end].enumerated() {
            value |= UInt64(byte) << (8 * offset)
        }
        cursor = end
        return value
    }
}

/// Builds protobuf messages field by field. Enough for the handshake and the small
/// control messages; nothing here needs a generated type.
public struct ProtobufWriter: Sendable {
    public private(set) var data = Data()

    public init() {}

    public mutating func varint(field: Int, _ value: UInt64) {
        appendKey(field: field, wireType: 0)
        data.append(contentsOf: Varint.encode(value))
    }

    public mutating func varint(field: Int, _ value: Int) {
        varint(field: field, UInt64(value))
    }

    public mutating func bool(field: Int, _ value: Bool) {
        varint(field: field, value ? 1 : 0)
    }

    public mutating func bytes(field: Int, _ value: Data) {
        appendKey(field: field, wireType: 2)
        data.append(contentsOf: Varint.encode(UInt64(value.count)))
        data.append(value)
    }

    public mutating func string(field: Int, _ value: String) {
        bytes(field: field, Data(value.utf8))
    }

    /// Nests a submessage, which is how every message in this protocol is carried.
    public mutating func message(field: Int, _ build: (inout ProtobufWriter) -> Void) {
        var inner = ProtobufWriter()
        build(&inner)
        bytes(field: field, inner.data)
    }

    private mutating func appendKey(field: Int, wireType: UInt64) {
        data.append(contentsOf: Varint.encode(UInt64(field) << 3 | wireType))
    }
}
