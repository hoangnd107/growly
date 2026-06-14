import Foundation
import SwiftUI

/// In-app language override. English keys are used as the lookup keys so a
/// missing translation gracefully falls back to readable English.
final class LocalizationManager {
  static let shared = LocalizationManager()

  private(set) var bundle: Bundle = .main

  /// "system" | "en" | "vi" | "zh-Hans" | "ko"
  var code: String = "system" {
    didSet { updateBundle() }
  }

  private func updateBundle() {
    guard code != "system" else { bundle = .main; return }
    if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
       let localized = Bundle(path: path) {
      bundle = localized
    } else {
      bundle = .main
    }
  }

  /// The locale used for date/number formatting (nil → system).
  var locale: Locale? {
    code == "system" ? nil : Locale(identifier: code)
  }
}

/// The languages offered in Settings.
enum AppLanguage: String, CaseIterable, Identifiable {
  case system
  case en
  case vi
  case zhHans = "zh-Hans"
  case ko

  var id: String { rawValue }

  /// Name shown in the picker, in the language itself.
  var displayName: String {
    switch self {
    case .system: return L("System")
    case .en: return "English"
    case .vi: return "Tiếng Việt"
    case .zhHans: return "中文"
    case .ko: return "한국어"
    }
  }

  var flag: String {
    switch self {
    case .system: return "🌐"
    case .en: return "🇬🇧"
    case .vi: return "🇻🇳"
    case .zhHans: return "🇨🇳"
    case .ko: return "🇰🇷"
    }
  }
}

/// Localized string lookup against the active language bundle.
func L(_ key: String) -> String {
  NSLocalizedString(key, tableName: nil, bundle: LocalizationManager.shared.bundle, value: key, comment: "")
}

/// Localized + formatted (e.g. `Lf("%d days", count)`).
func Lf(_ key: String, _ arguments: CVarArg...) -> String {
  String(format: L(key), arguments: arguments)
}
