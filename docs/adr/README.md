# Architecture decision records

One file per decision with lasting consequences, numbered in order. Start from
[`0000-template.md`](0000-template.md).

An accepted ADR's decision is never edited. It is either superseded by a new ADR, or
extended with a dated `## Follow-up` or `## Verification` section.

| # | Decision | Status | Date |
| --- | --- | --- | --- |
| [0001](0001-one-byte-transport-macos-first.md) | One `ByteTransport` protocol, with macOS RFCOMM implemented first | accepted | 2026-11-18 |
| [0002](0002-decode-protobuf-without-generated-types.md) | Decode protobuf structurally, with no generated types and no `swift-protobuf` | accepted | 2026-11-18 |
| [0003](0003-development-signed-distribution-only.md) | This app is distributed development-signed, never through the App Store | accepted | 2026-11-18 |
