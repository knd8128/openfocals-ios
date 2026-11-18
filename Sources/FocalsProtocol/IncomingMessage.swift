import Foundation
import FocalsWire

/// One decoded message from the glasses: which field it arrived in, its body, and any
/// bulk payload that rode along in the same frame.
public struct IncomingMessage: Sendable {
    public let fieldNumber: Int
    public let kind: ToCompanion?
    public let body: Data
    public let payload: Data

    public var name: String {
        kind.map { String(describing: $0) } ?? "unknown(\(fieldNumber))"
    }

    public init(fieldNumber: Int, body: Data, payload: Data) {
        self.fieldNumber = fieldNumber
        self.kind = ToCompanion(rawValue: fieldNumber)
        self.body = body
        self.payload = payload
    }

    /// Splits a frame body into the messages it carries. The union holds one field in
    /// practice, but the wire format permits more and this does not assume otherwise.
    public static func decode(frameBody: Data) throws -> [IncomingMessage] {
        let wire = try WireMessage(decoding: frameBody)
        return try ProtobufReader.scan(wire.message).compactMap { field in
            guard case .bytes(let body) = field.value else { return nil }
            return IncomingMessage(fieldNumber: field.number, body: body, payload: wire.payload)
        }
    }

    /// A one-line structural summary, for logs when no typed reader exists yet.
    public func describeFields() -> String {
        guard let fields = try? ProtobufReader.scan(body) else { return "<unparsable>" }
        let parts = fields.map { field -> String in
            switch field.value {
            case .varint(let v): return "\(field.number)=\(v)"
            case .fixed32(let v): return "\(field.number)=0x\(String(v, radix: 16))"
            case .fixed64(let v): return "\(field.number)=0x\(String(v, radix: 16))"
            case .bytes(let d):
                if let text = Self.printableString(d) { return "\(field.number)=\"\(text)\"" }
                return "\(field.number)=<\(d.count)B>"
            }
        }
        return parts.joined(separator: " ")
    }

    private static func printableString(_ data: Data) -> String? {
        guard !data.isEmpty, data.count <= 120 else { return nil }
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        return text.allSatisfy { !$0.isNewline && ($0.isLetter || $0.isNumber || $0.isPunctuation || $0 == " " || $0.isSymbol) } ? text : nil
    }
}
