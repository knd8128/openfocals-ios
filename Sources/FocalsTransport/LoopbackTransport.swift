import Foundation

/// An in-memory transport. Whatever is written shows up on `sent`; whatever is handed to
/// `deliver` shows up on the inbound stream. Lets the link, the framer and the handshake
/// be tested with no glasses and no Bluetooth.
public actor LoopbackTransport: ByteTransport {
    private var continuation: AsyncThrowingStream<Data, any Error>.Continuation?
    private var isOpen = false

    /// Everything the link has written, in order.
    public private(set) var sent: [Data] = []

    public init() {}

    public func open() async throws -> AsyncThrowingStream<Data, any Error> {
        isOpen = true
        return AsyncThrowingStream { continuation in
            self.continuation = continuation
        }
    }

    public func send(_ data: Data) async throws {
        guard isOpen else { throw TransportError.notConnected }
        sent.append(data)
    }

    public func close() async {
        isOpen = false
        continuation?.finish()
        continuation = nil
    }

    /// Pushes bytes towards the link, as if the glasses had sent them.
    public func deliver(_ data: Data) {
        continuation?.yield(data)
    }

    public func fail(_ error: any Error) {
        continuation?.finish(throwing: error)
    }

    /// Concatenation of everything written, for assertions on framing.
    public var sentBytes: Data { sent.reduce(into: Data()) { $0.append($1) } }
}
