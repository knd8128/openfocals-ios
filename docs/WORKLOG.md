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
- The licence for this repository is undecided (see `docs/ROADMAP.md`).

**Next.** Read the plan's verdict and decide whether to pursue the port, and in what
scope.
