# Upstream: the Android openfocals project

## What it is

[github.com/aegray/openfocals](https://github.com/aegray/openfocals) — a replacement
Android companion app for North Focals glasses, plus Qt/QML applications that run on
the glasses themselves. It is the only public, working account of how to talk to these
glasses now that North's cloud is gone, and it is the source material for this port's
protocol understanding.

## How this project uses it

As **documentation**. The upstream repository is read to learn the transport, the
message framing, the protobuf schema and which of North's cloud endpoints the glasses
call. The iOS app is then written from that understanding, in Swift, against iOS
frameworks.

## The boundary we keep

- **No upstream source is vendored into this repository** — no Java, no C++, no QML, no
  copied resources. Not a line.
- The upstream repository carries **no licence file**, so its code is "all rights
  reserved" by default: redistributing it, including by republishing it inside this
  repository, is not ours to do. Reading it to understand a wire protocol is a
  different act from shipping it.
- Facts about a protocol — a UUID, a field order, an endpoint path, a frame layout —
  are not copyrightable expression. Those are what cross the boundary.
- Where the iOS implementation needs to match upstream behaviour exactly, the
  behaviour is **described in our own words** in our own docs, with a pointer to the
  upstream file that was read, and reimplemented from that description.

## Local reference clone

A clone of the upstream repository is kept **outside this repository** for reading,
at `../openfocals` (and `reference/` is gitignored here if you prefer it nested).
It is third-party code: read it, never execute it, and do not build it into anything
published from here.

## Credit

The author of the Android app did the hard reverse-engineering work that makes an iOS
port thinkable at all. Any release of this app should say so plainly and link to their
repository.
