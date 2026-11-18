# ADR-0001: One `ByteTransport` protocol, with macOS RFCOMM implemented first

- **Status:** accepted
- **Date:** 2026-11-18
- **Decided by:** Abraham (order of work), Claude (the abstraction)

## Context

The glasses speak a single byte stream framed as described in [`PROTOCOL.md`](../PROTOCOL.md).
How that stream is obtained is the only part of the system that differs per platform:

- **macOS** reaches it over classic Bluetooth RFCOMM through IOBluetooth. No MFi, no
  protocol string, no provisioning profile, no entitlement.
- **iOS** cannot. The glasses are an MFi accessory (`IOS-MIGRATION.md` §12), so the same
  bytes arrive only through `ExternalAccessory`/`EASession`, which additionally requires the
  accessory's protocol string declared in `Info.plist` — a string we do not yet know.

Abraham's instruction was to build macOS first and add the iOS companion once the macOS side
is stable against hardware.

## Decision

All platform difference is confined to one protocol:

```swift
protocol ByteTransport: Sendable {
    func open() async throws -> AsyncThrowingStream<Data, any Error>
    func send(_ data: Data) async throws
    func close() async
}
```

`RFCOMMTransport` (macOS) and `LoopbackTransport` (tests) implement it today; `EATransport`
(iOS) will implement it later. Nothing above it — framing, the protobuf codec, the message
tables, the handshake, `GlassesLink`, and every feature still to come — may reference a
transport type, a platform, or a Bluetooth framework.

## Consequences

- Building macOS first costs nothing in rework: adding iOS is one new file plus an app
  target, not a port.
- The protocol can be learned and debugged without fighting Apple's accessory rules, and
  without waiting on the unknown protocol string.
- Tests run with no Bluetooth and no hardware, because `LoopbackTransport` is just another
  implementation. The 27 tests in this repository all run this way.
- The cost: `ByteTransport` is deliberately dumb — bytes in, bytes out. Anything a real
  transport knows that this hides (an `EAAccessory`'s serial number and protocol strings, an
  RFCOMM channel's MTU) has to be exposed as a transport-specific extra rather than through
  the protocol. `RFCOMMTransport` already does this for MTU-sized writes.
- Reversing it would mean rewriting `GlassesLink` per platform. It will not be reversed.

## Alternatives considered

- **Write the iOS app directly.** Rejected: blocked on hardware *and* on the unknown
  protocol string, and every bug would be debugged through a provisioning profile.
- **Two separate codebases.** Rejected: the protocol is the hard part and duplicating it
  guarantees the two drift.
