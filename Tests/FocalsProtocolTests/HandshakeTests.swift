import Testing
import Foundation
import FocalsWire
@testable import FocalsProtocol

@Suite("Handshake")
struct HandshakeTests {

    @Test("encodes as field 1 of the to-glasses union, carrying 4.40")
    func encodesVersion() throws {
        let fields = try ProtobufReader.scan(Handshake().encoded().message)
        #expect(fields.count == 1)
        #expect(fields[0].number == ToGlasses.handshake.rawValue)
        guard case .bytes(let body) = fields[0].value else { Issue.record("not a message"); return }
        #expect(try ProtobufReader.scan(body) == [
            ProtoField(number: 1, value: .varint(4)),
            ProtoField(number: 2, value: .varint(40)),
        ])
    }

    @Test("decodes a response the way the glasses send it")
    func decodesResponse() throws {
        var writer = ProtobufWriter()
        writer.varint(field: 1, UInt64(0))
        writer.string(field: 2, "1.119.0-4672")
        writer.varint(field: 3, UInt64(4))
        writer.varint(field: 4, UInt64(40))
        writer.varint(field: 5, UInt64(4))
        writer.varint(field: 6, UInt64(40))

        let response = try HandshakeResponse(decoding: writer.data)
        #expect(response.result == .success)
        #expect(response.softwareVersion == "1.119.0-4672")
        #expect(response.major == 4 && response.minor == 40)
        #expect(response.companionIsNewEnough)
    }

    @Test("notices when the glasses demand a newer companion")
    func tooOld() throws {
        var writer = ProtobufWriter()
        writer.varint(field: 1, UInt64(2))
        writer.string(field: 2, "9.9.9")
        writer.varint(field: 5, UInt64(5))
        writer.varint(field: 6, UInt64(0))
        let response = try HandshakeResponse(decoding: writer.data)
        #expect(response.result == .companionUpdateRequired)
        #expect(!response.companionIsNewEnough)
    }

    @Test("keeps an unrecognised result code instead of dropping it")
    func unknownResult() throws {
        var writer = ProtobufWriter()
        writer.varint(field: 1, UInt64(77))
        let response = try HandshakeResponse(decoding: writer.data)
        #expect(response.result == nil)
        #expect(response.rawResult == 77)
    }
}

@Suite("Message tables")
struct MessageKindTests {

    @Test("field numbers are unique in each direction")
    func uniqueNumbers() {
        #expect(Set(ToGlasses.allCases.map(\.rawValue)).count == ToGlasses.allCases.count)
        #expect(Set(ToCompanion.allCases.map(\.rawValue)).count == ToCompanion.allCases.count)
    }

    @Test("names an unknown field rather than discarding it")
    func unknownFieldStillDecodes() throws {
        var inner = ProtobufWriter()
        inner.varint(field: 1, UInt64(1))
        var writer = ProtobufWriter()
        writer.bytes(field: 99, inner.data)
        let body = WireMessage(message: writer.data).encodedBody()

        let messages = try IncomingMessage.decode(frameBody: body)
        #expect(messages.count == 1)
        #expect(messages[0].kind == nil)
        #expect(messages[0].name == "unknown(99)")
    }

    @Test("carries the bulk payload alongside the message")
    func payloadTravels() throws {
        var writer = ProtobufWriter()
        writer.bytes(field: ToCompanion.socketDataChunk.rawValue, Data([0x08, 0x01]))
        let payload = Data(repeating: 0x7F, count: 512)
        let body = WireMessage(message: writer.data, payload: payload).encodedBody()

        let messages = try IncomingMessage.decode(frameBody: body)
        #expect(messages[0].kind == .socketDataChunk)
        #expect(messages[0].payload == payload)
    }
}
