# openfocals-ios

An iOS companion app for **North Focals** smart glasses.

North shut down in 2020 after Google acquired the company, and the cloud services the
glasses depend on went dark with it. [openfocals](https://github.com/aegray/openfocals)
by [aegray](https://github.com/aegray) brought the glasses back to life on Android: it
replaces North's companion app, and stands in for the dead cloud by answering the
glasses' own requests locally. There is no equivalent for iPhone owners.

This project is the attempt to build one.

## Status

**Analysis done, not started, and hanging on one artifact nobody has found yet.** No
application code exists.

The analysis is in [`docs/IOS-MIGRATION.md`](docs/IOS-MIGRATION.md). It began as a mostly
negative verdict and improved as evidence came in; the honest current reading:

> A faithful port of the Android app is not viable. A reduced iOS companion probably is.
> Whether it could ever reach the App Store, or only ever be sideloaded, depends on a
> question that one file would answer.

### The question everything hangs on

North shipped an **official iOS app** for Focals (setup, settings, alignment, notification
selection; iPhone 5S and newer, pulled from the App Store in July 2020). So an
iPhone-to-glasses channel existed and worked. Two candidate explanations, and they have
opposite consequences:

| | How the iOS app talked to the glasses | Consequence |
| --- | --- | --- |
| **H1** | iAP2 over ExternalAccessory | The glasses are an MFi accessory. Our app can likely open the same session, but **sideload only** — an MFi accessory's manufacturer decides which apps may connect, and North is defunct |
| **H2** | A custom BLE GATT service | **No MFi involved.** Core Bluetooth is enough, and App Store distribution is back on the table |

The deciding artifact is an archived copy of North's iOS app: if its `Info.plist` declares
`UISupportedExternalAccessoryProtocols`, it is H1; if not, H2. That is the cheapest, highest
-value step in this project — **it needs no glasses** — and it is ahead of buying hardware.

Evidence for H2 is now the stronger side: the glasses are a confirmed dual-mode radio
(classic BR/EDR *and* BLE, per their FCC test report), their firmware demonstrably acts as a
BLE central/GATT client, and the captured Bluetooth service record shows the Android
companion channel is plain Serial Port Profile with **no iAP2 service advertised** — the
custom UUID that first suggested iAP2 turns out to be the Focals SPP service's own class.

### What is settled

- **The Android transport is classic Bluetooth RFCOMM (SPP)**, which iOS does not expose to
  third-party apps at all. If H1 and H2 both fail, an iPhone cannot talk to these glasses
  without carrying a bridge device, and that is a no-go.
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
