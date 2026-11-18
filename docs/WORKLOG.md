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
