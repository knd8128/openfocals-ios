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

**Next.** Phase 0 only: acquire hardware, determine whether the glasses are MFi, and
exchange one protocol message from an iPhone. See `docs/ROADMAP.md`.
