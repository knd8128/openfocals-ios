# Worklog

Newest entry first.

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

## 2026-11-18 — Tried to retrieve North's iOS companion app from Abraham's Apple ID

Goal: the one artifact that decides H1 vs H2 (iAP2/MFi vs custom BLE GATT), namely the
`Info.plist` of `id1438872705`.

- `ipatool` 2.8.0 authenticated against `rza8128@hotmail.com`. The login has to happen in a
  real terminal window — the session's inline shell provides no TTY and `auth login` dies with
  `failed to read password: failed to configure terminal`.
- Listed the account's purchases exhaustively: 961 unique bundle ids over 10 pages. No Focals,
  no North. `download -i 1438872705` → `license is required`. `download --purchase` → Apple's
  store request fails (`param 'STDQ'`): an app withdrawn from sale cannot be newly acquired.
- No iPhone reachable over USB (`idevice_id -l` empty), so reading the plist off a device with
  `ideviceinstaller` was not an option either; the app is offloaded on his phone anyway.
- Searched all of `focals_utils` for `iap2`/`externalaccessory`/`made for iphone`/`mfi`/
  `com.apple` (excluding `.git`, `glasses/rootcert/`, the FCC PDFs): zero matches, including
  the Qt apps that run on the glasses. Weak but H2-leaning.

Recorded as `docs/IOS-MIGRATION.md` §11.5 and a dated entry in `docs/ROADMAP.md`. Next lever is
the older Apple ID that was signed in when Focals was installed on his iPhone.

## 2026-11-18 (second entry) — The transport question is answered: ExternalAccessory/iAP2

The App Store route to North's IPA was exhausted (see the entry above), so the search widened
from Apple's servers to the machine itself. A Spotlight sweep for anything Focals-related
found `~/Downloads/focals`: the **data container of `com.bynorth.companion`**, North's own iOS
app, extracted from an iPhone backup in May 2025 and forgotten there.

What it settles, in one line: the app persisted the companion link as an **accessory name and
serial number** and the notification link as a **Core Bluetooth peripheral UUID** — the storage
shapes of `EAAccessory` and `CBPeripheral`. **H1 holds, H2 is dead.** The glasses are an MFi
accessory; the App Store is out for good; `EASession` is a supported transport for a
development-signed build, and the architecture's `ByteTransport` split survives untouched.

Also recovered from the same container:

- the bundle id `com.bynorth.companion`, app 1.114.1 (3377) on iOS 12.4, last active 2020-06-01;
- **Abraham owned a pair**: `Focals - 00DW`, serial `1f47080e`, hardware v11, software
  1.117.0-4559. Whether they still exist is now the project's gate;
- the signed **OTA package for firmware 1.119.0-4672** (8 MB): an Android delta OTA for
  `qcom/msm8909w:7.1.1`, so the glasses are Android 7.1.1 on a Snapdragon Wear 2100. Patched
  components include `companion_service`, `bt_server`, `auth_service`, `black_coral_simulator`;
- `minBlackCoralProtocolVersion: 4.40`, which confirms **BC = BlackCoral** and ties the
  `versionMajor=4, versionMinor=40` handshake to that protocol's own version number.

The container was copied to `reference/ios-app-container/` (gitignored) so it survives a
Downloads cleanup, and `CLAUDE.md` gained a rule that nothing from it is ever committed — it
holds an expired `id.bynorth.com` JWT with his name and email, a Firebase token and his
notification allow-list.

Written up as `docs/IOS-MIGRATION.md` §12, with a superseding banner on §0. `README.md`'s
status, the roadmap's *Now* and the decision register were rewritten to match. Also recorded:
`~/Documents/projects/xcode/BLELab`, an earlier Core Bluetooth attempt of his from September
2025 that never tried ExternalAccessory — a closed dead end, not vendored.
