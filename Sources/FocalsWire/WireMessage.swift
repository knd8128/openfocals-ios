import Foundation

/// A frame body: a length-prefixed protobuf message, optionally followed by bulk bytes.
///
/// The second length prefix exists so that large payloads — socket data, file transfer
/// chunks, images — ride along after the protobuf instead of inside it.
public struct WireMessage: Sendable, Equatable {

    public enum Error: Swift.Error, Equatable {
        /// The declared protobuf length runs past the end of the frame.
        case truncatedBody
    }

    /// The encoded protobuf message.
    public var message: Data
    /// Bytes following the message in the same frame. Empty for most traffic.
    public var payload: Data

    public init(message: Data, payload: Data = Data()) {
        self.message = message
        self.payload = payload
    }

    public init(decoding body: Data) throws {
        let (length, prefixCount) = try Varint.decode32(body, from: body.startIndex)
        let start = body.index(body.startIndex, offsetBy: prefixCount)
        guard let end = body.index(start, offsetBy: Int(length), limitedBy: body.endIndex) else {
            throw Error.truncatedBody
        }
        self.message = Data(body[start..<end])
        self.payload = Data(body[end...])
    }

    /// The frame body: `uvarint32(message.count) || message || payload`.
    public func encodedBody() -> Data {
        var out = Data(Varint.encode(UInt64(message.count)))
        out.append(message)
        out.append(payload)
        return out
    }

    /// The complete frame, length prefix included.
    public func encodedFrame() -> Data {
        encodeFrame(encodedBody())
    }
}
