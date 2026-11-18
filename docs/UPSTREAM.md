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

## Two cautions about reading it

**It contains live private keys, despite saying it does not.** The upstream README states
that the author stripped the certificates and private keys before publishing. They are
still in the source: two RSA private keys and their certificates are embedded in
`commutils/ssl/SSLInterceptDataHandler.java`, used to terminate TLS for the intercepted
cloud. Both are expired. Do not copy them anywhere, do not reuse them, and do not let them
reach this repository or any build published from it — a port needs its own domain and its
own certificate regardless, so there is nothing to gain by touching theirs.

**Its certificate expiry has probably already broken the Android app.** The embedded leaf
for `cloud.ofocals.com` expired on 2023-01-03, which means the cloud-mocking features it
documents may no longer work upstream either. Treat behaviour described in its docs as a
record of how things worked, not of how they work.

## Local reference clone

A clone of the upstream repository is kept **outside this repository** for reading,
at `../openfocals` (and `reference/` is gitignored here if you prefer it nested).
It is third-party code: read it, never execute it, and do not build it into anything
published from here.

## Credit

The author of the Android app did the hard reverse-engineering work that makes an iOS
port thinkable at all. Any release of this app should say so plainly and link to their
repository.
