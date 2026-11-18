# openfocals on iOS: migration plan

Status: analysis only, written 2026-11-17 from a read of the code at commit `4f25041`
(last upstream commit 2023-05-27). No hardware was available; nothing here was run against
real glasses. Everything marked **ASSUMPTION** is inferred and unverified.

## 0. Verdict first

**A faithful iOS port is not viable. A reduced, sideload-only port may be viable, and one
two-to-four-day experiment with physical glasses decides it. Do not commit to anything past
Phase 0 until that experiment passes.**

> **Read section 9 with this.** Added the same day from published sources: North shipped an
> official **iOS** companion app, and the glasses displayed iPhone notifications. That does
> not change the no-go on a faithful port or on the App Store, but it raises the odds on the
> iAP2 question below, and it moves notification mirroring from "impossible" to "probably
> already works firmware-side". It also makes two Phase 0 checks possible **without
> hardware**.

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
   - *Revised by section 10 (second repo, `focals_utils`): a captured SDP record shows the
     companion channel is plain SPP (service class `1101`) with no iAP2 service listed, which
     weakens the iAP2 story; but the glasses are a confirmed dual-mode BT device with a working
     BLE central/GATT stack, and the likelier explanation for North's iOS app is a custom BLE
     GATT companion channel, which needs no MFi. That would dissolve this blocker. Unproven
     from code; the archived IPA still decides it.*
2. **Distribution.** Even if (1) works, Apple's documentation states that the accessory
   manufacturer decides which apps may talk to its MFi accessory. North is defunct. Treat
   App Store distribution as unavailable; this is a personal/sideloaded app at best.
3. **Notification mirroring**, the feature most users would expect, has no iOS equivalent
   of `NotificationListenerService`. It is recoverable only if the glasses firmware itself
   implements Apple's ANCS (unknown), or in the EU on iOS 26.5+ via AccessoryNotifications.
   *Revised by section 9: contemporaneous reviews describe iPhone notifications working on
   Focals with exactly the action set ANCS allows, so the firmware is probably an ANCS
   client and this is probably not a blocker at all. Confirmed by section 10: the firmware's
   own protobuf schema carries an `AncsDeviceStatus` message. No longer a blocker.*
4. **The cloud-intercept TLS certificate is expired and is not ours to renew.** The embedded
   leaf for `cloud.ofocals.com` expired 2023-01-03. This is not an iOS problem; it has
   probably already broken the cloud features on Android. Any port needs its own domain,
   its own publicly trusted certificate, and a renewal pipeline.
   *Refined by section 10: for anyone with rooted glasses (connector cable) the second repo
   ships a procedure to install a private root CA, which lets the mock cloud use a self-signed,
   long-lived cert and removes the renewal problem entirely. For unmodified glasses the
   publicly-trusted-cert path above still stands.*

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
| BLE GATT path | Glasses advertise over BLE (`ConnectActivity.java:74-86`), so some GATT surface exists | Unknown contents in *this* repo. **Revised by section 10:** the second repo proves the firmware has a BLE central/GATT-client stack, and makes a custom-BLE iOS companion channel a live hypothesis. Still worth the BLE scan; no longer "do not plan on it" |
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
| Intercept arbitrary hosts (Amazon, Google speech) | Custom CA leaf (`SSLInterceptDataHandler.java:19-69`), `InterceptedSSLPassthroughProxy.java`; all registrations commented out (`DeviceService.java:166-187`) | Same technique | Out of scope | Needs the custom root installed on the glasses' filesystem (comment at `SSLInterceptDataHandler.java:15-16`), i.e. rooted glasses. Dead code upstream. **Section 10** confirms the second repo ships exactly that install procedure (cable + rooted filesystem) |
| Notification mirroring | `NotificationListenerService` (`NotificationService.java`, manifest `:54-61`) | None for apps. Options: (a) ANCS, firmware-side; (b) AccessoryNotifications, iOS 26.5+, customers in the EU only; (c) notifications our own app originates (calendar via EventKit, reminders, our integrations) | **Revised by section 10 to "firmware-side, no app code"** | The firmware is an ANCS client (`AncsDeviceStatus` in the BT schema), so once the glasses are paired to an iPhone they receive notifications directly over BLE/ANCS with ANCS's reduced action set, independent of our companion app. iOS still gives *our app* no way to read other apps' notifications; it does not need to. (b) remains EU-only |
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

## 9. Addendum, 2026-11-17: North shipped an official iOS app

Added after the code analysis, from published sources rather than the repository. The
Android code cannot know this, and it changes two of the judgements above.

### 9.1 The facts

- **An official Focals companion app existed for iOS**, not only Android. It handled setup,
  settings, the Alignment (calibration) flow, and **choosing which app notifications appear
  on the glasses**. Supported iPhone 5S and later on iOS 11+. North's own support page
  confirms it was removed from both the App Store and Google Play when Focals and its
  services were discontinued after 2020-07-31.
- **The glasses displayed iPhone notifications**, and reviewers consistently describe an
  asymmetry: on Android you could triage and reply to a notification; **on iPhone you could
  only mark it as read**, and replying to texts worked on Android only.
- Replying to texts on iOS went through North's own servers, so the recipient saw a message
  from an unfamiliar number. That path depended on the dead cloud and is gone regardless.
- *Not* to be confused with **Focals Showroom**, a separate iOS app that used the TrueDepth
  camera for sizing before purchase. It has nothing to do with the companion link; do not
  chase it.

### 9.2 What it implies

- **An iOS-to-glasses data channel existed and worked.** North's app changed settings and
  drove alignment, which is bidirectional application data, not a standard Bluetooth
  profile. On iOS that leaves exactly two possibilities: iAP2 via ExternalAccessory, or a
  custom BLE GATT service. Either one is a path this port could use; the hard blocker in
  section 0 item 1 is "neither exists", and that is now unlikely.
- **The glasses are probably an MFi accessory.** Combined with the unused
  `00000000-DECA-FADE-DECA-DEAFDECACAFF` constant at `focals/Device.java:98`, the existence
  of a working iOS app that is not a mere BLE remote raises the iAP2 hypothesis from
  "suggestive" to "probable". **Still an ASSUMPTION**: no primary source names Focals in the
  MFi programme, and a custom GATT service would explain the same observations.
- **The firmware is probably an ANCS client.** The iPhone action asymmetry is diagnostic, not
  incidental: Apple's ANCS gives an accessory the notification content plus a *positive and a
  negative action slot* and nothing more, while Android's `NotificationListenerService`
  exposes arbitrary actions and `RemoteInput` replies. "Mark as read on iPhone, full triage
  on Android" is precisely the shape of that difference. If the firmware consumes ANCS, then
  on iOS **notification mirroring needs no app code from us at all** — the glasses get
  notifications straight from iOS over BLE once paired. This revises section 3's "Impossible"
  verdicts for the three notification rows to "probably works, firmware-side, with ANCS's
  reduced action set". **ASSUMPTION** until checked on hardware.
- It also explains why the Android app owns a notification listener at all: on Android the
  phone must do the work, while on iOS the system hands it to the accessory directly.

### 9.3 What this adds to Phase 0 — and two checks that need no glasses

The original Phase 0 needed hardware for everything. Two of its questions can now be
attacked first, cheaply, from a desk:

1. **Find an archived copy of North's iOS app and read its `Info.plist`.** This single
   artifact would settle the project's central question without touching glasses:
   `UISupportedExternalAccessoryProtocols` confirms iAP2 **and gives the exact protocol
   string** (question 1 in section 6); `UIBackgroundModes` distinguishes
   `external-accessory` from `bluetooth-central`; the binary would carry any GATT service
   UUIDs. The app was public until 2020-07-31, so copies may exist in old iTunes libraries,
   old device backups, or IPA archives. **This is now the cheapest highest-value step in the
   whole project** — ahead of buying hardware.
2. **Check whether the firmware is an ANCS client** — still needs glasses, but only a
   pairing and a glance at "Share System Notifications" in iOS Bluetooth settings. Minutes,
   and it decides the feature users care about most.

### 9.4 What it does not change

The no-go stands where it stood. App Store distribution remains unavailable: an MFi
accessory's manufacturer decides which apps may connect, and North is defunct — being
*probably* MFi does not help, it is the same gate. Everything remains sideload-only, and the
expired-certificate problem with the mocked cloud is untouched by any of this.

### 9.5 Sources

- North's support site (discontinuation; app removed from both stores): https://support.bynorth.com/
- Tom's Hardware review (iPhone vs Android notification handling): https://www.tomshardware.com/reviews/north-focals-smart-glasses-ar,5968.html
- Trusted Reviews (app's role in setup, settings, alignment, notification selection): https://www.trustedreviews.com/reviews/focals-by-north-smart-glasses
- Voicebot.ai review (reply-to-text limited to Android): https://voicebot.ai/2019/08/08/review-north-focals-clarify-a-vision-of-smart-glasses/
- MacSources review (iPhone compatibility, iOS 11+): https://macsources.com/focals-by-north-smart-glasses-review/
- MobileSyrup (Focals *Showroom*, the separate sizing app, for disambiguation): https://mobilesyrup.com/2019/09/18/focals-ios-showroom-app-launch-canada/

## 10. Addendum, 2026-11-17: second repo (`focals_utils`) by the same author

Assessed from a read of `aegray/focals_utils`, cloned read-only at
`/Users/abraham/Documents/projects/focals_utils`. Protocol facts only cross the boundary; no
code is vendored (project rule). Nothing here was executed; nothing was run against glasses.
Private-key files in `glasses/rootcert/` were not opened; the procedure is described, never its
keys. `file:line` citations below are into `focals_utils`.

**Does the verdict move?** Partly, and in the optimistic direction, but not to an unconditional
go. Three things changed. (1) **Notification mirroring is no longer a blocker:** the firmware's
own Bluetooth schema contains an `AncsDeviceStatus` message, so the glasses are an ANCS client
and receive iPhone notifications directly over BLE once paired — this upgrades section 9's
inference to a confirmed fact and revises section 3's "Impossible" rows to "works firmware-side,
no app code". (2) **The transport blocker is now genuinely two-sided:** a captured SDP record
shows the companion channel is plain SPP with no iAP2 service advertised (which, taken alone,
would make section 0 item 1 *worse*), but the glasses are a confirmed dual-mode device with a
working BLE central/GATT stack, and North's documented iOS app most plausibly used a **custom
BLE GATT companion channel** — a path that needs no MFi and would reopen even App Store
distribution. I cannot choose between those from code. (3) The expired-certificate blocker has a
clean resolution for rooted glasses. Net: the conditional-go for the subset becomes materially
more likely, the single decisive artifact is still the archived iOS IPA (section 9.3), and the
no-go for a *guaranteed* App Store port stands only until that IPA is read. **The go/no-go gate
itself is unchanged; the odds behind it improved.**

### 10.1 BLE/GATT-client question (the one that matters most)

Confirmed: the firmware contains a BLE central / GATT-client stack.

- `loop/loop_provider.py` is a BlueZ GATT **peripheral** that impersonates the Loop ring
  (`FocalsLoopMainService.SVC_UUID = '39de08dc-624e-4d6f-8e42-e1adb7d92fe1'`,
  `loop/loop_provider.py:297`, with input/devid/unknown characteristics at `:417`, `:473`,
  `:514`). The README states the glasses connect to it and accept it as a Loop. For the glasses
  to discover services and subscribe to a characteristic on it, the **glasses must act as a BLE
  central and GATT client** — the exact role an ANCS consumer plays against an iPhone. The
  companion comment block at `loop/loop_provider.py:61-81` records the real Loop's GATT table,
  and `loop/loop_input.py:8-11` drives the same characteristics as a client.
- Effect on blocker 3 (section 2.4 "BLE GATT path — unknown contents"): the stack is no longer
  unknown to exist. What remains unknown is whether a *companion* GATT service (as opposed to the
  Loop-facing and ANCS-facing roles) is exposed. The Loop UUIDs are the Loop's, not the glasses'.

### 10.2 ANCS: now a schema fact, not an inference

- `btmsgprotos/` holds the BT protobuf schema lifted from five shipping app versions (v1.81 →
  v1.115). Every version defines `message AncsDeviceStatus { required AncsStatus status; }` with
  `enum AncsStatus { LISTENING, ENUMERATING, PAIRING, PAIRING_COMPLETE, REGISTERING, CONNECTED }`
  (`btmsgprotos/focals_v1.115.0-2842.apk.bc.proto:89`). That is the lifecycle vocabulary of an
  ANCS consumer attaching to an ANCS provider.
- It is carried both ways: the to-glasses envelope `BlackCoral` has `ancsStatus = 23`
  (`:499`) and the to-phone `CompanionSync` has `ancsStatus = 2` (`:678`).
- Corroborating Apple-shaped fields in the same schema: `AppAttributes { bundleId, name }`
  (`:84`, "bundleId" is ANCS App-Attribute language), `AppNotificationBlacklist` /
  `AddToAppNotificationBlacklist` (the per-app notification selection North's iOS app offered),
  `DismissNotification` and `PerformNotificationAction` (ANCS positive/negative actions).
- Conclusion: notification delivery to the glasses on iOS is handled by iOS + the firmware over
  BLE/ANCS, needs no code from us, and gives ANCS's reduced action set — which is precisely the
  "mark as read on iPhone, full triage on Android" asymmetry section 9 cited from reviews.
  **ASSUMPTION** still open only on whether a 2026 iPhone completes ANCS pairing with 2019
  firmware; checkable in minutes on hardware (the Bluetooth-settings notification toggle).

### 10.3 `pycompanion` is the better protocol reference, and corroborates section 2.2

`linuxtools/pycompanion/` is a working companion that the glasses accept in place of the phone
app. It is a better basis for `FocalsProtocol`/`FocalsLink` than the decompiled Java, because it
is the author's own clean expression of the wire format rather than Google's proto-lite output:

- **Framing matches section 2.2 exactly.** `companion_lib.py:13-45` reads
  `uvarint(frameLen)`, then `uvarint(msgLen) + message + trailing payload` — byte-for-byte the
  `Device.java` scheme. Send side at `companion_lib.py:71-82`. Chunking is 950/1000 bytes
  (`companion_lib.py:117`, `connect.py:17`). This independently confirms the framing I recovered.
- **Handshake matches:** `connect.py:36-43` sends `Handshake{protocolMajorVersion=4,
  protocolMinorVersion=40}` over `AF_BLUETOOTH / BTPROTO_RFCOMM` (`connect.py:29`), identical to
  `EstablishConnection{4,40}`. `HandshakeResponse` (`btmsgprotos/...:976`) adds fields the Android
  side ignores: `softwareVersion`, and `requiredProtocol{Major,Minor}Version` with an enum result
  `{SUCCESS, BLACK_CORAL_UPDATE_REQUIRED, COMPANION_UPDATE_REQUIRED}` — version negotiation the
  port should honour.
- **Envelope names differ, mapping is clean:** `BlackCoral` = to-glasses (openfocals
  `BTMessageToFocals`), `Companion` = to-phone (`BTMessageToBuddy`). 203 messages vs the ~60 in
  the `BTMessages.proto` I analysed.
- **It fills section 2.2's gaps.** Templated settings, which `Device.java:783-789` threw
  "Not impl" for, are fully specified (`GetSettings`/`SetSettings`/`GetSettingsResponse`,
  `BlackCoralTemplatedSettings` at `:367`; `avail_settings.txt` is a captured dump). It adds SMS
  (`CompanionSms`, `MarkSmsRead`, `SyncSms`), navigation, favourite contacts, clipboard, camera,
  showcase/stories, exit-pupil alignment (the calibration flow), and `ExternalAuthorization`
  (the Alexa path). `send_msg.py` and `test_msgs.py` are worked examples.
- **Does it make Phase 0 cheaper?** It moves Phase 0a off macOS: `pycompanion` and
  `loop_provider` use Linux BlueZ (`AF_BLUETOOTH` RFCOMM, dbus GATT), not portable to a Mac.
  The cheapest proof-of-life host is now a **Linux box or Raspberry Pi** with a BT adapter,
  reading these as the reference, rather than writing fresh IOBluetooth code. It does **not**
  make the iPhone step (0b) testable sooner — that still needs an `EASession` or a GATT client
  on a real device, and it does not resolve whether iOS uses SPP/iAP2 or BLE.

### 10.4 The certificate blocker (section 0 item 4), refined

`glasses/rootcert/directions.sh` is a procedure to mint a private root CA and a leaf, then
**install the CA into the glasses' system trust store** (the script's own target is
`/system/etc/ssl/certs/cacert.pem`, `directions.sh:31`). `qt_test_ssl/` is a Qt client that
verifies the installed CA against a local HTTPS server (`runserver.py`). Implications:

- Installing the CA requires write access to `/system`, i.e. the full rooted-filesystem access
  the connector cable gives (section 10.5). So for **unmodified** glasses this is not available,
  and the publicly-trusted-cert path in section 0 item 4 stands unchanged.
- For **rooted** glasses it dissolves the blocker: with your own CA installed you serve the mock
  cloud with a self-signed, long-lived certificate and never depend on a public CA or its expiry.
  The author's `ofocals.com` cloud-host-redirect trick (openfocals) exists precisely to avoid
  needing this install; the two are alternative resolutions, not a dependency.
- The embedded leaves in both repos are expired and their SANs are the author's own domains; none
  is reusable. (Per project rule, keys were not read.)

### 10.5 Connector cable and firmware access (section 2.4 "glasses-side shim")

`connector/notes.txt`, `connector/bootloader.txt` and `glasses/updating/update_process.txt`
establish how much the cable gives:

- The 4-pin magnetic connector is USB (`connector/notes.txt:12-18`); the device is Qualcomm-based
  (USB `idVendor=05c6`, `connector/notes.txt`), and its secure-boot fuses were never blown, so a
  self-built cable plus low-level flashing yields read/write filesystem and bootloader access.
  `WRITEUP.md:119-122` reaches a root adb shell by that route.
- But adding software the *supported* way is gated: OTA update packages are whole-file
  signature-verified against North's certificates (`update_process.txt`, the
  `verify_pkg_sig` description), so an unsigned package cannot be pushed without North's private
  keys. The only install path is the cable.
- Rating change for a glasses-side BLE shim that would route around MFi entirely: from "research
  project, not a plan" to **"physically possible and the hardware access is proven, but still a
  multi-month reverse-engineering effort that each user must repeat with a hand-built cable, and
  the author never worked out how the glasses *receive* Bluetooth messages or run new software
  without the cable (`WRITEUP.md:188-199`, `:242-244`)."** It is not a distributable path, and
  the ANCS finding makes it largely unnecessary: notifications already arrive without it, and the
  shim would only help the companion link.

### 10.6 FCC filings (`info/fcc/`) — the only primary hardware evidence

Extracted with `pdftotext` (installed; nothing added).

- **The glasses officially supported iPhone.** Focals User Manual (FCC ID `2ACKV-TL1A`):
  "compatible with Android ... smartphones and iPhones (5S and newer). The North App supports
  Android OS versions 5.0+ and iOS versions 10+." This is primary-source confirmation of section
  9's premise that an iOS companion existed and worked.
- **The glasses are a dual-mode Bluetooth radio.** Test Report lists classic BR/EDR packet types
  (`3-EV5, 3-DH5, DM5`) *and* BLE (`GFSK`), both in 2402–2480 MHz. So both the SPP companion link
  and a BLE companion/ANCS link are physically present — the hardware does not decide H1 vs H2.
- **Loop is a separate BLE device** (FCC ID `2ACKV-TL1B`), consistent with `loop_provider`.
- The exact Bluetooth module part number is not in the extractable text (only in internal-photo
  images); the Qualcomm SoC is confirmed by the USB VID. Not worth more effort.

### 10.7 The SDP capture refines, and slightly complicates, the transport question

`linuxtools/findglasses.py:85` records the author's captured SDP service list for the glasses.
The companion service is **"Focals SPP Service", RFCOMM, service-classes `1101` +
`00000000-DECA-FADE-DECA-DEAFDECACAFF`**. Two consequences:

- The mystery constant from section 0 item 1 and section 9.2 is **not iAP2**: it is the custom
  service-class UUID of the Focals SPP service itself. This *weakens* the "glasses are MFi / use
  iAP2" reading — no iAP service class appears in the captured record.
- Yet North shipped a working iOS app (10.6). The most parsimonious reconciliation is **H2: the
  iOS companion used a custom BLE GATT service**, which the confirmed BLE stack (10.1) supports
  and which requires no MFi. H1 (an iAP2 service the Linux browse did not surface) is not
  excluded. The archived IPA's `Info.plist` settles it directly: `UISupportedExternalAccessoryProtocols`
  present ⇒ H1 (iAP2/ExternalAccessory, sideload-only); absent ⇒ H2 (custom BLE GATT, Core
  Bluetooth, no MFi, App Store possible). This is still the highest-value no-hardware step, and
  section 9.3 already names where to look.

### 10.8 WRITEUP.md firmware inventory — effect on the feature table

`WRITEUP.md` is the author's full account. Items that touch a verdict:

- **Networking is Bluetooth-tunnelled by design, system-wide.** A custom lib ("csl") replaces Qt's
  network stack so every glasses-side socket is carried as BT messages through the companion
  (`WRITEUP.md:127-132`, `:443`). This confirms the tunnel architecture in section 1.3 is not an
  app choice but the platform's only network path — so the port's `TunnelManager` (section 4) is
  mandatory for *any* cloud-backed lens, not optional.
- **A firmware service drives updates and file transfer** (`companion_service`,
  `update_process.txt`), matching the file-pull protocol in section 3; nothing changes, firmware
  update stays out of scope.
- **`notification_app`/`notification_service` exist on the glasses** (`WRITEUP.md:415-417`) — the
  consumer of ANCS/notification data, consistent with 10.2.
- **`libcslserver.so` exists** (`WRITEUP.md:443-444`): there may be a way to make the glasses
  *accept* inbound connections, which would matter for a shim, but the author never used it.
  Flagged, not planned.
- Nothing in the inventory names Apple directly; the Apple integration is visible only in the BT
  schema (10.2), not in the binary names.

### 10.9 What remains unknown after this repo

- H1 vs H2 (SPP/iAP2 vs custom BLE GATT for the iOS companion). Resolved by the archived IPA or by
  hardware, not by either repo's code.
- Whether 2026 iOS still pairs/authenticates and completes ANCS with 2019 firmware.
- Whether a companion-grade GATT service (beyond Loop-facing and ANCS-facing roles) is exposed;
  `findglasses.py` would print it but no capture is committed.
- Section 6's other open items are unchanged.

### 10.10 Sources (second repo)

All citations are into `aegray/focals_utils` at the clone path above:
`loop/loop_provider.py`, `loop/loop_input.py`, `linuxtools/findglasses.py`,
`linuxtools/pycompanion/{companion_lib.py,connect.py}`,
`btmsgprotos/focals_v1.115.0-2842.apk.bc.proto`, `glasses/rootcert/directions.sh`,
`connector/{notes.txt,bootloader.txt}`, `glasses/updating/update_process.txt`, `WRITEUP.md`,
and the FCC PDFs under `info/fcc/tl1a/` and `tl1b/` (public filings, fccid.io `2ACKV-TL1A` /
`2ACKV-TL1B`).
