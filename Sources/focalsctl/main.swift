import Foundation
import FocalsWire
import FocalsProtocol
import FocalsTransport
import FocalsLink

let usage = """
focalsctl — talk to North Focals glasses over classic Bluetooth from a Mac.

  focalsctl devices            list paired Bluetooth devices, marking likely Focals
  focalsctl probe [name]       connect, handshake, then print every message that arrives

The glasses must already be paired in System Settings > Bluetooth. `name` matches a paired
device exactly or by prefix; with no name, the first paired device whose name contains
"focals" is used.
"""

#if !os(macOS)
FileHandle.standardError.write(Data("focalsctl needs macOS: classic Bluetooth is not reachable elsewhere.\n".utf8))
exit(1)
#else

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

@MainActor
func listDevices() {
    let devices = RFCOMMTransport.pairedDevices()
    guard !devices.isEmpty else {
        print("No paired Bluetooth devices. Pair the glasses in System Settings > Bluetooth first.")
        return
    }
    print("Paired devices:")
    for device in devices {
        let name = device.name ?? "(unnamed)"
        let mark = name.lowercased().contains("focals") ? "  <- looks like Focals" : ""
        print("  \(name)  [\(device.addressString ?? "?")]\(mark)")
    }
}

@MainActor
func probe(name: String?) async {
    let transport: RFCOMMTransport
    do {
        if let name {
            transport = try RFCOMMTransport(named: name)
        } else {
            guard let device = RFCOMMTransport.discoverPairedFocals().first else {
                fail("No paired device whose name contains \"focals\". Pair them first, or pass a name.")
            }
            transport = RFCOMMTransport(device: device)
        }
    } catch {
        fail("Could not find that device: \(error)")
    }

    print("Device:   \(transport.deviceName)")
    let link = GlassesLink(transport: transport)

    do {
        let response = try await link.connect()
        print("Handshake accepted.")
        print("  glasses software:  \(response.softwareVersion)")
        print("  glasses protocol:  \(response.major).\(response.minor)")
        print("  requires at least: \(response.requiredMajor).\(response.requiredMinor)")
        print("  we sent:           \(ProtocolVersion.major).\(ProtocolVersion.minor)")
    } catch {
        fail("Handshake failed: \(error)")
    }

    print("\nListening. Ctrl-C to stop.\n")
    for await message in await link.messages {
        let payload = message.payload.isEmpty ? "" : "  (+\(message.payload.count)B payload)"
        print("\(message.name)\(payload)  \(message.describeFields())")
    }
    print("Link closed.")
}

let arguments = Array(CommandLine.arguments.dropFirst())

switch arguments.first {
case "devices":
    Task { @MainActor in
        listDevices()
        exit(0)
    }
case "probe":
    Task { @MainActor in
        await probe(name: arguments.count > 1 ? arguments[1] : nil)
        exit(0)
    }
default:
    print(usage)
    exit(arguments.isEmpty ? 0 : 1)
}

// IOBluetooth delivers its callbacks on the main run loop, and the main actor is
// serviced from it, so the run loop has to spin for anything above to make progress.
RunLoop.main.run()
#endif
