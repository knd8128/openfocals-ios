# Roadmap

Priorities first, then the decision register. Every decision, idea and "for later"
discussed about this project is written here in the session it came up, including the
decisions to *not* do something.

## Now

1. **Read the migration plan and accept or reject its verdict.** `docs/IOS-MIGRATION.md`
   ends in a go/no-go recommendation. Nothing else in this roadmap matters until that
   call is made, because the blockers it names decide whether a faithful port exists.
2. **The proof-of-life spike**, if the verdict allows one: establish a connection to
   real glasses from an iOS device and exchange a single protocol message. This is the
   one experiment that retires the project's central risk, and it needs hardware.

## Blocked on hardware

Everything that touches the glasses. Focals were sold only in 2019–2020 and only in
North America; acquiring a used pair is a prerequisite, not a detail. Until then the
work that can proceed is analysis, protocol documentation and the parts of the app
that do not need a device.

## Open decisions

- **Licence.** The repository is public but carries no licence yet, which means "all
  rights reserved" and makes it unfriendly to the community it is aimed at. A
  permissive licence (MIT) is the obvious default for a community project; it is left
  open deliberately because the upstream Android project is itself unlicensed, and
  Abraham should make the call rather than inherit one. Decide before any code ships.
- **Distribution.** Several of the capabilities this app would need are ones Apple does
  not grant to App Store apps. Whether this ever becomes a store app, a TestFlight
  build, or something a developer sideloads with their own signing, follows from the
  migration plan's verdicts and is not yet decided.

## Decision register

### 2026-11-17 — Project created as a separate, clean-room repository

**Decided.** The iOS port lives in its own public repository on `knd8128`
(`openfocals-ios`), not as a fork of `aegray/openfocals` and not as a directory inside
a clone of it.

**Why.** The upstream repository ships no licence file, so its code is all-rights-reserved
by default; republishing it under a different account is not ours to do, and a public
repository makes that a real act rather than a technicality. Reading it to learn a wire
protocol is a separate and legitimate act. Keeping the two apart also keeps the iOS
repository honest about what it actually contains: our own work.

**Next step.** Keep the upstream clone outside this repository (`../openfocals`) and
record protocol findings in our own words. See `docs/UPSTREAM.md`.

### 2026-11-17 — Analysis before architecture

**Decided.** Before any Swift is written, the Android implementation is analysed in full
and the result committed as `docs/IOS-MIGRATION.md`, including an explicit go/no-go
verdict and a feature-by-feature feasibility table.

**Why.** The difficulty of this port is not the UI, it is that iOS withholds platform
capabilities the Android app is built on — reading other apps' notifications, classic
Bluetooth to a non-MFi accessory, a system-wide intercepting proxy with a custom CA,
unrestricted background execution. Writing an app first and discovering the blockers
later would waste the work. A plan that concludes "not viable as a faithful port, here
is the largest viable subset" is a successful outcome of this step.

**Next step.** Act on the verdict in the plan.
