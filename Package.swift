// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FocalsKit",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "FocalsKit", targets: ["FocalsWire", "FocalsProtocol", "FocalsTransport", "FocalsLink"]),
        .executable(name: "focalsctl", targets: ["focalsctl"]),
    ],
    targets: [
        // Wire format: varints, frames, and a schema-less protobuf reader.
        .target(name: "FocalsWire"),

        // The glasses' message vocabulary, expressed as field numbers.
        .target(name: "FocalsProtocol", dependencies: ["FocalsWire"]),

        // Byte transports. RFCOMM on macOS, ExternalAccessory on iOS (not written yet).
        .target(
            name: "FocalsTransport",
            dependencies: ["FocalsWire"],
            linkerSettings: [.linkedFramework("IOBluetooth", .when(platforms: [.macOS]))]
        ),

        // The session on top of a transport: handshake, send, receive.
        .target(name: "FocalsLink", dependencies: ["FocalsWire", "FocalsProtocol", "FocalsTransport"]),

        .executableTarget(name: "focalsctl", dependencies: ["FocalsLink"]),

        .testTarget(name: "FocalsWireTests", dependencies: ["FocalsWire"]),
        .testTarget(name: "FocalsProtocolTests", dependencies: ["FocalsProtocol"]),
        .testTarget(name: "FocalsLinkTests", dependencies: ["FocalsLink"]),
    ]
)
