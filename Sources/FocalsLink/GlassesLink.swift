import Foundation
import FocalsWire
import FocalsProtocol
import FocalsTransport

/// A session with a pair of Focals, on top of any `ByteTransport`.
///
/// Owns the framing, performs the handshake, and hands every other message up as it
/// arrives. Nothing here knows whether the bytes came from RFCOMM, from ExternalAccessory
/// or from memory.
public actor GlassesLink {

    public enum Error: Swift.Error, Equatable {
        case alreadyConnected
        case notConnected
        case handshakeTimedOut
        case handshakeRejected(HandshakeResponse.Result?)
        /// The glasses require a newer companion protocol than this build speaks.
        case companionTooOld(requiredMajor: UInt32, requiredMinor: UInt32)
    }

    private let transport: any ByteTransport
    private var reader = FrameReader()
    private var pump: Task<Void, Never>?
    private var messageContinuation: AsyncStream<IncomingMessage>.Continuation?
    private var handshake = HandshakeState.idle
    private var connected = false

    /// The handshake has three racing participants — the caller awaiting it, the pump that
    /// may deliver the reply first, and the timeout — so its state is explicit rather than
    /// a bare optional continuation.
    private enum HandshakeState {
        case idle
        case waiting(CheckedContinuation<HandshakeResponse, any Swift.Error>)
        case settled(Result<HandshakeResponse, any Swift.Error>)
        case done
    }

    /// Every message from the glasses except the handshake response.
    public let messages: AsyncStream<IncomingMessage>

    public init(transport: any ByteTransport) {
        self.transport = transport
        var continuation: AsyncStream<IncomingMessage>.Continuation!
        self.messages = AsyncStream { continuation = $0 }
        self.messageContinuation = continuation
    }

    /// Opens the transport, sends the handshake and waits for the glasses to accept it.
    @discardableResult
    public func connect(timeout: Duration = .seconds(10)) async throws -> HandshakeResponse {
        guard !connected else { throw Error.alreadyConnected }
        let bytes = try await transport.open()
        connected = true
        startPump(bytes)

        try await transport.send(Handshake().encodedFrame())

        let deadline = Task { [weak self] in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled else { return }
            await self?.settleHandshake(.failure(Error.handshakeTimedOut))
        }
        defer { deadline.cancel() }

        let response = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<HandshakeResponse, any Swift.Error>) in
            // Runs synchronously on this actor, so there is no window between the
            // continuation existing and the link knowing about it.
            awaitHandshake(continuation)
        }

        guard response.result == .success else {
            throw Error.handshakeRejected(response.result)
        }
        guard response.companionIsNewEnough else {
            throw Error.companionTooOld(
                requiredMajor: response.requiredMajor, requiredMinor: response.requiredMinor)
        }
        return response
    }

    public func send(_ message: WireMessage) async throws {
        guard connected else { throw Error.notConnected }
        try await transport.send(message.encodedFrame())
    }

    public func disconnect() async {
        pump?.cancel()
        pump = nil
        connected = false
        messageContinuation?.finish()
        messageContinuation = nil
        await transport.close()
    }

    /// Parks the caller, unless the reply (or a failure) already arrived.
    private func awaitHandshake(_ continuation: CheckedContinuation<HandshakeResponse, any Swift.Error>) {
        switch handshake {
        case .settled(let result):
            handshake = .done
            continuation.resume(with: result)
        case .idle:
            handshake = .waiting(continuation)
        case .waiting, .done:
            continuation.resume(throwing: Error.alreadyConnected)
        }
    }

    /// Completes the handshake exactly once, whoever gets there first.
    private func settleHandshake(_ result: Result<HandshakeResponse, any Swift.Error>) {
        switch handshake {
        case .waiting(let continuation):
            handshake = .done
            continuation.resume(with: result)
        case .idle:
            handshake = .settled(result)
        case .settled, .done:
            break
        }
    }

    private func startPump(_ bytes: AsyncThrowingStream<Data, any Swift.Error>) {
        pump = Task { [weak self] in
            do {
                for try await chunk in bytes {
                    await self?.ingest(chunk)
                }
                await self?.finish(error: nil)
            } catch {
                await self?.finish(error: error)
            }
        }
    }

    private func ingest(_ chunk: Data) {
        reader.append(chunk)
        while true {
            let frame: Data?
            do {
                frame = try reader.next()
            } catch {
                // A bad length prefix desynchronises the stream; there is no resync point,
                // so the session ends rather than guessing.
                finish(error: error)
                return
            }
            guard let frame else { return }
            guard let decoded = try? IncomingMessage.decode(frameBody: frame) else { continue }
            for message in decoded { route(message) }
        }
    }

    private func route(_ message: IncomingMessage) {
        if message.kind == .handshakeResponse {
            settleHandshake(Result { try HandshakeResponse(decoding: message.body) })
            return
        }
        messageContinuation?.yield(message)
    }

    private func finish(error: (any Swift.Error)?) {
        connected = false
        settleHandshake(.failure(error ?? Error.notConnected))
        messageContinuation?.finish()
        messageContinuation = nil
    }
}

extension Handshake {
    /// The handshake as a complete frame.
    func encodedFrame() -> Data { encoded().encodedFrame() }
}
