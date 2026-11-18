# openfocals-ios — working notes for Claude

An iOS companion app for North Focals smart glasses. Read `docs/IOS-MIGRATION.md`
before touching anything: it holds the feasibility analysis and the go/no-go verdict,
and the whole shape of this project follows from it.

## Canonical docs

- `docs/IOS-MIGRATION.md` — the analysis and the plan. The source of truth for scope.
- `docs/UPSTREAM.md` — how the Android project is used and the boundary we keep.
- `docs/ROADMAP.md` — priorities and the decision register. Every decision lands here.
- `docs/WORKLOG.md` — one entry per session.
- `docs/adr/` — architecture decision records.

## Hard rules

- **Never vendor upstream code.** No Java, C++, QML or resources from
  `aegray/openfocals` enter this repository. It carries no licence; protocol facts
  cross the boundary, expression does not. See `docs/UPSTREAM.md`.
- **This is a personal project**: the GitHub remote is `knd8128`, never `arubio-z`.
  Check `git remote -v` before any push.
- **`reference/` never gets committed, and `reference/ios-app-container/` least of all.**
  It is the real data container of North's iOS app recovered from Abraham's iPhone backup —
  the evidence behind `docs/IOS-MIGRATION.md` §12 — and it contains an `id.bynorth.com` JWT
  with his name and email, a Firebase token and his notification allow-list. Quote findings
  from it; never copy its files, its tokens or that allow-list into the repo.
- **Public repository.** Nothing secret is committed: no certificates, no private keys,
  no API keys, no keystores. `Secrets.xcconfig` and `*.p8`/`*.p12`/`*.cer` are
  gitignored — keep it that way, and never work around it.
- **English in the codebase** — code, identifiers, comments, docs, commit messages.
  Only user-facing product strings follow the product's language.
- **Do not claim a feature works until it has been verified against real hardware**,
  or state plainly that it has not been. Much of this project is unverifiable without
  Focals glasses in hand; say which parts, rather than implying a working app.

## Simulators

Use the two fixed simulators (`iPhone 17 (26.2)` for normal work). Note that **nothing
about the glasses connection can be tested in a simulator** — Bluetooth and the
accessory frameworks need a real device.

## State

No application code yet. See `docs/ROADMAP.md` for what is next.
