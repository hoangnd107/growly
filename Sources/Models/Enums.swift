import SwiftUI

// MARK: - Mood

enum Mood: Int, CaseIterable, Identifiable {
  case awful = 1
  case low
  case neutral
  case good
  case great

  var id: Int { rawValue }

  /// The default emoji for this built-in mood. Per-user skins are applied through
  /// `MoodCatalog` / `MoodOption`, not here.
  var emoji: String { defaultEmoji }

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

  var color: Color { Color(hexString: defaultColorHex) }

  /// The default color (hex, no `#`) for this built-in mood. Used as the seed for
  /// the customizable `MoodOption`.
  var defaultColorHex: String {
    switch self {
    case .awful: return "E5484D"
    case .low: return "F0883E"
    case .neutral: return "F5C84B"
    case .good: return "8CCF4D"
    case .great: return "34C759"
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
