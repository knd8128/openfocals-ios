# openfocals on iOS: migration plan

Status: analysis only, written 2026-11-17 from a read of the code at commit `4f25041`
(last upstream commit 2023-05-27). No hardware was available; nothing here was run against
real glasses. Everything marked **ASSUMPTION** is inferred and unverified.

## 0. Verdict first

**A faithful iOS port is not viable. A reduced, sideload-only port may be viable, and one
two-to-four-day experiment with physical glasses decides it. Do not commit to anything past
Phase 0 until that experiment passes.**

Why, in order of severity:

1. **Transport.** The Android app talks to the glasses over classic Bluetooth RFCOMM using
   the Serial Port Profile UUID (`focals/Device.java:97`, `:281`). iOS gives third-party apps
   no RFCOMM/SPP API. The only classic-Bluetooth data path on iOS is ExternalAccessory, which
   works only with MFi (iAP2) accessories. There is no BLE GATT data path and no Wi-Fi/TCP
   path anywhere in this codebase: the glasses have no IP link to the phone at all.
   - The one opening: `Device.java:98` declares an unused constant
     `00000000-DECA-FADE-DECA-DEAFDECACAFF`, labelled "debug". That value is the publicly
     known iAP2-over-Bluetooth service UUID pattern (the Apple-device side ends in `…CAFE`),
     and a feature string in `CloudMockService.java:271` mentions "on iPhone". **ASSUMPTION:**
     the glasses were MFi-certified and North's own iOS app used ExternalAccessory. If so, a
     development-signed iOS app can open the same session once the protocol string is known.
     If not, an iPhone cannot talk to these glasses without a bridge device.
2. **Distribution.** Even if (1) works, Apple's documentation states that the accessory
   manufacturer decides which apps may talk to its MFi accessory. North is defunct. Treat
   App Store distribution as unavailable; this is a personal/sideloaded app at best.
3. **Notification mirroring**, the feature most users would expect, has no iOS equivalent
   of `NotificationListenerService`. It is recoverable only if the glasses firmware itself
   implements Apple's ANCS (unknown), or in the EU on iOS 26.5+ via AccessoryNotifications.
4. **The cloud-intercept TLS certificate is expired and is not ours to renew.** The embedded
   leaf for `cloud.ofocals.com` expired 2023-01-03. This is not an iOS problem; it has
   probably already broken the cloud features on Android. Any port needs its own domain,
   its own publicly trusted certificate, and a renewal pipeline.

Largest viable subset if Phase 0 passes: connect/reconnect, battery and Loop state, Loop
pairing, display calibration, feature toggles, the tunnelled network proxy, the mocked cloud
(notes, tasks, weather with real data, teleprompter/streaming text, live subtitles with
on-device speech), file transfer for icons, real location, Apple Music control. Dropped or
degraded: mirroring other apps' notifications, generic media control and volume, screen-region
overlay, anything that must survive a force-quit, App Store distribution.

If Phase 0 fails, the only working design is a bridge (section 2.4), and at that point
carrying the bridge is carrying an Android phone. That is a no-go.

## 1. What the app actually does

### 1.1 Corrections to the README and to common assumptions

| Claim | What the code says |
| --- | --- |
| "I've taken out ... ssl certificates and private keys" (`README.md:51-53`) | Not true for this tree. `commutils/ssl/SSLInterceptDataHandler.java:19-69` embeds a self-signed-CA leaf and its RSA private key; `:80-185` embeds the ZeroSSL chain for `cloud.ofocals.com` and its RSA private key, under a comment saying it "is left out of the repo" (`:159`). Both leaves are expired (2022-10-20 and 2023-01-03, decoded with `openssl x509`). Only the Amazon API key (`res/values/keys.xml:2`, placeholder) and the keystore (`app/build.gradle:10`) are actually absent. |
| The app runs an HTTP/SSL proxy server | It opens no listening socket. The glasses send `SocketOpen`/`SocketData` protobuf messages over Bluetooth and the phone is their only network stack. "Interception" is an in-memory session object fed with bytes from the Bluetooth link; TLS is terminated with a `javax.net.ssl.SSLEngine` on byte buffers (`commutils/ssl/SSLServerDataHandler.java:131-171`). No port, no loopback, no phone-side trust store involved. |
| Weather, location, notes, tasks are features | They are fixtures. Location is a hardcoded coordinate (`services/location/LocationService.java:24`); weather is one fixed JSON string (`cloudintercept/CloudWeatherService.java:22`); notes and tasks are seeded in constructors (`README.md:94-98`). |
| Software update service | Logs and does nothing (`services/update/SoftwareUpdateService.java:22-27`). The only update path is a debug button that downloads from a LAN address (`buddy/ui/devtools/DeveloperToolsFragment.java:106`, `:115`). |
| The service keeps running in the background | `DeviceService` is a plain started service with `START_STICKY` (`services/DeviceService.java:97-102`, `AndroidManifest.xml:69`), not a foreground service. Only `ScreenRecorderService` is foreground (`AndroidManifest.xml:62-68`). |

### 1.2 Component map

All paths below are under `focals_buddy/app/src/main/java/com/openfocals/`.

| Layer | File | Role |
| --- | --- | --- |
| Transport + framing | `focals/Device.java`, `focals/VarInt.java` | RFCOMM socket, reader thread, varint framing, typed send helpers for every message |
| Schema | `../../proto/BTMessages.proto` | proto2; two envelopes, `BTMessageToFocals` (`:462-487`) and `BTMessageToBuddy` (`:489-507`) |
| Composition root | `services/DeviceService.java:106-192` | Builds every sub-service and registers interceptors |
| Plumbing | greenrobot `EventBus.getDefault()` (`Device.java:201`) | Global bus; every service subscribes on the main thread |
| Discovery/pairing UI | `buddy/ConnectActivity.java` | BLE scan for a name containing "Focals" (`:74-86`), strongest RSSI wins (`:198-203`), then RFCOMM to that MAC |
| Network tunnel | `services/network/NetworkService.java`, `NetworkSocketManager.java` | Handles `HostWhois`, `SocketOpen/Close/Data/Error`; real `java.net.Socket` per tunnel id |
| Interception | `services/network/InterceptedNetworkServiceManager.java` | Maps hostnames to fake IPs `0.0.0.N` (`:89-95`, `:106-110`); tunnels to those IPs go to in-process session factories |
| TLS | `commutils/ssl/SSLServerDataHandler.java`, `PEMImporter.java`, `SSLInterceptDataHandler.java` | In-memory TLS server; keys as above |
| HTTP | `services/network/HTTPHandler.java`, `HTTPEndpointHandler.java` | Hand-written HTTP/1.1 parser and path router |
| Mock cloud | `services/network/cloudintercept/CloudMockService.java` | `/v1/device/companions`, `/v1/device`, `/v1/messenger/user`, `/v1/feature-manager/user` (`:141-332`); pushes cloud host, dummy user id and dummy JWT on connect (`:420-424`), re-issues the token on `RefreshCloudToken` (`:426-432`) |
| Integrations | `cloudintercept/CloudIntegrationHandler.java`, `integrations/{Notes,Tasks,Music}Integration.java`, `CloudWeatherService.java` | `/v1/integration/respond/<uuid>` dispatch (`CloudIntegrationHandler.java:182-223`), `/v1/weather` |
| Teleprompter | `services/network/present/PresentationInterceptService.java`, `present/providers/*` | Fake `north-teleprompter.herokuapp.com` WebSocket (`:229-231`); pushes text cards (`:107-111`) |
| Speech | `present/providers/SpeechToTextProvider.java` | Mozilla DeepSpeech 0.8 with model files expected on external storage (`:38-39`, `:86-89`) |
| Glasses app store | `cloudintercept/CustomFocalsAppService.java` | Serves QML source at `/ofocals/apps/{enable,list,impl}` (`:153-221`) on `app.ofocals.com` and on the mock cloud |
| Screen mirror | `services/ScreenRecorderService.java`, `services/screenmirror/ScreenFrameGrabber.java`, `services/network/ScreenMirrorWSService.java` | MediaProjection, crop, scale to 220x220, JPEG q80, base64 data URI (`ScreenFrameGrabber.java:351-376`) over a fake `screenmirror.ofocals.com` WebSocket (`ScreenMirrorWSService.java:257-259`) |
| Notifications | `services/notifications/NotificationService.java`, `NotificationSender.java` | Listener service; maps Android notifications, actions and RemoteInputs to protobuf; executes actions via `PendingIntent` |
| Media | `services/media/MediaPlaybackService.java` | Media key events and stream volume via `AudioManager` (`:65-107`) |
| Files | `services/files/FileTransferService.java` | Glasses pull files by id in offset/length chunks; CRC32 (`:89-99`, `:199-260`) |
| Alexa | `services/alexa/AlexaAuthState.java`, `buddy/ui/alexa/AlexaAuthFragment.java` | Login with Amazon SDK, PKCE challenge supplied by the glasses |
| UI | `buddy/ui/{main,features,calibrate,apps,screenmirror,devtools,alexa}` | Seven fragments in a navigation drawer |

### 1.3 Message flow, phone to glasses

Example: a notification arrives.

1. Android calls `NotificationService.onNotificationPosted` (`NotificationService.java:44-49`), which posts a `NotificationPostedEvent` on the global bus.
2. `NotificationSender.onNotificationPosted` (`NotificationSender.java:64-165`) builds a protobuf `Notification` and calls `device_.sendNotification` (`:162`).
3. `Device.sendNotification` wraps it in `BTMessageToFocals{notification=6}` (`Device.java:719-721`) and calls `sendMessage`, which drops the message if the handshake has not completed (`:229-235`).
4. `sendMessageInternal` writes `varint(len(proto))`, the proto bytes, then any raw payload (`:205-227`); `sendFramedData` prefixes `varint(len(all of that))` and writes to the RFCOMM output stream (`:413-424`).

Glasses to phone: a reader thread reads up to 950 bytes at a time (`Device.java:382-399`), reposts to the main thread, `onDataReceivedFromBluetooth` reassembles frames (`:439-475`), decodes `BTMessageToBuddy` (`:477-489`), handles connection, battery and Loop state itself (`:492-515`) and broadcasts everything else as `FocalsBluetoothMessageEvent`. Each service filters by which optional field is set.

Example of the reverse direction with payload: the glasses want `GET /v1/weather`. They send `HostWhois{host}`, the phone answers with fake IP `0.0.0.N` (`NetworkService.java:154-170`); `SocketOpen{id, host=0.0.0.N}` creates an intercepted session (`:121-128`); `SocketData{id}` frames carry the TLS records as the trailing payload; the session decrypts, routes the HTTP request, encrypts the response and sends it back as `SocketData{id}` plus payload (`CloudMockService.java:72-129`).

## 2. Transport and protocol

### 2.1 What the code uses

- **Classic Bluetooth RFCOMM, SPP UUID** `00001101-0000-1000-8000-00805f9b34fb` (`Device.java:97`), opened with `createRfcommSocketToServiceRecord` (`:281`), i.e. a secure (bonded) socket with SDP lookup.
- **BLE is used for discovery only.** `ConnectActivity` runs `startLeScan` and keeps devices whose advertised name contains "Focals" (`:74-86`, `:244-264`). No GATT connection is ever made; a repo-wide search for `BluetoothGatt` and `BluetoothLe` finds nothing. So the glasses do advertise over BLE, but the code tells us nothing about what GATT services they expose.
- **No IP path.** No `ServerSocket`, no Wi-Fi API use. Hardcoded `192.168.1.6` addresses are the author's dev machine (`DeviceService.java:157`, `DeveloperToolsFragment.java:87`, `:106`).
- A second UUID, `00000000-DECA-FADE-DECA-DEAFDECACAFF`, is declared and never referenced (`Device.java:98`).

### 2.2 Wire format (fully recoverable from the code)

```
frame    := uvarint32(len(body)) body
body     := uvarint32(len(message)) message payload
message  := protobuf BTMessageToFocals | BTMessageToBuddy   (proto2)
payload  := zero or more raw bytes, to end of frame          (socket data, file chunks)
```

- Encoding: `Device.java:205-227` and `:413-424`. Decoding: `:439-489`, `VarInt.java:14-31` (LEB128, max 5 bytes).
- Handshake: after the socket connects the phone sends `EstablishConnection{versionMajor=4, versionMinor=40}` (`:405-409`); on `EstablishConnectionResponse` it marks the link established, sends `DateTimeUpdate` with the timezone hardcoded to `"CST"` (`:591-598`) and announces `FocalsConnectedEvent` (`:493-499`). Subscribers then push cloud host, user id and token (`CloudMockService.java:420-424`), network state (`NetConnectedService.java:59-62`) and location (`LocationService.java:22-25`).
- No application-level authentication or encryption. Security is Bluetooth bonding only.
- Payload chunking: 950 bytes per read and per tunnelled write (`Device.java:96`, `NetworkSocketManager.java:25`).
- `Heartbeat` exists in the schema (`BTMessages.proto:25`, `:502`) and nothing in the Android code handles or answers it. **ASSUMPTION:** it is informational.
- Reconnect: on failure or disconnect the code immediately calls `connect()` again with no backoff (`Device.java:311-333`).
- The schema is reverse engineered and incomplete: field numbers skip (`BTMessages.proto:462-487`), there are placeholders such as `someintshoudlbe1` (`:238`), and settings calls throw "Not impl" (`Device.java:783-789`).

### 2.3 What iOS allows

Confirmed against Apple sources on 2026-11-17 (links in section 8):

- ExternalAccessory is described by Apple as the way "to set up and manage a connection to an MFi accessory", over Lightning/30-pin "or wirelessly with Bluetooth". There is no other public classic-Bluetooth data API on iOS; Core Bluetooth covers BLE (GATT and L2CAP channels) only.
- Apple's MFi FAQ: accessories using only BLE, Core Bluetooth or "standard Bluetooth profiles supported by iOS" are outside the MFi Program. SPP is not a profile iOS exposes to apps, so a plain SPP device can pair for audio-type profiles but an app cannot open its serial channel.
- The MFi Program does not admit individuals building for personal use, and the accessory maker controls which apps may talk to its accessory.

Consequences:

- **If the glasses are SPP-only and not MFi: hard blocker, no workaround on a stock iPhone.**
- **If the glasses also expose iAP2** (the `…DECAFF` constant suggests so): an iOS app that lists the accessory's protocol string in `UISupportedExternalAccessoryProtocols` can open an `EASession` and get the same kind of byte stream. Three unknowns remain, each needing hardware:
  1. the protocol string (reverse-DNS, chosen by North);
  2. whether the byte stream inside the iAP2 session carries the same framing and `BTMessage` envelope as SPP (**ASSUMPTION:** yes, one firmware, one protocol; unverified);
  3. whether iOS 26 still pairs with and authenticates a 2019 accessory.

### 2.4 Options if the iAP2 path does not exist or does not work

| Option | What it is | Honest assessment |
| --- | --- | --- |
| BLE GATT path | Glasses advertise over BLE (`ConnectActivity.java:74-86`), so some GATT surface exists | Unknown contents. No evidence of a data service in this repo. Worth a 30-minute scan with a BLE explorer; do not plan on it |
| Wi-Fi/TCP | n/a | The glasses have no IP link to the phone in this design. Not available |
| Bridge device | A Mac (IOBluetooth allows RFCOMM), a Raspberry Pi or an old Android phone holds the RFCOMM link and relays frames to the iPhone over BLE or WebSocket | Works technically. For a wearable it means carrying a second device; an Android phone running the existing app does the same job with zero new code. Acceptable only as a desk demo |
| Glasses-side shim | A native daemon on the glasses that re-exposes the companion link over BLE | `glasses_apps/app_manager/notes.txt` shows native binaries can be installed over adb with `/system` remounted, but it needs the connector cable, root, and reverse engineering of the firmware's companion service. Research project, not a plan |
| Jailbreak | Private RFCOMM APIs | No practical jailbreak for current iOS. Not an option |

## 3. Feature-by-feature feasibility

Verdicts: **Direct** (same behaviour), **Degraded** (works with less), **User action** (works after a manual step), **Impossible** (no route on stock iOS), **Blocked** (depends on something outside our control). Every row assumes section 2 is solved.

| Feature | Android mechanism | iOS equivalent | Verdict | Notes |
| --- | --- | --- | --- | --- |
| Discover and pair | BLE scan by name, bond via RFCOMM connect (`ConnectActivity.java:74-86`, `Device.java:281`) | Pair in Settings > Bluetooth, or `EAAccessoryManager.showBluetoothAccessoryPicker`; then `EAAccessoryManager.connectedAccessories` | User action | No in-app scan-and-connect by MAC; iOS never exposes MAC addresses |
| Link, framing, handshake | `Device.java` | `EASession` input/output streams + Swift framer | Direct, if 2.3 holds | The decisive unknown |
| Battery, Loop state, Loop pairing | `Device.java:500-511`, `:697-707` | Same messages | Direct | |
| Display calibration | `ui/calibrate/CalibrateFragment.java:98-162`, `Device.java:663-687` | Same messages | Direct | |
| Feature toggles | `ui/features/FeaturesFragment.java:219-277`, `Device.java:725-739` | Same messages | Direct | |
| Network tunnel (passthrough) | `NetworkSocketManager.java` (`java.net.Socket`) | `NWConnection` per tunnel id; DNS via `getaddrinfo` or `NWEndpoint.hostPort` | Degraded | Works while the app is running. Sockets held by a suspended app are reclaimed; see background row |
| Mock cloud + TLS termination | `CloudMockService.java`, `SSLServerDataHandler.java` | In-memory TLS server (swift-nio-ssl on an `EmbeddedChannel`, or a loopback `NWListener` with a `sec_identity`) + Swift HTTP router | Blocked on certificate | The iOS trust store and `NSAppTransportSecurity` are irrelevant: the phone is the TLS *server* and the glasses are the client that validates. The embedded leaf expired 2023-01-03 and `ofocals.com` belongs to the upstream author. We need our own domain and a publicly trusted cert whose chain a 2019-2020 firmware trust store accepts. A private key shipped inside an app is a compromised key; fetch it at runtime from our server, or terminate TLS on a real server and let the phone tunnel pass through |
| Intercept arbitrary hosts (Amazon, Google speech) | Custom CA leaf (`SSLInterceptDataHandler.java:19-69`), `InterceptedSSLPassthroughProxy.java`; all registrations commented out (`DeviceService.java:166-187`) | Same technique | Out of scope | Needs the custom root installed on the glasses' filesystem (comment at `SSLInterceptDataHandler.java:15-16`), i.e. rooted glasses. Dead code upstream |
| Notification mirroring | `NotificationListenerService` (`NotificationService.java`, manifest `:54-61`) | None for apps. Options: (a) ANCS, if the *firmware* is an ANCS client; (b) AccessoryNotifications, iOS 26.5+, customers in the EU only; (c) notifications our own app originates (calendar via EventKit, reminders, our integrations) | Impossible as built; Degraded via (c) | iOS has no API to read other apps' notifications. (a) needs no app code at all and is checkable in minutes: after pairing, look for "Share System Notifications" on the device's Bluetooth settings page. (b) is real but unusable for a Mexico-based user outside development |
| Notification actions and replies | `PendingIntent.send` with `RemoteInput` (`NotificationSender.java:186-216`) | Only through ANCS positive/negative actions or AccessoryNotifications `NotificationResponse` | Impossible (same caveats) | |
| Dismiss on phone from glasses | `cancelNotification` (`NotificationSender.java:180-185`) | Same as above | Impossible (same caveats) | |
| Media transport control | `AudioManager.dispatchMediaKeyEvent` (`MediaPlaybackService.java:65-87`) driven by the fake Spotify integration (`MusicIntegration.java:91-123`) | `MPMusicPlayerController.systemMusicPlayer` controls Apple Music only; Spotify via its Web API (Premium) | Degraded | No iOS API sends play/pause/next to whichever app is playing |
| Now-playing info | Not implemented upstream; returns "Phone media" placeholder (`MusicIntegration.java:51-67`) | `systemMusicPlayer.nowPlayingItem` for Apple Music; Spotify Web API | Degraded (but better than upstream for those two apps) | `MPNowPlayingInfoCenter` is write-only for our own audio |
| Volume | `AudioManager.setStreamVolume` (`MediaPlaybackService.java:89-107`) | None. `AVAudioSession.outputVolume` is read-only; the `MPVolumeView` slider trick needs a visible view in a foreground app | Impossible in background | |
| Screen mirroring | `MediaProjection` + `ImageReader` (`ScreenFrameGrabber.java:88-96`, `:311-404`), overlay to pick a region (`ScreenRecorderService.java:194-298`, `SYSTEM_ALERT_WINDOW`) | ReplayKit Broadcast Upload Extension (`RPBroadcastSampleHandler`) for system-wide capture, or `RPScreenRecorder.startCapture` for our own app only | Degraded + User action | User must start the broadcast from the system picker each time. The extension runs in a separate process with a tight memory budget (about 50 MB by developer reports; not in Apple's docs), so it must downscale immediately and hand 220x220 JPEGs to the main app (which owns the accessory session) over an app-group socket. No overlay on other apps exists on iOS; pick the crop rectangle inside our app. Independently of the phone, this needs the `screenmirror` binary installed on the glasses by cable (`README.md:90`) |
| Glasses screencast to a server | `StartProgram "Konacast Service"` (`Device.java:768-778`) | Same message | Direct | Debug feature; the receiver is not in this repo |
| Background operation and reconnect | Started service, `START_STICKY` (`DeviceService.java:97-102`); reconnect loop (`Device.java:311-333`) | `UIBackgroundModes: external-accessory` (and `bluetooth-central` only if a BLE path is used) | Degraded | With an open `EASession` the app is woken for accessory traffic, but it is still suspended between events: timers (e.g. the streaming-text provider) stop, idle tunnelled sockets die, long transfers need `beginBackgroundTask`. A force-quit ends everything until the user reopens the app. For BLE, Apple's TN3115 says force-quit apps are relaunched only if they use AccessorySetupKit on iOS 26+, and never after Bluetooth is toggled off in Settings. **ASSUMPTION:** ExternalAccessory does not relaunch a terminated app on accessory connect; verify in Phase 1 |
| File transfer to glasses | Pull protocol, CRC32 (`FileTransferService.java:199-260`) | Same messages; `zlib.crc32` | Direct | Upstream only registers one icon file (`:80`) |
| Firmware update | Debug only (`FileTransferService.java:107-180`, `Device.java:848-866`) | Same messages | Out of scope | No firmware images exist, version is hardcoded (`:178`), brick risk. Do not port |
| Location | Hardcoded (`LocationService.java:24`) | Core Location, "When In Use" or "Always" | Direct, better | |
| Weather | Fixed JSON (`CloudWeatherService.java:22`) | WeatherKit mapped into the same JSON shape | Direct, better | Response schema must be inferred from the single sample |
| Notes, tasks | Seeded fixtures (`NotesIntegration.java`, `TasksIntegration.java`) | EventKit reminders for tasks; notes from our own store (Apple Notes has no API) | Direct | |
| Teleprompter / streaming text | `PresentationInterceptService.java`, `StreamingTextPresentationProvider.java` | Same WebSocket emulation | Direct (foreground), Degraded (background timers) | Plain HTTP, no certificate dependency |
| Live subtitles (speech-to-text) | DeepSpeech with model files the repo does not ship (`SpeechToTextProvider.java:38-39`; `README.md:28-31`) | `SFSpeechRecognizer` with `requiresOnDeviceRecognition`, or SpeechAnalyzer on iOS 26; `AVAudioEngine` | Direct, better | Needs microphone + speech permissions; `audio` background mode to keep listening with the screen off |
| Custom QML apps | `CustomFocalsAppService.java:153-221`, `res/raw/game_2048.qml` | Same HTTP endpoints, QML bundled as resources | Direct | Useless without `app_manager` installed on the glasses by cable (`README.md:213-215`) |
| Alexa login | Login with Amazon SDK jar (`AlexaAuthFragment.java:219-242`), key stripped (`keys.xml:2`) | Login with Amazon SDK for iOS, same PKCE flow and messages (`Device.java:604-651`) | Blocked | The LWA security profile must be linked to the AVS product id the glasses report (`AlexaAuthFragment.java:224-226`). We do not own that product. Also unverified that AVS still serves this device type |
| Time sync | `DateTimeUpdate`, tz hardcoded `"CST"` (`Device.java:591-598`) | Same, with the real `TimeZone.current` | Direct, better | Expected tz string format is unknown |

### `glasses_apps/` is out of scope

Confirmed from the code. Both projects are Qt 5.9 / QML programs cross-compiled with the Android NDK for ARM (`glasses_apps/screenmirror/Makefile:13-17`), linked against the glasses' own `black_coral_app` libraries (`screenmirror/demo_app.pro:8`) and installed with `adb push` into `/system/bin` (`app_manager/notes.txt`). They run on the glasses' OS and reach the phone only through the tunnelled HTTP/WebSocket endpoints (`app_manager/RemoteAppGrabber.cpp:33`). Nothing in them is phone-side code. An iOS port neither changes nor rebuilds them; it only has to keep serving the same endpoints (`/ofocals/apps/*`, the `screenmirror.ofocals.com` WebSocket).

## 4. Proposed iOS architecture

Swift 6, SwiftUI, strict concurrency, iOS 18 minimum (iOS 26 if SpeechAnalyzer is wanted). The protocol core is a Swift package with no UIKit dependency so it also builds for macOS, which is what makes the Phase 0 Mac spike and any bridge reuse the same code.

```
FocalsKit (Swift package)
  FocalsProtocol   swift-protobuf types generated from BTMessages.proto (proto2 is supported),
                   Framer (uvarint + payload split), golden-vector tests
  FocalsTransport  protocol ByteTransport { inbound: AsyncThrowingStream<Data>; send(Data) async throws }
                   EATransport (EASession streams), RFCOMMTransport (macOS, IOBluetooth),
                   LoopbackTransport (tests, simulator)
  FocalsLink       actor GlassesLink: handshake, state machine, backoff reconnect, typed send API,
                   MessageRouter fan-out
  FocalsNet        actor TunnelManager: id -> TunnelHandler; PassthroughTunnel (NWConnection);
                   InterceptRegistry (hostname -> fake IP -> handler factory);
                   HTTP1 parser, WebSocket server framing, in-memory TLS server
  FocalsFeatures   CloudMock, Integrations, Presentation, Apps, Files, Calibration, FeatureFlags,
                   Location, Weather, Media, Alexa
App target         SwiftUI screens, @Observable view models, permissions, settings
BroadcastExt       RPBroadcastSampleHandler -> downscale -> app-group socket (screen mirror)
```

Replacing the Android plumbing:

- **Service -> actor.** `DeviceService` becomes one `GlassesLink` actor owned by the app delegate, alive for the process lifetime. There is no iOS analogue of a sticky service; what keeps the process around is the `external-accessory` background mode.
- **EventBus -> typed streams.** The global bus posts everything to everyone on the main thread. Replace it with a `MessageRouter` that exposes one `AsyncStream` per `BTMessageToBuddy` case (`router.messages(of: \.socketData)`), plus `AsyncStream<LinkState>` for connect/disconnect. Each feature is an actor running a `for await` loop. This removes the main-thread hop that currently serialises all tunnel traffic.
- **Threads and AsyncTask -> structured concurrency.** One read task, one serial write queue with backpressure driven by `hasSpaceAvailable` (the Android code has none). `EASession` streams are run-loop based; schedule them on a dedicated thread's run loop and bridge to `AsyncStream`.
- **Protobuf.** `swift-protobuf` with the existing `.proto` checked in unchanged; generate at build time with the SwiftPM plugin. The mix of `required` fields means building messages through small factory functions so a missing field fails in tests, not on the wire.
- **Where the "local HTTP server" lives.** Nowhere on the network. It is a `TunnelHandler` conforming type inside the app process that receives `Data` from `SocketData` frames and returns `Data`. So the question "can an embedded server in an iOS app serve the glasses" has a clean answer: yes, because the glasses never reach the phone over IP; the constraint is only that our process is awake, which accessory traffic itself provides.
- **TLS termination.** Preferred: `swift-nio-ssl` `NIOSSLServerHandler` in an `EmbeddedChannel`, the direct equivalent of `SSLEngine`. Alternative with zero dependencies: bind an `NWListener` with TLS on `127.0.0.1` and pipe each intercepted tunnel to it. Either way the identity is fetched from our server and kept in the Keychain, never compiled in.
- **Certificate service.** A small server-side job (ACME DNS-01 for a domain we own) that renews the cloud-host certificate and serves it to the authenticated app. Alternatively host the mock cloud on a real server and drop local termination; the phone then only tunnels. The second is simpler and keeps keys off devices, at the cost of features that need phone-local state (media control).
- **Simulator.** ExternalAccessory does not work usefully in the simulator; `LoopbackTransport` with recorded frames lets everything above the transport run under XCTest and in previews.

Info.plist surface: `UISupportedExternalAccessoryProtocols`, `UIBackgroundModes` (`external-accessory`, optionally `audio`, `location`), `NSBluetoothAlwaysUsageDescription`, `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSAppleMusicUsageDescription`. No ATS exceptions are needed for the mock cloud; passthrough tunnels use `NWConnection`, which ATS does not govern.

## 5. Phased plan

Effort is one experienced iOS developer. Phases 1+ are conditional on Phase 0.

| Phase | Work | Effort | Risk retired / exit criterion |
| --- | --- | --- | --- |
| **0a. Proof of life on a Mac** | `FocalsProtocol` package + a macOS command-line tool using IOBluetooth RFCOMM (allowed on macOS, no MFi). Pair, send `EstablishConnection{4,40}`, print `EstablishConnectionResponse` and `FocalsBatteryState`. Also dump the SDP records and note every service UUID | 1-2 days | The glasses still boot, pair and speak this protocol in 2026. Produces the framing code and test vectors every later phase uses. **Fail = stop: nothing to port to** |
| **0b. Proof of life on an iPhone** | (1) Pair the glasses in iOS Settings. (2) Obtain the protocol string (section 6). (3) Minimal app: `UISupportedExternalAccessoryProtocols`, open `EASession`, send the same handshake, show the battery level. (4) In parallel, list GATT services with a BLE explorer and check for the ANCS toggle | 2-4 days | The transport blocker. **Pass = one protobuf message exchanged with a development-signed build on a stock iPhone. Fail = no-go** (section 2.4 options are not a product) |
| 1. Link layer | `GlassesLink` actor, reconnect with backoff, router, background mode, connection UI, battery/Loop/calibration/feature-toggle screens | 1.5 weeks | Background behaviour of ExternalAccessory: measure what survives lock, suspension, out-of-range, reboot |
| 2. Network tunnel | `TunnelManager`, passthrough with `NWConnection`, `HostWhois`, error-code mapping (101/104/106/107 as in `NetworkSocketManager.java`) | 1 week | Throughput and stability of tunnelled traffic at 950-byte frames; whether the glasses tolerate tunnel loss on suspension |
| 3. Cloud mock | Own domain + ACME pipeline, in-memory TLS, HTTP router, the four base endpoints, token refresh | 1.5-2 weeks | Whether the glasses accept a current public chain and what they do when the cloud is absent. **If the firmware rejects modern chains, all cloud-backed lenses are dead on every platform** |
| 4. Useful lenses | Weather (WeatherKit), tasks (EventKit), notes, teleprompter, live subtitles, location, Apple Music control, file transfer for icons | 2-3 weeks | Product value: is the result worth wearing |
| 5. Notifications | Whichever of ANCS / own-app notifications Phase 0b showed possible; AccessoryNotifications only as an EU experiment | 0-2 weeks | The feature gap users will notice first |
| 6. Optional | Screen mirror (broadcast extension), QML app server, Spotify Web API, Alexa | 2-3 weeks | Only if glasses-side binaries are installed / keys obtainable |

Total if everything passes: roughly 9-13 weeks for a personal-use app covering the subset in section 0. Phase 0 costs under a week and can end the project.

## 6. Open questions and required hardware

Cannot be answered from this repository:

1. **Do the glasses expose iAP2, and what is the protocol string?** Needs the glasses. Ways to learn it: SDP browse from macOS or Linux (`sdptool browse`); Apple's PacketLogger while an iPhone pairs; the `UISupportedExternalAccessoryProtocols` array in North's original iOS app `Info.plist` if an archived IPA can be found; or the firmware image.
2. **Is the iAP2 session payload the same framing and schema as SPP?** Needs 0b.
3. **Does a third-party development build get an `EASession` to this accessory on iOS 26?** Needs 0b.
4. **What GATT services do the glasses expose, and does the firmware act as an ANCS/AMS client?** BLE explorer plus the Settings toggle check. If AMS is implemented, media control may also work firmware-side with no app.
5. **Which root CAs does the firmware trust, and does it enforce certificate validity dates?** The upstream design note says the certificate "may periodically need to be updated" (`DESIGN.md:27-31`), which implies it does. Needs glasses plus a test certificate.
6. **How is the cloud hostname derived?** The app sends `ofocals.com` (`CloudMockService.java:40`, `:423`) but registers the interceptor for `cloud.ofocals.com` (`:41`, `DeviceService.java:132`). **ASSUMPTION:** the firmware prepends `cloud.`.
7. **Do the glasses need the Loop ring paired to be usable**, and does Loop pairing work when driven from iOS? (`ConnectActivity.java:322-324`.)
8. **Are the glasses usable at all if previously bound to North's app/account?** The README requires disconnecting in the North app first (`README.md:11`), which can no longer be done.
9. **Heartbeat semantics, tz string format, full `/v1/weather` schema, unmapped proto fields.** A Bluetooth HCI capture of the Android app (Android's HCI snoop log) would settle these cheaply.
10. **Licence.** The repository has no licence file. A port that reuses its schema and logic is a derivative work of unlicensed code; get the author's permission or a licence before publishing anything.

Hardware and tools: one pair of Focals with Loop and charging case; ideally the connector cable (needed for any glasses-side app); a Mac; a development iPhone; optionally an Android phone for HCI snoop logs and as a known-good reference.

## 7. Go / no-go

- **No-go** as a faithful port, and no-go as an App Store product, regardless of Phase 0.
- **Conditional go** for a personal, sideloaded companion with the subset in section 0, *only* after Phase 0b exchanges a protocol message from an iPhone. That is the single experiment that matters; it costs days, not weeks.
- If the goal is simply to use the glasses, the existing Android app on a spare phone is the cheaper answer, subject to the same expired-certificate problem (section 0, item 4), which should be checked first because it affects both platforms.

## 8. iOS references checked (2026-11-17)

- External Accessory framework overview: https://developer.apple.com/documentation/externalaccessory
- MFi Program FAQ (what is in and out of the programme, who may join): https://mfi.apple.com/en/faqs
- TN3115, Bluetooth State Restoration app relaunch rules (updated 2025-09-15 for iOS 26): https://developer.apple.com/documentation/technotes/tn3115-bluetooth-state-restoration-app-relaunch-rules
- Accessory Notifications framework (iOS 26.5+, iPhone only, customer use limited to the EU): https://developer.apple.com/documentation/accessorynotifications
- Broadcast extension memory ceiling (secondary sources only; not in Apple's documentation): https://www.forasoft.com/blog/article/how-to-implement-screen-sharing-in-ios-1193
- iAP2 service UUID (device-side `…CAFE` value in a vendor SDK header; the accessory-side `…CAFF` value is not confirmed by a primary source): https://mtbgit.infineon.cn/Infineon/btsdk-include/blob/master/wiced_bt_iap2.h
