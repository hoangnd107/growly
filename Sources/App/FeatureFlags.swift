import Foundation

/// Capabilities that require entitlements a *free* Apple ID cannot sign are
/// gated here. The code for them lives in the project but is disabled in the
/// Sideloadly build so the app installs and runs. Flip these on when building
/// with a paid Apple Developer account (App Store / TestFlight).
enum FeatureFlags {
  /// HealthKit read/write — needs the HealthKit entitlement (paid only).
  static let healthKit = false

  /// Live Activities / Dynamic Island & push — needs APNs + entitlement.
  static let liveActivities = false

  /// iCloud / CloudKit sync of the SwiftData store — needs iCloud entitlement.
  static let iCloudSync = false

  /// Local notification reminders — works when the user grants permission.
  static let reminders = true

  /// On-device speech-to-text for reflections (mic permission, no entitlement).
  static let voiceInput = false

  /// Apple Intelligence / FoundationModels coaching — needs newer OS + entitlement.
  static let appleIntelligence = false
}
