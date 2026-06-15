import SwiftUI

// MARK: - Mood

/// Holds the user's optional per-level mood emoji overrides so a custom emoji
/// shows everywhere `Mood.emoji` is read (set from `UserProgress.moodEmojis`).
/// `emojis` is either empty (use defaults) or holds one entry per mood level.
final class MoodStyle {
  static let shared = MoodStyle()
  var emojis: [String] = []

  /// The override for a 1-based mood level, or nil to fall back to the default.
  func emoji(for level: Int) -> String? {
    let index = level - 1
    guard emojis.indices.contains(index) else { return nil }
    let value = emojis[index].trimmingCharacters(in: .whitespaces)
    return value.isEmpty ? nil : value
  }
}

enum Mood: Int, CaseIterable, Identifiable {
  case awful = 1
  case low
  case neutral
  case good
  case great

  var id: Int { rawValue }

  /// The user's custom emoji for this level if set, else the default.
  var emoji: String {
    if let custom = MoodStyle.shared.emoji(for: rawValue) { return custom }
    return defaultEmoji
  }

  var defaultEmoji: String {
    switch self {
    case .awful: return "😣"
    case .low: return "😔"
    case .neutral: return "😐"
    case .good: return "🙂"
    case .great: return "😄"
    }
  }

  var label: String {
    switch self {
    case .awful: return "Awful"
    case .low: return "Low"
    case .neutral: return "Okay"
    case .good: return "Good"
    case .great: return "Great"
    }
  }

  var color: Color {
    switch self {
    case .awful: return Color(hex: 0xE5484D)
    case .low: return Color(hex: 0xF0883E)
    case .neutral: return Color(hex: 0xF5C84B)
    case .good: return Color(hex: 0x8CCF4D)
    case .great: return Color(hex: 0x34C759)
    }
  }
}

// MARK: - The four reflection fields (the daily loop)

enum ReflectionKind: String, CaseIterable, Identifiable {
  case win
  case mistake
  case lesson
  case adjustment

  var id: String { rawValue }

  var title: String {
    switch self {
    case .win: return "Win"
    case .mistake: return "Mistake"
    case .lesson: return "Lesson"
    case .adjustment: return "Adjustment"
    }
  }

  var prompt: String {
    switch self {
    case .win: return "What went well today?"
    case .mistake: return "What didn't go as planned?"
    case .lesson: return "What did you learn from it?"
    case .adjustment: return "What will you do differently tomorrow?"
    }
  }

  var systemIcon: String {
    switch self {
    case .win: return "trophy.fill"
    case .mistake: return "exclamationmark.triangle.fill"
    case .lesson: return "lightbulb.fill"
    case .adjustment: return "arrow.triangle.2.circlepath"
    }
  }

  var accent: Color {
    switch self {
    case .win: return Color(hex: 0x34C759)
    case .mistake: return Color(hex: 0xFF9F0A)
    case .lesson: return Color(hex: 0x5AC8FA)
    case .adjustment: return Color(hex: 0xAF8CFF)
    }
  }
}

// MARK: - XP reasons

enum XPReason: String, Codable {
  case dailyReview
  case earlyBonus
  case qualityField
  case habitComplete
  case streakBonus
  case morningIntention
  case challenge

  var label: String {
    switch self {
    case .dailyReview: return "Daily review"
    case .earlyBonus: return "Early bird"
    case .qualityField: return "Quality reflection"
    case .habitComplete: return "Habit complete"
    case .streakBonus: return "Streak bonus"
    case .morningIntention: return "Morning intention"
    case .challenge: return "Challenge"
    }
  }
}

// MARK: - Badge categories

enum BadgeCategory: String, CaseIterable, Identifiable, Codable {
  case milestone
  case consistency
  case mastery
  case health
  case career
  case relationships

  var id: String { rawValue }

  var title: String {
    switch self {
    case .milestone: return "Milestones"
    case .consistency: return "Consistency"
    case .mastery: return "Mastery"
    case .health: return "Health"
    case .career: return "Career"
    case .relationships: return "Relationships"
    }
  }
}

// MARK: - Theme preference

enum ThemePreference: String, CaseIterable, Identifiable {
  case system
  case light
  case dark

  var id: String { rawValue }

  var label: String {
    switch self {
    case .system: return "System"
    case .light: return "Light"
    case .dark: return "Dark"
    }
  }

  /// Icon shown in the Appearance picker (instead of text).
  var icon: String {
    switch self {
    case .system: return "circle.lefthalf.filled"
    case .light: return "sun.max.fill"
    case .dark: return "moon.fill"
    }
  }

  var colorScheme: ColorScheme? {
    switch self {
    case .system: return nil
    case .light: return .light
    case .dark: return .dark
    }
  }
}
