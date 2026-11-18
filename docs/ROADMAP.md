# Roadmap

Priorities first, then the decision register. Every decision, idea and "for later"
discussed about this project is written here in the session it came up, including the
decisions to *not* do something.

## Now

The plan's gate is unchanged but its order has: the decisive step no longer needs glasses.

1. **Find an archived copy of North's iOS app and read its `Info.plist`.** No hardware, and
   it answers the question the whole project hangs on: `UISupportedExternalAccessoryProtocols`
   present means iAP2/MFi and sideload-only; absent means a custom BLE GATT companion, Core
   Bluetooth, no MFi, and App Store distribution back on the table. The app was public until
   2020-07-31, so copies may survive in old iTunes libraries, device backups or IPA archives.
   The Android package was `co.glassio`, which is likely the iOS bundle-id prefix too.
   **Do this before spending money on hardware.**
2. **Acquire Focals hardware** — still needed for everything past the IPA, and the long-lead
   item (sold 2019–2020, North America only). Start looking in parallel with 1.
3. **Scan the glasses' BLE GATT services** with any BLE explorer. Minutes of work, and it
   tests H2 directly: a companion-grade service beyond the Loop- and ANCS-facing roles is
   what a custom-BLE port would use.
4. **Exchange one protocol message from an iPhone**, over whichever path 1 and 3 indicate.
   Two to four days once there is hardware. Nothing past this point is worth building first.
5. **Stand up `pycompanion` against the glasses** from a Linux box or a Raspberry Pi. It is
   the author's working Python companion and the glasses accept it in place of the phone app:
   cheaper than writing Swift to learn the protocol, and it validates our understanding of
   framing, handshake, settings and features before any app code exists.

Do not build UI and do not write feature code before 4 passes.

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

### 2026-11-17 — Evidence revised the verdict upward; the deciding artifact is an IPA, not hardware

**Decided (analysis).** Two later findings materially improved the outlook recorded in the
entry below, without changing the gate. Full reasoning in `docs/IOS-MIGRATION.md` sections 9
and 10.

**What changed.**

- **North shipped an official iOS app**, so an iPhone-to-glasses channel provably existed.
  That splits the transport question in two: iAP2/MFi (sideload only) versus a custom BLE
  GATT service (no MFi, App Store possible). The second is now the better-supported reading —
  the glasses are a confirmed dual-mode radio per their FCC test report, their firmware acts
  as a BLE central/GATT client, and the captured SDP record shows no iAP2 service advertised.
- **The custom UUID that suggested iAP2 was a false lead**: `00000000-DECA-FADE-DECA-DEAFDECACAFF`
  is the Focals SPP service's own service class, not the iAP2 service. Recorded so nobody
  rebuilds the MFi hypothesis on it.
- **Notification mirroring is not a blocker and needs no code from us.** The glasses' own
  Bluetooth schema carries ANCS state (`AncsDeviceStatus`, `AppAttributes{bundleId}`,
  `AppNotificationBlacklist`, `PerformNotificationAction`), so the firmware is an ANCS client
  and receives iPhone notifications directly over BLE once paired. The feature expected to be
  impossible is the one that comes free.
- **A second repository by the same author, `aegray/focals_utils`, is the better reference**:
  a working Python companion the glasses accept in place of the phone app, the Bluetooth
  schema extracted from five official app versions, a procedure for installing a private root
  CA on rooted glasses (which resolves the expired-certificate problem for that case), the
  connector-cable and firmware-access notes, and the FCC filings.

**Why it matters.** The decisive experiment is no longer "buy glasses and try to connect". It
is "find the old iOS app and read one plist", which costs nothing and reorders the roadmap.

**Next step.** Item 1 under "Now".

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
