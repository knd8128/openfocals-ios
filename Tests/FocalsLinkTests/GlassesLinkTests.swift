import Testing
import Foundation
import FocalsWire
import FocalsProtocol
import FocalsTransport
@testable import FocalsLink

/// Builds the frame the glasses would send back for a successful handshake.
private func handshakeResponseFrame(
    software: String = "1.119.0-4672", result: UInt64 = 0,
    major: UInt64 = 4, minor: UInt64 = 40,
    requiredMajor: UInt64 = 4, requiredMinor: UInt64 = 40
) -> Data {
    var inner = ProtobufWriter()
    inner.varint(field: 1, result)
    inner.string(field: 2, software)
    inner.varint(field: 3, major)
    inner.varint(field: 4, minor)
    inner.varint(field: 5, requiredMajor)
    inner.varint(field: 6, requiredMinor)

    var outer = ProtobufWriter()
    outer.bytes(field: ToCompanion.handshakeResponse.rawValue, inner.data)
    return WireMessage(message: outer.data).encodedFrame()
}

private func messageFrame(_ kind: ToCompanion, _ build: (inout ProtobufWriter) -> Void) -> Data {
    var inner = ProtobufWriter()
    build(&inner)
    var outer = ProtobufWriter()
    outer.bytes(field: kind.rawValue, inner.data)
    return WireMessage(message: outer.data).encodedFrame()
}

@Suite("GlassesLink")
struct GlassesLinkTests {

    @Test("sends the handshake first and accepts the reply")
    func handshakeSucceeds() async throws {
        let transport = LoopbackTransport()
        let link = GlassesLink(transport: transport)

        async let connecting = link.connect(timeout: .seconds(5))
        try await waitUntil { await !transport.sent.isEmpty }
        await transport.deliver(handshakeResponseFrame())

        let response = try await connecting
        #expect(response.softwareVersion == "1.119.0-4672")
        #expect(await transport.sentBytes == Handshake().encoded().encodedFrame())
    }

    @Test("refuses to continue when the glasses reject the handshake")
    func handshakeRejected() async throws {
        let transport = LoopbackTransport()
        let link = GlassesLink(transport: transport)

        async let connecting: Void = {
            do {
                _ = try await link.connect(timeout: .seconds(5))
                Issue.record("connect should have thrown")
            } catch let error as GlassesLink.Error {
                #expect(error == .handshakeRejected(.glassesUpdateRequired))
            }
        }()
        try await waitUntil { await !transport.sent.isEmpty }
        await transport.deliver(handshakeResponseFrame(result: 1))
        try await connecting
    }

    @Test("times out instead of hanging when nothing answers")
    func handshakeTimesOut() async throws {
        let link = GlassesLink(transport: LoopbackTransport())
        do {
            _ = try await link.connect(timeout: .milliseconds(80))
            Issue.record("connect should have timed out")
        } catch let error as GlassesLink.Error {
            #expect(error == .handshakeTimedOut)
        }
    }

    @Test("delivers later messages, including ones split across reads")
    func deliversMessages() async throws {
        let transport = LoopbackTransport()
        let link = GlassesLink(transport: transport)

        async let connecting = link.connect(timeout: .seconds(5))
        try await waitUntil { await !transport.sent.isEmpty }
        await transport.deliver(handshakeResponseFrame())
        _ = try await connecting

        let battery = messageFrame(.batteryState) { $0.varint(field: 1, 73) }
        // Deliver it one byte at a time: the reader has to reassemble it.
        for byte in battery { await transport.deliver(Data([byte])) }

        var iterator = await link.messages.makeAsyncIterator()
        let message = try #require(await iterator.next())
        #expect(message.kind == .batteryState)
        #expect(message.describeFields() == "1=73")
    }

    @Test("ends the message stream when the transport drops")
    func streamFinishesOnClose() async throws {
        let transport = LoopbackTransport()
        let link = GlassesLink(transport: transport)

        async let connecting = link.connect(timeout: .seconds(5))
        try await waitUntil { await !transport.sent.isEmpty }
        await transport.deliver(handshakeResponseFrame())
        _ = try await connecting

        await transport.close()

        var seen = 0
        for await _ in await link.messages { seen += 1 }
        #expect(seen == 0)
    }
}

/// Polls a condition instead of sleeping a fixed amount, so the tests stay quick and
/// do not depend on scheduling luck.
private func waitUntil(
    timeout: Duration = .seconds(2), _ condition: @Sendable () async -> Bool
) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() { return }
        try await Task.sleep(for: .milliseconds(5))
    }
    Issue.record("condition never became true")
}
