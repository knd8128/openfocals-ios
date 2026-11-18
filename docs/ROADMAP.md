# Roadmap

Priorities first, then the decision register. Every decision, idea and "for later"
discussed about this project is written here in the session it came up, including the
decisions to *not* do something.

## Now

The transport question is answered (`docs/IOS-MIGRATION.md` §12): North's iOS app used
**ExternalAccessory/iAP2**, so the glasses are an MFi accessory. The App Store is out; a
development-signed app is a real path. The gate is now **hardware**.

0. **Done 2026-11-18: the macOS side exists.** `FocalsKit` (`FocalsWire`, `FocalsProtocol`,
   `FocalsTransport`, `FocalsLink`) plus the `focalsctl` tool. Varints, framing, a
   schema-less protobuf codec, both message tables, the 4.40 handshake and the session
   actor, with 27 tests; the RFCOMM transport enumerates real paired Bluetooth devices.
   Nothing has touched glasses yet — `focalsctl probe` is written and unrun.

1. **Find out whether the Focals still exist.** Abraham owned a pair — `Focals - 00DW`,
   serial `1f47080e`, hardware v11, software 1.117.0-4559, last used 2020-06-01 — proven by
   the app container recovered from his iPhone backup. If that pair is in a drawer, the
   project is unblocked today and step 2 of the old plan disappears. If not, buying a used
   pair returns as the long-lead item (sold 2019–2020, North America only).
2. **Ask the glasses for their accessory protocol string.** A development build on any iPhone:
   bond the glasses, then `EAAccessoryManager.shared.connectedAccessories` and read
   `name`, `serialNumber`, `firmwareRevision` and `protocolStrings`. Half a day. It yields the
   string our `Info.plist` needs, and it converts §12's inference into proof — if the glasses
   appear in that array, they are MFi, full stop.
3. **Run `focalsctl probe` against the glasses from this Mac.** The first real test of
   `docs/PROTOCOL.md`: pair the glasses in System Settings, then watch the handshake either
   come back with a software version or fail. Everything above the transport is already
   written, so this is minutes of work once they are paired, and it validates the framing,
   the varints and the message tables in one shot.
4. **Open an `EASession` and exchange one protocol message.** The handshake is
   `EstablishConnection{versionMajor: 4, versionMinor: 40}` (confirmed independently: the OTA
   metadata requires `minBlackCoralProtocolVersion 4.40`). This is the old step 4 and it is
   still the point past which nothing should be built.
5. **Stand up `pycompanion` against the glasses** from a Linux box or a Raspberry Pi — the
   author's working Python companion, cheaper than Swift for learning the protocol.

Obsolete: getting North's IPA. It was only ever a way to learn the protocol string without
hardware, and §11 showed it is not publicly archived, not on Abraham's current Apple ID, and
not re-acquirable (the app is withdrawn from sale, so Apple grants no new licence). Keep it as
a fallback if hardware never materialises and someone who still owns a copy turns up.

Do not build UI and do not write feature code before 3 passes.

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

### 2026-11-18 — Build macOS first, iOS after it is stable against hardware

**Decided (Abraham's call):** write the protocol stack and a macOS tool first, and only
build the iOS companion once that is stable. **Why:** macOS reaches the glasses over RFCOMM
with no MFi, no protocol string and no provisioning, so the protocol can be learned and the
whole stack debugged without fighting Apple; and because the transport is one protocol
(`ByteTransport`), none of that work is thrown away when iOS arrives — only
`EATransport` is added beside `RFCOMMTransport`. **Status:** done for the first slice; see
item 0 of *Now*. **Also decided:** no code from upstream or from the extracted schemas is
copied — field numbers and framing are facts, written out as our own Swift tables, and
`docs/PROTOCOL.md` states them in our own words.

**Also decided:** no `swift-protobuf` dependency for now. The schema is large, only partly
known, and the decoder works without one — an unrecognised field still reads as a number and
a value, so new firmware cannot break it. Revisit when typed readers for the bigger messages
(sync, settings, file transfer) start costing more than a dependency would.



### 2026-11-18 — The transport is settled: ExternalAccessory/iAP2, found on Abraham's own Mac

**Decided:** treat H1 as established and stop hunting the IPA; make hardware the gate.
**Why:** a Spotlight sweep of the whole Mac turned up `~/Downloads/focals`, the data container
of `com.bynorth.companion` extracted from an iPhone backup in May 2025. It stores the companion
link as accessory name + serial and the ANCS link as a Core Bluetooth peripheral UUID — the
persistence shapes of `EAAccessory` and `CBPeripheral`. **Consequences:** the App Store is out
permanently; `EASession` is a supported path for a development-signed build; the planned
`FocalsTransport`/`EATransport` split was right. **Next step:** find out whether his pair of
Focals still exists, then read `protocolStrings` off them. **Status:** agreed. Full write-up in
`docs/IOS-MIGRATION.md` §12.

**Also decided:** keep the recovered container at `reference/ios-app-container/` (gitignored)
rather than in `~/Downloads`, where it would eventually be cleaned out, and never commit any of
it — it holds an expired `id.bynorth.com` JWT with his name and email, a Firebase token and his
notification allow-list. Rule added to `CLAUDE.md`.

**Also recorded:** `~/Documents/projects/xcode/BLELab` is an earlier attempt of his own
(September 2025) that tried Core Bluetooth, documented in its own comments that classic
Bluetooth has no iOS API, and never tried ExternalAccessory. Not vendored, not a starting
point; noted so a future session does not rediscover it. **Status:** closed.



### 2026-11-18 — The IPA is not on Abraham's current Apple ID; one older account left to try

**Decided:** keep the IPA as step 1 of *Now*, but split it into a free local attempt (another
Apple ID of his) before any outward-facing request. **Why:** `ipatool` authenticated fine but
the account `rza8128@hotmail.com` holds no Focals licence across all 961 of its purchases, and
Apple will not grant a new one for an app withdrawn from sale, so the remaining local lever is
the Apple ID that was signed in when the app was first installed. **Next step:** `auth revoke`,
log in with that account, retry. **Status:** agreed. Evidence in `docs/IOS-MIGRATION.md` §11.5.

**Also decided:** do not look for iAP2 evidence in `focals_utils` again. A full search for
`iap2`/`externalaccessory`/`mfi`/`com.apple` returns zero, including the glasses-side Qt apps;
it is weak evidence for H2 and the well is dry.


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
