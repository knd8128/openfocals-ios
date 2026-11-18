import Foundation

/// A bidirectional stream of bytes to the glasses.
///
/// Everything above this protocol is platform-independent. The whole iOS question lives
/// here and nowhere else: on macOS the bytes come from an RFCOMM channel, on iOS they
/// come from an `EASession`'s stream pair, and in tests they come from memory.
public protocol ByteTransport: Sendable {
    /// Connects and returns the inbound stream. Finishes when the link drops.
    func open() async throws -> AsyncThrowingStream<Data, any Error>
    func send(_ data: Data) async throws
    func close() async
}

public enum TransportError: Error, Equatable {
    case notConnected
    case deviceNotFound(String)
    /// The device is reachable but advertises no serial-port service.
    case serviceNotFound
    case openFailed(code: Int32)
    case writeFailed(code: Int32)
    case closedByPeer
}
