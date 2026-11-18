# openfocals-ios

An iOS companion app for **North Focals** smart glasses.

North shut down in 2020 after Google acquired the company, and the cloud services the
glasses depend on went dark with it. [openfocals](https://github.com/aegray/openfocals)
by [aegray](https://github.com/aegray) brought the glasses back to life on Android: it
replaces North's companion app, and stands in for the dead cloud by answering the
glasses' own requests locally. There is no equivalent for iPhone owners.

This project is the attempt to build one.

## Status

**Planning.** No application code yet. The feasibility analysis of the Android
implementation, and the migration plan derived from it, live in
[`docs/IOS-MIGRATION.md`](docs/IOS-MIGRATION.md) — read that first, including its
go/no-go verdict and the blockers behind it. iOS withholds several platform
capabilities the Android app relies on, so the plan is explicit about which features
port, which degrade, and which cannot exist on iOS at all.

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
