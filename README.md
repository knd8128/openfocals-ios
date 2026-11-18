# openfocals-ios

An iOS companion app for **North Focals** smart glasses.

North shut down in 2020 after Google acquired the company, and the cloud services the
glasses depend on went dark with it. [openfocals](https://github.com/aegray/openfocals)
by [aegray](https://github.com/aegray) brought the glasses back to life on Android: it
replaces North's companion app, and stands in for the dead cloud by answering the
glasses' own requests locally. There is no equivalent for iPhone owners.

This project is the attempt to build one.

## Status

**The question the project hung on is answered, and the protocol stack exists on macOS.**
On 2026-11-18 the data container of North's own iOS companion app turned up on the owner's
Mac, recovered from an old iPhone backup; it settles the transport. A Swift package and a
macOS command line tool were written the same day. **No byte has been exchanged with real
glasses yet** — see *Building and running* below for exactly what is and is not verified.

The analysis is in [`docs/IOS-MIGRATION.md`](docs/IOS-MIGRATION.md); section 12 holds the
finding and supersedes parts of the earlier verdict.

### The question everything hung on, and its answer

North shipped an **official iOS app** for Focals, `com.bynorth.companion` (setup, settings,
alignment, notification selection; iPhone 5S and newer, pulled from the App Store in July
2020). So an iPhone-to-glasses channel existed. Two candidate explanations had opposite
consequences:

| | How the iOS app talked to the glasses | Consequence |
| --- | --- | --- |
| **H1** | iAP2 over ExternalAccessory | The glasses are an MFi accessory. Our app can open the same session, but **sideload only** — App Store review requires the developer to be authorised for the accessory's protocol string, and North is defunct |
| **H2** | A custom BLE GATT service | No MFi involved. Core Bluetooth would be enough, and App Store distribution would be back on the table |

**It is H1.** The app stored the companion link as an **accessory name and serial number**
(`Focals - 00DW` / `1f47080e`) and the notification link as a **Core Bluetooth peripheral
UUID**. Those are the storage shapes of `EAAccessory` and `CBPeripheral`: a Core Bluetooth
client must persist the peripheral's UUID to reconnect, while an ExternalAccessory client has
no UUID and identifies an accessory by name and serial. The app also calls only the
notification side "Ble". Evidence, not yet proof — reading
`UISupportedExternalAccessoryProtocols` out of the app binary would be proof — but it points
one way and matches everything else known.

What that means in practice:

- **The App Store is out, permanently.** Distribution is development-signed or sideloaded.
- **iOS can nevertheless talk to these glasses, through a public API.** `EASession` hands back
  an `InputStream`/`OutputStream` pair, which is exactly the byte transport the planned
  architecture is built around. The MFi requirement falls on the accessory hardware, and the
  glasses meet it.
- **The next gate is hardware, not the IPA.** The one missing detail is the accessory protocol
  string, and a ten-line development build can ask a bonded pair of glasses for it directly
  (`EAAccessoryManager.connectedAccessories` → `protocolStrings`) — which would also turn the
  inference above into fact.

## Building and running

Zero dependencies. Swift 6, macOS 14 or newer.

```
swift build          # builds FocalsKit and focalsctl
swift test           # 27 tests, under a second, no hardware needed
swift run focalsctl  # usage
```

`FocalsKit` is four modules:

| Module | What it does |
| --- | --- |
| `FocalsWire` | varints, frame reassembly, the protobuf/payload split, a schema-less protobuf codec |
| `FocalsProtocol` | the message tables for both directions, the 4.40 handshake |
| `FocalsTransport` | `ByteTransport`, plus RFCOMM on macOS and a loopback for tests |
| `FocalsLink` | `GlassesLink`, the session actor on top of any transport |

`focalsctl devices` lists paired Bluetooth devices; `focalsctl probe` connects, performs the
handshake and prints everything the glasses send.

**Verified:** the build, the 27 tests, and `focalsctl devices` against real Bluetooth
hardware. **Not verified:** anything involving actual glasses. `focalsctl probe` has never
run, and every protocol claim in [`docs/PROTOCOL.md`](docs/PROTOCOL.md) is unconfirmed
against hardware. See [`docs/TESTING.md`](docs/TESTING.md).

### What is settled

- **The Android transport is classic Bluetooth RFCOMM (SPP)**, which iOS does not expose to
  third-party apps directly. iOS reaches the same classic-Bluetooth link only through
  ExternalAccessory — which, per the finding above, is what North's own app did.
- **Notification mirroring works, and needs no code from us.** The glasses' own Bluetooth
  schema carries ANCS state, so the firmware is an ANCS client: paired to an iPhone, it
  receives notifications straight from iOS over BLE, with ANCS's reduced action set. This
  was the feature expected to be impossible; it is the one that comes free.
- **The dead cloud is replaceable.** The glasses ask for a cloud host and the companion
  answers in its place, terminating TLS in memory — no iOS trust-store problem, because no
  system proxy is involved. The upstream certificate expired in January 2023, so a port
  needs its own domain and certificate.

What would survive: connecting and reconnecting, battery and Loop state, Loop pairing,
calibration, the tunnelled network proxy and the mocked cloud behind it (notes, tasks,
weather, teleprompter, live subtitles with on-device speech), file transfer, location,
Apple Music control. What does not: reading other apps' notifications *through our app*
(unnecessary — see above), generic media control, screen-region mirroring, and anything
that must survive a force-quit.

Nothing here has been tested against hardware, because there is none on hand.

## Relationship to the Android app

This is a **clean-room reimplementation for iOS**, not a fork and not a translation.
No upstream source is vendored here; the upstream repository is used as protocol
documentation only. See [`docs/UPSTREAM.md`](docs/UPSTREAM.md).

## Documentation

| Document | What it holds |
| --- | --- |
| [`docs/IOS-MIGRATION.md`](docs/IOS-MIGRATION.md) | Feasibility analysis, feature-by-feature verdicts, proposed architecture, phased plan |
| [`docs/UPSTREAM.md`](docs/UPSTREAM.md) | How the upstream Android project is used, and the boundary we keep |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Priorities and the decision register |
| [`docs/WORKLOG.md`](docs/WORKLOG.md) | Session-by-session record of the work |

## Hardware

Development needs real Focals hardware. They were sold only in 2019–2020 and were
never shipped outside North America, which makes the hardware itself a gating
constraint on this project rather than a detail.

## Licence

[MIT](LICENSE). The licence covers the work in this repository, which is ours; it says
nothing about the upstream Android project, whose code is not here. See
[`docs/UPSTREAM.md`](docs/UPSTREAM.md).
