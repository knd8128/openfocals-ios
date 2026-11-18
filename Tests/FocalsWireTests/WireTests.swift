import Testing
import Foundation
@testable import FocalsWire

@Suite("Varints")
struct VarintTests {

    @Test("round-trips the values the protocol actually uses")
    func roundTrip() throws {
        for value: UInt64 in [0, 1, 127, 128, 300, 950, 16_383, 16_384, 1 << 31, UInt64(UInt32.max)] {
            let bytes = Varint.encode(value)
            let (decoded, count) = try Varint.decode(bytes, from: bytes.startIndex)
            #expect(decoded == value)
            #expect(count == bytes.count)
        }
    }

    @Test("encodes small values in one byte and 128 in two")
    func knownEncodings() {
        #expect(Varint.encode(UInt64(0)) == [0x00])
        #expect(Varint.encode(UInt64(127)) == [0x7F])
        #expect(Varint.encode(UInt64(128)) == [0x80, 0x01])
        #expect(Varint.encode(UInt64(300)) == [0xAC, 0x02])
    }

    @Test("reports truncation rather than guessing")
    func truncated() {
        #expect(throws: Varint.Error.truncated) {
            _ = try Varint.decode([0x80, 0x80] as [UInt8], from: 0)
        }
    }

    @Test("refuses a value too wide for 32 bits")
    func overflow32() {
        let wide = Varint.encode(UInt64(UInt32.max) + 1)
        #expect(throws: Varint.Error.overflow) {
            _ = try Varint.decode32(wide, from: wide.startIndex)
        }
    }
}

@Suite("Framing")
struct FrameReaderTests {

    @Test("reads a frame delivered whole")
    func singleFrame() throws {
        var reader = FrameReader()
        reader.append(encodeFrame(Data([1, 2, 3])))
        #expect(try reader.next() == Data([1, 2, 3]))
        #expect(try reader.next() == nil)
    }

    @Test("reassembles a frame split across reads, including inside the length prefix")
    func splitAcrossReads() throws {
        let body = Data(repeating: 0xAB, count: 300) // length prefix is two bytes
        let frame = encodeFrame(body)
        var reader = FrameReader()
        for byte in frame {
            #expect(try reader.next() == nil || reader.bufferedByteCount == 0)
            reader.append(Data([byte]))
        }
        #expect(try reader.next() == body)
    }

    @Test("reads several frames arriving in one read")
    func coalescedFrames() throws {
        var data = Data()
        for n in 1...5 { data.append(encodeFrame(Data(repeating: UInt8(n), count: n * 40))) }
        var reader = FrameReader()
        reader.append(data)
        let frames = try reader.drain()
        #expect(frames.count == 5)
        #expect(frames[4] == Data(repeating: 5, count: 200))
        #expect(reader.bufferedByteCount == 0)
    }

    @Test("refuses an implausible length instead of buffering forever")
    func sizeLimit() {
        var reader = FrameReader(frameSizeLimit: 1024)
        reader.append(Data(Varint.encode(UInt64(99_999))))
        #expect(throws: FrameReader.Error.frameTooLarge(99_999)) { _ = try reader.next() }
    }

    @Test("rejects a zero-length frame and keeps going")
    func emptyFrame() throws {
        var reader = FrameReader()
        reader.append(Data([0x00]))
        reader.append(encodeFrame(Data([9])))
        #expect(throws: FrameReader.Error.emptyFrame) { _ = try reader.next() }
        #expect(try reader.next() == Data([9]))
    }
}

@Suite("Message bodies")
struct WireMessageTests {

    @Test("separates the protobuf from the bulk payload")
    func splitsPayload() throws {
        let message = Data([0x08, 0x04])
        let payload = Data(repeating: 0x5A, count: 950)
        let encoded = WireMessage(message: message, payload: payload).encodedBody()
        let decoded = try WireMessage(decoding: encoded)
        #expect(decoded.message == message)
        #expect(decoded.payload == payload)
    }

    @Test("round-trips through a frame")
    func roundTripsFrame() throws {
        let original = WireMessage(message: Data([0x0A, 0x02, 0x08, 0x2C]))
        var reader = FrameReader()
        reader.append(original.encodedFrame())
        let body = try #require(try reader.next())
        #expect(try WireMessage(decoding: body) == original)
    }

    @Test("rejects a declared length longer than the frame")
    func truncatedBody() {
        var body = Data(Varint.encode(UInt64(10)))
        body.append(Data([1, 2, 3]))
        #expect(throws: WireMessage.Error.truncatedBody) { _ = try WireMessage(decoding: body) }
    }
}

@Suite("Schema-less protobuf")
struct ProtobufTests {

    @Test("reads back what the writer produced")
    func writerReaderRoundTrip() throws {
        var writer = ProtobufWriter()
        writer.varint(field: 1, UInt64(4))
        writer.string(field: 2, "1.119.0-4672")
        writer.message(field: 3) { $0.varint(field: 7, UInt64(40)) }

        let fields = try ProtobufReader.scan(writer.data)
        #expect(fields.count == 3)
        #expect(fields[0] == ProtoField(number: 1, value: .varint(4)))
        #expect(fields[1] == ProtoField(number: 2, value: .bytes(Data("1.119.0-4672".utf8))))
        guard case .bytes(let nested) = fields[2].value else { Issue.record("field 3 is not a message"); return }
        #expect(try ProtobufReader.scan(nested) == [ProtoField(number: 7, value: .varint(40))])
    }

    @Test("reports truncation instead of returning half a field")
    func truncatedField() {
        #expect(throws: ProtobufReader.Error.truncated) {
            _ = try ProtobufReader.scan(Data([0x12, 0x05, 0x61]))
        }
    }

    @Test("rejects the removed group wire types")
    func groupsUnsupported() {
        #expect(throws: ProtobufReader.Error.unsupportedWireType(3)) {
            _ = try ProtobufReader.scan(Data([0x0B]))
        }
    }
}
