# Roadmap

Priorities first, then the decision register. Every decision, idea and "for later"
discussed about this project is written here in the session it came up, including the
decisions to *not* do something.

## Now

**Phase 0, and nothing else.** The plan's verdict (`docs/IOS-MIGRATION.md`) is that a
faithful port is not viable and a reduced sideload-only port is conditional on one
experiment. That experiment is the entire near-term roadmap:

1. **Acquire Focals hardware.** Blocking everything below.
2. **Determine whether the glasses are an MFi (iAP2) accessory.** The Android code
   declares an unused `00000000-DECA-FADE-DECA-DEAFDECACAFF` constant, which matches the
   known iAP2-over-Bluetooth service UUID pattern, and a string elsewhere mentions
   "on iPhone". If Focals are MFi, `ExternalAccessory` can likely carry the same byte
   stream once the protocol string is known. If they are not, an iPhone cannot talk to
   these glasses at all and the project is over.
3. **Exchange one protocol message from an iPhone** — the handshake and its response.
   Two to four days of work once there is hardware. Everything past this point is
   wasted effort until it passes.
4. **Check whether the firmware is an ANCS client.** Minutes of work on hardware, and it
   decides whether notification mirroring exists in any form on iOS.

Do not build UI, do not write feature code, do not set up App Store anything before 3
passes.

## Blocked on hardware

Everything that touches the glasses. Focals were sold only in 2019–2020 and only in
North America; acquiring a used pair is a prerequisite, not a detail. Until then the
work that can proceed is analysis, protocol documentation and the parts of the app
that do not need a device.

## Open decisions

- **A domain and certificate for the mocked cloud.** The glasses ask for a cloud host and
  the app answers in its place, terminating TLS in memory. The upstream certificate for
  `cloud.ofocals.com` expired on 2023-01-03 and is not ours to renew, so a port needs its
  own domain, a certificate the 2019 firmware still accepts, and something that renews it.
  Which domain, and whether 2019-era firmware accepts a modern certificate chain at all,
  is open and is a hardware question.
- **Whether to pursue this at all if Phase 0 fails.** If the glasses are not MFi, the only
  remaining design is a bridge device relaying Bluetooth for the iPhone — and carrying the
  bridge means carrying an Android phone, which defeats the purpose. The plan calls that a
  no-go; the alternative worth considering in that case is contributing to the Android app
  instead.

## Decision register

### 2026-11-17 — Verdict: no faithful port; Phase 0 gates everything

**Decided (analysis).** A faithful iOS port of the Android companion app is not viable,
and App Store distribution is unavailable under every outcome. A reduced, sideload-only
companion is a conditional go, gated on a two-to-four-day experiment with physical
glasses. Full reasoning and the feature-by-feature table are in `docs/IOS-MIGRATION.md`.

**Why.** The glasses speak classic Bluetooth RFCOMM on the Serial Port Profile UUID, and
iOS exposes no RFCOMM API to third-party apps — the only classic-Bluetooth data path is
`ExternalAccessory`, restricted to MFi accessories, whose manufacturer controls which apps
may connect. North is defunct, so even success there cannot pass App Store review. There
is no BLE data path and no IP link to fall back on: BLE appears in the Android code only to
find a device whose name contains "Focals". Separately, Android's notification listener has
no iOS counterpart, which removes the feature most owners would ask for first.

**Next step.** Phase 0 as written under "Now". Nothing else.

**Also recorded from the analysis**, because these contradict the upstream documentation
and would otherwise be rediscovered later: the upstream README claims keys were stripped
and they were not (see `docs/UPSTREAM.md`); the intercepting "proxy" is not a network
server at all but TLS terminated in memory over a Bluetooth-tunnelled socket, which is why
the iOS trust store and ATS do not apply; several upstream features are fixtures rather
than implementations (hardcoded location, one fixed weather payload, seeded notes and
tasks, an update service that only logs); and `glasses_apps/` is confirmed out of scope,
being Qt 5.9 cross-compiled for the glasses' own ARM OS.

### 2026-11-17 — MIT licence

**Decided.** The repository is MIT licensed, copyright Abraham Rubio.

**Why.** It is aimed at a community of people whose glasses stopped working, so the
licence should let them use, fork and ship the result without asking. A public
repository with no licence is all-rights-reserved by default, which would have been the
opposite of the point. The upstream Android project being unlicensed does not constrain
this choice, because none of its code is here — MIT covers our own work only.

**Next step.** None; `LICENSE` is in place and `README.md` and `docs/UPSTREAM.md` say
what it does and does not cover.

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
