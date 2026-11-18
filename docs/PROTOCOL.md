# The Focals companion protocol, as this project implements it

Everything here is a protocol fact: what goes on the wire between a pair of Focals and
whatever is acting as its companion. None of it is upstream code — see `UPSTREAM.md` for
the boundary. The implementation lives in `Sources/FocalsWire` and `Sources/FocalsProtocol`,
and the tests in `Tests/` pin every claim on this page.

## Transport

Classic Bluetooth, Serial Port Profile, service UUID `0x1101`. The glasses publish it and
the companion opens an RFCOMM channel to it. On macOS that is IOBluetooth and needs no
entitlement; on iOS the same link is reachable only through ExternalAccessory, because the
glasses are an MFi accessory (`IOS-MIGRATION.md` §12).

## Framing

Two nested length prefixes, both unsigned base-128 varints (LEB128), little-endian groups,
most significant bit as the continuation flag:

```
frame = uvarint32(byteCount(body)) || body
body  = uvarint32(byteCount(message)) || message || payload
```

- `message` is a protobuf message.
- `payload` is whatever remains in the frame: bulk bytes that would be wasteful to encode
  inside protobuf — socket data, file-transfer chunks, images. Most frames have none.
- A read from the transport carries no relationship to frame boundaries. `FrameReader`
  buffers partial frames, including a length prefix split mid-varint.
- A zero length or an implausibly large one is refused rather than buffered. There is no
  resynchronisation point in this format, so a desynchronised stream ends the session.

## Messages

Two union messages, each a flat list of optional submessages, **named for their
destination**:

| Union | Direction | Field 1 |
| --- | --- | --- |
| `BlackCoral` | companion → glasses | `handshake` |
| `Companion` | glasses → companion | `handshakeResponse` |

(`BlackCoral` is North's internal codename for the glasses; the firmware OTA metadata asks
for a `minBlackCoralProtocolVersion`, which is where the `BC` in the schema comes from.)

In practice one field is set per frame, but the wire format allows more and the decoder does
not assume otherwise. Field numbers are stable across every firmware seen, 1.81 through
1.115; `ToGlasses` and `ToCompanion` in `Sources/FocalsProtocol/MessageKinds.swift` carry
the full tables. A number missing from a table still decodes structurally — it just has no
name — so new firmware cannot break the reader.

## Handshake

The companion speaks first:

```
BlackCoral.handshake = Handshake { protocolMajorVersion: 4, protocolMinorVersion: 40 }
```

The glasses answer:

```
Companion.handshakeResponse = HandshakeResponse {
    result: 0 SUCCESS | 1 BLACK_CORAL_UPDATE_REQUIRED | 2 COMPANION_UPDATE_REQUIRED
    softwareVersion: string            // e.g. "1.119.0-4672"
    protocolMajorVersion, protocolMinorVersion
    requiredProtocolMajorVersion, requiredProtocolMinorVersion
}
```

4.40 is what firmware 1.119 requires and what the official companion sent. A result other
than `SUCCESS`, or a required version above ours, ends the session rather than continuing
into undefined behaviour.

## Not yet implemented

The network tunnel (`socketOpen` / `socketDataChunk` / `getHostByName`, where the companion
is the glasses' only route to the internet and terminates TLS in memory), notifications,
settings, sync, file transfer and the update flow. The decoder already surfaces all of them
structurally; none has a typed reader yet.

## Unverified

**Everything on this page is read from the protocol as documented and reverse-engineered by
others; nothing has been exchanged with a physical pair of Focals yet.** The first thing a
real handshake will test is this page.
