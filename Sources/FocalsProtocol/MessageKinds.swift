import Foundation

/// The two message vocabularies, named the way the protocol names them: by destination.
///
/// Field numbers are protocol facts, read from the schema the glasses and the companion
/// agree on. They are stable across every firmware version seen (1.81 through 1.115).
/// A number missing from a table is a field the official app did not use; it still
/// decodes structurally, it just has no name.
public enum ToGlasses: Int, CaseIterable, Sendable {
    case handshake = 1
    case socketOpenResponse = 2
    case socketCloseResponse = 3
    case socketDataChunk = 4
    case notification = 6
    case remotePing = 7
    case currentTime = 8
    case calibrateEyeTracking = 9
    case startInputDevicePairing = 10
    case cancelInputDevicePairing = 11
    case unpairInputDevice = 12
    case appNotificationFilter = 13
    case dismissNotification = 16
    case getHostByNameResponse = 18
    case socketError = 19
    case sync = 20
    case settings = 25
    case state = 26
    case startExperience = 27
    case stopExperience = 28
    case fileTransfer = 29
    case update = 30
    case factoryReset = 31
    case captureLogs = 32
    case calendar = 33
    case location = 34
    case exitPupilAlignment = 35
    case refreshAuthTokenFailed = 36
    case sendSmsResponse = 37
    case sms = 38
    case features = 39
    case externalAuthorization = 40
    case locationSharingControl = 41
    case navigation = 42
    case activity = 43
    case captureScreenshot = 44
    case favouriteContacts = 45
    case noteTaker = 46
    case templatedSettings = 47
    case wonderland = 48
    case showcase = 49
    case bcpV2 = 50
}

public enum ToCompanion: Int, CaseIterable, Sendable {
    case handshakeResponse = 1
    case socketOpen = 2
    case socketClose = 3
    case socketDataChunk = 4
    case dismissNotification = 6
    case inputDevicePairingStatusChanged = 7
    case inputDeviceStatus = 8
    case appAttributes = 9
    case getHostByName = 10
    case socketError = 11
    case batteryState = 12
    case refreshAuthToken = 14
    case launchableExperiences = 15
    case fileTransfer = 16
    case update = 17
    case factoryResetResponse = 18
    case sync = 19
    case poke = 20
    case location = 21
    case exitPupilAlignment = 22
    case ancsStatus = 23
    case sendSms = 24
    case sms = 25
    case features = 26
    case externalAuthorization = 27
    case locationSharingControl = 28
    case notification = 29
    case navigation = 30
    case activity = 31
    case screenshot = 32
    case favouriteContacts = 33
    case intentionalReboot = 34
    case templatedSettings = 35
    case clipboard = 36
    case noteTaker = 37
    case showcase = 38
    case camera = 39
    case bcpV2 = 40
}
