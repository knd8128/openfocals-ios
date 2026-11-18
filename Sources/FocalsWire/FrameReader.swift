import Foundation

/// Splits the byte stream coming off the transport into frames.
///
/// The glasses frame every message as `uvarint32(count) || body`. A read from the transport
/// may hand back part of a frame, several frames, or a frame boundary mid-varint, so the
/// reader buffers whatever it cannot finish.
public struct FrameReader: Sendable {

    public enum Error: Swift.Error, Equatable {
        /// A frame announced more bytes than `frameSizeLimit` allows.
        case frameTooLarge(UInt32)
        /// A frame announced zero bytes. The glasses are not expected to send these.
        case emptyFrame
    }

    /// Frames larger than this are refused rather than buffered, so a corrupt length
    /// prefix cannot make the reader allocate without bound.
    public var frameSizeLimit: UInt32

    private var buffer = Data()
    private var pending: UInt32?

    public init(frameSizeLimit: UInt32 = 4 * 1024 * 1024) {
        self.frameSizeLimit = frameSizeLimit
    }

    /// Buffered bytes not yet formed into a frame. Useful in tests and diagnostics.
    public var bufferedByteCount: Int { buffer.count }

    public mutating func append(_ data: Data) {
        buffer.append(data)
    }

    /// Returns the next complete frame body, or nil when more bytes are needed.
    public mutating func next() throws -> Data? {
        while true {
            if pending == nil {
                guard !buffer.isEmpty else { return nil }
                let decoded: (value: UInt32, byteCount: Int)
                do {
                    decoded = try Varint.decode32(buffer, from: buffer.startIndex)
                } catch Varint.Error.truncated {
                    return nil // the length prefix itself is split across reads
                }
                guard decoded.value != 0 else {
                    buffer.removeFirst(decoded.byteCount)
                    throw Error.emptyFrame
                }
                guard decoded.value <= frameSizeLimit else {
                    throw Error.frameTooLarge(decoded.value)
                }
                buffer.removeFirst(decoded.byteCount)
                pending = decoded.value
            }

            guard let want = pending else { return nil }
            guard buffer.count >= Int(want) else { return nil }
            let body = buffer.prefix(Int(want))
            buffer.removeFirst(Int(want))
            pending = nil
            return Data(body)
        }
    }

    /// Drains every frame currently available.
    public mutating func drain() throws -> [Data] {
        var frames: [Data] = []
        while let frame = try next() { frames.append(frame) }
        return frames
    }
}

/// Wraps a frame body in its length prefix, ready for the transport.
public func encodeFrame(_ body: Data) -> Data {
    var out = Data(Varint.encode(UInt64(body.count)))
    out.append(body)
    return out
}
