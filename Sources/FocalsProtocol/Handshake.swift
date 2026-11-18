import Foundation
import FocalsWire

/// The protocol version this companion claims. The glasses refuse anything older than
/// their own minimum; 4.40 is what firmware 1.119 requires and what the official
/// companion sent.
public enum ProtocolVersion {
    public static let major: UInt32 = 4
    public static let minor: UInt32 = 40
}

/// First message of every session, sent by the companion.
public struct Handshake: Sendable, Equatable {
    public var major: UInt32
    public var minor: UInt32

    public init(major: UInt32 = ProtocolVersion.major, minor: UInt32 = ProtocolVersion.minor) {
        self.major = major
        self.minor = minor
    }

    /// Encoded as `ToGlasses.handshake`, ready to frame and write.
    public func encoded() -> WireMessage {
        var writer = ProtobufWriter()
        writer.message(field: ToGlasses.handshake.rawValue) { inner in
            inner.varint(field: 1, UInt64(major))
            inner.varint(field: 2, UInt64(minor))
        }
        return WireMessage(message: writer.data)
    }
}

/// The glasses' reply. A `result` other than `.success` means the session will not proceed.
public struct HandshakeResponse: Sendable, Equatable {

    public enum Result: UInt64, Sendable {
        case success = 0
        case glassesUpdateRequired = 1
        case companionUpdateRequired = 2
    }

    public enum Error: Swift.Error, Equatable {
        case notAHandshakeResponse
        case missingField(Int)
    }

    public var result: Result?
    public var rawResult: UInt64
    public var softwareVersion: String
    public var major: UInt32
    public var minor: UInt32
    public var requiredMajor: UInt32
    public var requiredMinor: UInt32

    /// Reads the response out of an already-decoded `ToCompanion.handshakeResponse` body.
    public init(decoding body: Data) throws {
        var rawResult: UInt64?
        var software: String?
        var major: UInt32?, minor: UInt32?, reqMajor: UInt32?, reqMinor: UInt32?

        for field in try ProtobufReader.scan(body) {
            switch (field.number, field.value) {
            case (1, .varint(let v)): rawResult = v
            case (2, .bytes(let d)): software = String(decoding: d, as: UTF8.self)
            case (3, .varint(let v)): major = UInt32(truncatingIfNeeded: v)
            case (4, .varint(let v)): minor = UInt32(truncatingIfNeeded: v)
            case (5, .varint(let v)): reqMajor = UInt32(truncatingIfNeeded: v)
            case (6, .varint(let v)): reqMinor = UInt32(truncatingIfNeeded: v)
            default: break
            }
        }

        guard let rawResult else { throw Error.missingField(1) }
        self.rawResult = rawResult
        self.result = Result(rawValue: rawResult)
        self.softwareVersion = software ?? ""
        self.major = major ?? 0
        self.minor = minor ?? 0
        self.requiredMajor = reqMajor ?? 0
        self.requiredMinor = reqMinor ?? 0
    }

    /// True when this companion satisfies the minimum the glasses demand.
    public var companionIsNewEnough: Bool {
        (ProtocolVersion.major, ProtocolVersion.minor) >= (requiredMajor, requiredMinor)
    }
}
