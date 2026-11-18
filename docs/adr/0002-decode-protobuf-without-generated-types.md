# ADR-0002: Decode protobuf structurally, with no generated types and no `swift-protobuf`

- **Status:** accepted
- **Date:** 2026-11-18
- **Decided by:** Claude

## Context

The glasses' message schema is large — two union messages carrying 50 and 40 submessage
fields respectively, each of those a message of its own — and it is **only partly known**.
What exists was reverse-engineered from North's Android app by a third party, in a
repository with no licence, across five firmware versions.

Two things follow. First, copying that schema into this repository would cross the boundary
`UPSTREAM.md` sets: field numbers and framing are protocol facts, but a `.proto` file is a
transcribed artifact. Second, generated types fail closed on anything they were not
generated for, and this project will certainly meet fields nobody has catalogued.

## Decision

No `.proto` files, no code generation, no `swift-protobuf` dependency.

`FocalsWire` implements the wire format directly: `ProtobufReader.scan` walks a message and
returns `[ProtoField]` of field number and value; `ProtobufWriter` builds messages field by
field. `FocalsProtocol` supplies meaning as plain Swift enums (`ToGlasses`, `ToCompanion`)
mapping field numbers to names, and hand-written readers for the messages that need typed
access — currently only `HandshakeResponse`.

## Consequences

- **An unknown field still decodes.** It reads as a number and a value and logs as
  `unknown(99)` rather than throwing, so new or uncatalogued firmware messages cannot break
  the reader. There is a test for exactly this.
- No build-time code generation, no dependency to resolve, no network access needed to
  build. The package has zero dependencies.
- The clean-room boundary holds: what crosses is a table of integers we wrote ourselves.
- **The cost is per-message work.** Every message that needs typed access needs a
  hand-written reader, and a hand-written reader can silently disagree with the real schema
  in a way a generated one cannot. Each one therefore carries tests that encode a realistic
  message and read it back.
- Revisit when the typed readers for the larger messages — sync, settings, file transfer,
  the network tunnel — cost more to maintain than a schema we write ourselves would. That
  schema would be ours, written from the facts; it is a later decision, not a blocked one.

## Alternatives considered

- **Vendor the extracted `.proto` and generate with `swift-protobuf`.** Rejected on the
  licence boundary, and because generated proto2 types fail on fields they do not know.
- **Write our own `.proto` now and generate from it.** Rejected for now only: it is real
  work for messages we cannot yet test against hardware, and the structural decoder already
  gives us the handshake and full visibility into everything else.
