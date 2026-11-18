#if os(macOS)
import Foundation
import IOBluetooth

/// Classic Bluetooth RFCOMM, the link the glasses actually speak.
///
/// macOS exposes the Serial Port Profile to any application through IOBluetooth, with no
/// MFi involvement — which is why the Mac is where this protocol gets learned. iOS has no
/// equivalent; there the same bytes have to come from ExternalAccessory.
///
/// The glasses must already be paired with this Mac; this opens a channel to a paired
/// device, it does not drive pairing.
@MainActor
public final class RFCOMMTransport: NSObject, ByteTransport {

    /// Serial Port Profile, `0x1101`. The service the glasses publish for the companion.
    public static let serialPortServiceUUID = IOBluetoothSDPUUID(uuid16: 0x1101)

    /// Paired devices whose name looks like a pair of Focals.
    public static func discoverPairedFocals() -> [IOBluetoothDevice] {
        pairedDevices().filter { ($0.name ?? "").lowercased().contains("focals") }
    }

    public static func pairedDevices() -> [IOBluetoothDevice] {
        (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
    }

    private let device: IOBluetoothDevice
    private var channel: IOBluetoothRFCOMMChannel?
    private var continuation: AsyncThrowingStream<Data, any Error>.Continuation?
    private var openContinuation: CheckedContinuation<Void, any Error>?

    public init(device: IOBluetoothDevice) {
        self.device = device
        super.init()
    }

    /// Looks a paired device up by name, exactly or by prefix.
    public convenience init(named name: String) throws {
        let matches = Self.pairedDevices().filter {
            guard let deviceName = $0.name else { return false }
            return deviceName == name || deviceName.hasPrefix(name)
        }
        guard let device = matches.first else { throw TransportError.deviceNotFound(name) }
        self.init(device: device)
    }

    public var deviceName: String { device.name ?? device.addressString ?? "?" }

    public func open() async throws -> AsyncThrowingStream<Data, any Error> {
        let stream = AsyncThrowingStream<Data, any Error> { continuation in
            self.continuation = continuation
        }

        guard let record = device.getServiceRecord(for: Self.serialPortServiceUUID) else {
            throw TransportError.serviceNotFound
        }
        var channelID: BluetoothRFCOMMChannelID = 0
        guard record.getRFCOMMChannelID(&channelID) == kIOReturnSuccess else {
            throw TransportError.serviceNotFound
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            self.openContinuation = continuation
            var opened: IOBluetoothRFCOMMChannel?
            let status = device.openRFCOMMChannelAsync(&opened, withChannelID: channelID, delegate: self)
            if status != kIOReturnSuccess {
                self.openContinuation = nil
                continuation.resume(throwing: TransportError.openFailed(code: status))
                return
            }
            self.channel = opened
        }

        return stream
    }

    public func send(_ data: Data) async throws {
        guard let channel, channel.isOpen() else { throw TransportError.notConnected }
        // The channel's MTU caps a single write; longer messages go out in pieces.
        let mtu = Int(channel.getMTU())
        var offset = 0
        while offset < data.count {
            let end = min(offset + mtu, data.count)
            var slice = [UInt8](data[data.index(data.startIndex, offsetBy: offset)..<data.index(data.startIndex, offsetBy: end)])
            let status = slice.withUnsafeMutableBytes { buffer -> IOReturn in
                channel.writeSync(buffer.baseAddress, length: UInt16(buffer.count))
            }
            guard status == kIOReturnSuccess else { throw TransportError.writeFailed(code: status) }
            offset = end
        }
    }

    public func close() async {
        channel?.close()
        channel = nil
        continuation?.finish()
        continuation = nil
    }
}

extension RFCOMMTransport: IOBluetoothRFCOMMChannelDelegate {

    public nonisolated func rfcommChannelOpenComplete(
        _ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn
    ) {
        MainActor.assumeIsolated {
            guard let continuation = openContinuation else { return }
            openContinuation = nil
            if error == kIOReturnSuccess {
                continuation.resume()
            } else {
                continuation.resume(throwing: TransportError.openFailed(code: error))
            }
        }
    }

    public nonisolated func rfcommChannelData(
        _ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length: Int
    ) {
        let data = Data(bytes: dataPointer, count: length)
        MainActor.assumeIsolated {
            _ = continuation?.yield(data)
        }
    }

    public nonisolated func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        MainActor.assumeIsolated {
            continuation?.finish()
            continuation = nil
            channel = nil
            if let continuation = openContinuation {
                openContinuation = nil
                continuation.resume(throwing: TransportError.closedByPeer)
            }
        }
    }
}
#endif
