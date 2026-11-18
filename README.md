# openfocals-ios

An iOS companion app for **North Focals** smart glasses.

North shut down in 2020 after Google acquired the company, and the cloud services the
glasses depend on went dark with it. [openfocals](https://github.com/aegray/openfocals)
by [aegray](https://github.com/aegray) brought the glasses back to life on Android: it
replaces North's companion app, and stands in for the dead cloud by answering the
glasses' own requests locally. There is no equivalent for iPhone owners.

This project is the attempt to build one.

## Status

**Analysis done, not started, and conditional on an experiment nobody has run yet.**
No application code exists.

The analysis is in [`docs/IOS-MIGRATION.md`](docs/IOS-MIGRATION.md) and its conclusion
is worth stating up front rather than burying:

> A faithful iOS port is not viable. A reduced, sideload-only port may be viable, and a
> two-to-four-day experiment with physical glasses decides it.

Three findings drive that:

- **The glasses speak classic Bluetooth RFCOMM** (Serial Port Profile). iOS gives
  third-party apps no RFCOMM API at all; the only classic-Bluetooth data path is
  ExternalAccessory, which works solely with MFi-certified accessories. There is no BLE
  data path and no Wi-Fi link to the phone anywhere in the protocol. Whether Focals are
  MFi accessories is the single question the whole project hangs on — there is suggestive
  evidence in the Android source, and it is unconfirmed.
- **App Store distribution is unavailable** under any outcome: an MFi accessory's
  manufacturer decides which apps may connect to it, and North is defunct.
- **Mirroring other apps' notifications cannot be ported.** iOS has no equivalent of
  Android's notification listener, so the feature most owners would want is the one
  least likely to exist.

What would survive: connecting, battery and Loop state, calibration, the tunnelled
network proxy and the mocked cloud behind it (notes, tasks, weather, teleprompter,
live subtitles), file transfer, location, Apple Music control.

Nothing here has been tested against real hardware, because there is none on hand.

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
