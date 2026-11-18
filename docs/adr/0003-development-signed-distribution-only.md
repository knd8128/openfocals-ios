# ADR-0003: This app is distributed development-signed, never through the App Store

- **Status:** accepted
- **Date:** 2026-11-18
- **Decided by:** Abraham (owns the consequence), Claude (established the finding)

## Context

North's own iOS companion talked to the glasses through `ExternalAccessory`, which means the
glasses are an MFi accessory and iAP2 is the only route from an iPhone to them. The evidence
is in [`IOS-MIGRATION.md`](../IOS-MIGRATION.md) §12: the recovered app container persists the
companion link as an accessory name and serial number, and the notification link as a Core
Bluetooth peripheral UUID.

Using `ExternalAccessory` requires declaring the accessory's protocol string in
`Info.plist`. App Store review requires the developer to be authorised for that string by
the accessory's manufacturer. North Inc. was acquired by Google in 2020 and no longer
exists, so that authorisation cannot be obtained by anyone, ever.

## Decision

The iOS app is built and signed for development and installed on devices its owner
controls. It is never submitted to the App Store, and no work is planned, costed or designed
around the possibility that it might be.

## Consequences

- **Nothing in this project optimises for review.** No App Store metadata, no privacy
  nutrition labels, no screenshots, no pricing, no IAP, no review-driven UX compromises.
- Builds expire. A paid Apple Developer account signs for a year; a free one for seven days.
  Whoever runs it re-signs on that cadence. TestFlight is equally unavailable, since external
  testing is reviewed.
- The audience is whoever still owns a pair of Focals and can build from source. That is the
  honest size of this project and the README says so.
- **This is not a limitation waiting to be lifted.** It follows from a defunct company, so
  it does not expire, and a future session should not re-open it.
- macOS is unaffected: IOBluetooth needs no MFi, and a Mac build could ship by any route.

## Alternatives considered

- **Find a BLE GATT path that avoids MFi.** This was hypothesis H2 and it is dead; §12
  explains why.
- **Wait for the EU's accessory rules (iOS 26.5 `AccessoryNotifications`).** Rejected as a
  distribution strategy: it addresses notification access, not accessory protocol
  authorisation, and it would not make a companion app shippable.
