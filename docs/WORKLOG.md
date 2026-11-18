# Worklog

Newest entry first.

## 2026-11-18 — The transport question answered, and the macOS stack built

**Done.**

Abraham: *"busca el ipa de la app oficial de iOS"* → *"hay alguna forma de bajarla de mi
cuenta, o dime el bundleid"* → *"busca en todos lados de la mac"* → *"dale, empieza con el
lado de macOS y ya que sea estable hacemos el companion app de ios"*.

1. **The App Store route, exhausted.** `ipatool` 2.8.0 authenticated against
   `rza8128@hotmail.com` (the login needs a real terminal; the session shell has no TTY).
   All 961 purchases of that account listed across 10 pages: no Focals, no North.
   `download -i 1438872705` → `license is required`; `download --purchase` → Apple refuses
   (`param 'STDQ'`), because an app withdrawn from sale cannot be newly acquired by anyone.
   No iPhone reachable over USB either. Commit `bc5cce8`.
2. **The FCC-photo route, closed.** The glasses' internal photographs were checked for
   Apple's MFi authentication coprocessor: 1155×866 at 220 ppi, large packages partly
   legible (an SK hynix die reads), small ICs not. Absence proves nothing; recorded as a
   dead end so no future session repeats it. Commit `32c3b60`.
3. **The answer, found on his own Mac.** A Spotlight sweep turned up `~/Downloads/focals`:
   the **data container of `com.bynorth.companion`**, North's iOS app, extracted from an
   iPhone backup in May 2025. It stores the companion link as **accessory name + serial
   number** (`Focals - 00DW` / `1f47080e`) and the ANCS link as a **Core Bluetooth
   peripheral UUID** — the persistence shapes of `EAAccessory` and `CBPeripheral`
   respectively, since a CB client must keep the UUID to reconnect and an EA client has no
   UUID at all. **H1 holds, H2 is dead: the glasses are an MFi accessory and the iOS app
   spoke iAP2.** Written up as `IOS-MIGRATION.md` §12; commit `f34821b`.
   - Also recovered: Abraham **owned a pair** (hardware v11, software 1.117.0-4559, last
     active 2020-06-01), and the signed **OTA package for firmware 1.119.0-4672** — an
     Android delta OTA for `qcom/msm8909w:7.1.1`, so the glasses are Android 7.1.1 on a
     Snapdragon Wear 2100, with components `companion_service`, `bt_server`, `auth_service`,
     `black_coral_simulator`. Its `minBlackCoralProtocolVersion: 4.40` confirms **BC =
     BlackCoral** and ties the 4.40 handshake to that protocol's own version.
   - The container was copied to `reference/ios-app-container/` (gitignored) so a Downloads
     cleanup cannot take it.
4. **The macOS stack.** `FocalsKit` — `FocalsWire` (LEB128 varints, streaming `FrameReader`,
   `WireMessage`, schema-less protobuf reader/writer), `FocalsProtocol` (both message tables,
   the 4.40 handshake, `IncomingMessage`), `FocalsTransport` (`ByteTransport`,
   `LoopbackTransport`, `RFCOMMTransport` on IOBluetooth), `FocalsLink` (the `GlassesLink`
   actor) — plus the `focalsctl` tool. Commit `d077b01`.

**Verified for real:** `swift build` clean, **27 tests pass** (`swift test`), and
`focalsctl devices` enumerated the 13 genuine paired Bluetooth devices on this Mac.
**Not verified:** no byte has been exchanged with actual glasses. `focalsctl probe` is
written and has never run. Every protocol claim in `docs/PROTOCOL.md` is unverified against
hardware and says so.

One real bug found and fixed: the handshake raced its timeout inside a task group, and
because a `CheckedContinuation` cannot be cancelled the group never finished and the suite
hung. Replaced with an explicit state machine, which also closed two latent races — the
reply arriving before the caller parked, and the transport dropping while it waited.

**Decided.**

- **Claude: `ADR-0001` — one `ByteTransport` protocol, macOS RFCOMM first, iOS later.**
  Abraham's call to do macOS first; the abstraction is what makes it cost nothing.
- **Claude: `ADR-0002` — no `swift-protobuf`; decode structurally against field-number
  tables.** The schema is large and only partly known; an unknown field must still decode.
- **`ADR-0003` — distribution is development-signed only, never the App Store.** Follows
  from the H1 finding; it is a product decision, not a temporary limitation.
- **Claude: stop hunting the IPA.** It was only ever a way to learn the accessory protocol
  string without hardware. The glasses can be asked directly
  (`EAAccessoryManager` → `protocolStrings`), so the gate is hardware now.
- **Claude: nothing from `reference/ios-app-container/` is ever committed**, and a rule to
  that effect was added to `CLAUDE.md`. It holds an expired `id.bynorth.com` JWT with his
  name and email, a Firebase token and his notification allow-list.
- **Claude: no upstream code and no copied schema.** Field numbers and framing are facts,
  written out as our own Swift tables; `docs/PROTOCOL.md` states them in our own words.

**Pending.**

- Pair the glasses and run `swift run focalsctl probe`. First real test of `PROTOCOL.md`.
- Typed readers for the larger messages, starting with the network tunnel (`socketOpen`,
  `socketDataChunk`, `getHostByName`). Can be built against `LoopbackTransport` with no
  hardware.
- The iOS target, after the macOS side is stable against hardware — `EATransport` beside
  `RFCOMMTransport`, plus the accessory protocol string in `Info.plist`.

**Blocked.**

- Everything that needs the glasses to power on. They are a 2020 lithium cell that has sat
  discharged for years and may not revive; that is unknown until Abraham charges them.
- The accessory protocol string, if the glasses never power on: the only other sources are
  North's IPA (unobtainable, see above) or a shell on the glasses' Android system.

**Notes.**

- No changes were made outside this repository. Nothing was created, bought, sent or
  published to any external service this session.
- `~/Documents/projects/xcode/BLELab` is an earlier attempt of his own (September 2025) that
  tried Core Bluetooth, documented in its own comments that classic Bluetooth has no iOS
  API, and never tried `ExternalAccessory`. Not vendored; recorded so it is not rediscovered.
- `focalsctl devices` also showed a pair of **Even G1** smart glasses paired to this Mac.
  Unrelated to this project, noted only because it came out of the same run.

## 2026-11-17 — Project created; Android implementation analysed for an iOS port

**Done.**

- Cloned the upstream Android project, `aegray/openfocals`, to `../openfocals` as a
  read-only reference (~12k LOC: a Java companion app plus Qt/QML applications that run
  on the glasses themselves).
- Analysed that implementation end to end and wrote the migration plan to
  `docs/IOS-MIGRATION.md`: what the app actually does, the transport and protocol, a
  feature-by-feature feasibility table against iOS, a proposed Swift architecture, a
  phased plan starting from a proof-of-life spike, the open questions that need
  hardware, and a go/no-go recommendation.
- Created this repository as a separate clean-room project on `knd8128`, public, with
  the canonical docs and an explicit upstream boundary (`docs/UPSTREAM.md`): no upstream
  source is vendored, because the upstream carries no licence.

**Not done / unverified.**

- No application code exists yet, and **nothing has been verified against real
  hardware** — there are no Focals glasses on hand. Every claim in the migration plan
  about how the glasses behave is derived from reading the Android source, not from
  observing a device.

- MIT licence added (Abraham's call), covering our work only.

**What the analysis concluded.** A faithful port is not viable; a reduced sideload-only
port is conditional on one short experiment with hardware. The transport is classic
Bluetooth RFCOMM (SPP), which iOS does not expose to third-party apps, so the project
hangs on whether Focals are an MFi accessory — suggestive but unconfirmed evidence in the
Android source says maybe. Notification mirroring cannot be ported. App Store
distribution is unavailable regardless.

**Worth flagging.** The upstream README says the private keys and certificates were
stripped before publishing; they were not — two RSA private keys and their certificates
are still embedded in its source, both expired. Nothing was copied from them, and
`docs/UPSTREAM.md` now warns future sessions off them.

**Then the verdict improved twice.** Published sources confirmed North shipped an official
**iOS** app, and reviewers' description of iPhone notifications (mark-as-read only, versus
full triage on Android) matched the ANCS action shape exactly — written up as section 9 of
the plan. Then a second repository by the same author, `aegray/focals_utils`, settled it:
the glasses' own Bluetooth schema carries `AncsDeviceStatus`, so the firmware **is** an ANCS
client and notification mirroring needs no code from us. That repo also proved the firmware
acts as a BLE central/GATT client, yielded the FCC test report (dual-mode radio: classic
BR/EDR *and* BLE), and showed from a captured SDP record that the UUID which suggested iAP2
is really the Focals SPP service's own class — a false lead, now recorded as such. Written
up as section 10.

**Where that leaves it.** The gate is unchanged, the odds behind it are better, and the
decisive step got cheaper: whether this can ever be an App Store app or only a sideloaded
one depends on whether North's iOS app used iAP2 (MFi) or a custom BLE GATT service, and an
archived copy of that app's `Info.plist` answers it **without hardware**. That is now step
one, ahead of buying glasses.

**Next.** Find the archived IPA. See `docs/ROADMAP.md`.
