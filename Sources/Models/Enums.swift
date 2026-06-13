import SwiftUI

// MARK: - Mood

enum Mood: Int, CaseIterable, Identifiable {
  case awful = 1
  case low
  case neutral
  case good
  case great

  var id: Int { rawValue }

  var emoji: String {
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

  var colorScheme: ColorScheme? {
    switch self {
    case .system: return nil
    case .light: return .light
    case .dark: return .dark
    }
  }
}
