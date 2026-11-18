# Testing

## Running the suite

```
swift test
```

Zero dependencies, no network, no Bluetooth, no hardware, no simulator. It takes under a
second. Run it before every commit; it is the only automated check this project has.

As of 2026-11-18: **27 tests in 7 suites, all passing.**

## What is covered

| Area | Suite | What it pins |
| --- | --- | --- |
| Varints | `Varints` | round-trips, known encodings (`128` → `80 01`), truncation reported rather than guessed, 32-bit overflow refused |
| Framing | `Framing` | a whole frame, a frame delivered one byte at a time (including a length prefix split mid-varint), several frames in one read, an implausible length refused, a zero-length frame rejected without losing the next one |
| Message bodies | `Message bodies` | the protobuf/bulk-payload split, a round trip through a frame, a declared length longer than the frame |
| Protobuf codec | `Schema-less protobuf` | writer/reader round trip including nesting, truncation, the removed group wire types |
| Handshake | `Handshake` | encodes as field 1 of the to-glasses union carrying 4.40, decodes a real-shaped response, notices a required version above ours, keeps an unrecognised result code |
| Message tables | `Message tables` | field numbers unique per direction, an unknown field named rather than dropped, bulk payload travelling with its message |
| Session | `GlassesLink` | handshake sent first and accepted, rejection refused, timeout instead of hanging, messages delivered when split across reads, stream finished when the transport drops |

`LoopbackTransport` is what makes the session testable: it is a `ByteTransport` like any
other, so `GlassesLink` cannot tell it from Bluetooth.

## What is not covered, and cannot be yet

**Nothing has been exchanged with physical glasses.** Every protocol claim in
[`PROTOCOL.md`](PROTOCOL.md) — the framing, the version numbers, the field tables — is read
from documentation and reverse engineering by others. The suite proves the implementation
matches what we believe; it cannot prove what we believe is right.

`RFCOMMTransport` has no unit tests: it is a thin adapter over IOBluetooth delegate
callbacks, and testing it would mean testing a mock of IOBluetooth. It is exercised manually
instead — see the drill log.

## Manual checks

| Check | Command | Needs |
| --- | --- | --- |
| Bluetooth enumeration works | `swift run focalsctl devices` | a Mac with Bluetooth |
| The protocol is right | `swift run focalsctl probe` | **a paired pair of Focals** |

## Drill log

| Date | Drill | Result |
| --- | --- | --- |
| 2026-11-18 | `focalsctl devices` against real Bluetooth | Passed. Enumerated 13 genuine paired devices on Abraham's Mac. |
| — | `focalsctl probe` against glasses | **Never run.** Blocked on hardware; the glasses have been discharged since 2020. |
