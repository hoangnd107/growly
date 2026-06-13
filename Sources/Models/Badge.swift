import SwiftUI

/// Static badge definition (display metadata). Earned badges are recorded as
/// `BadgeRecord` in SwiftData; unlock rules live in `BadgeEngine`.
struct Badge: Identifiable, Hashable {
  let id: String
  let title: String
  let subtitle: String
  let systemIcon: String
  let category: BadgeCategory
  let accentHex: UInt

  var color: Color { Color(hex: accentHex) }
}

enum BadgeCatalog {
  static let all: [Badge] = [
    Badge(id: "first_reflection", title: "First Reflection", subtitle: "Complete your first review", systemIcon: "sparkles", category: .milestone, accentHex: 0xFFC83D),
    Badge(id: "sage_7", title: "7-Day Sage", subtitle: "Keep a 7-day streak", systemIcon: "flame.fill", category: .consistency, accentHex: 0xFF6B3D),
    Badge(id: "perfectionist_30", title: "Perfectionist", subtitle: "Review 30 days in a row", systemIcon: "crown.fill", category: .consistency, accentHex: 0xFFD23D),
    Badge(id: "insight_master", title: "Insight Master", subtitle: "Capture 50 lessons", systemIcon: "lightbulb.fill", category: .mastery, accentHex: 0x5AC8FA),
    Badge(id: "adjuster_25", title: "The Adjuster", subtitle: "Complete 25 adjustments", systemIcon: "arrow.triangle.2.circlepath", category: .mastery, accentHex: 0xAF8CFF),
    Badge(id: "habit_hero", title: "Habit Hero", subtitle: "Complete 100 habits", systemIcon: "checkmark.seal.fill", category: .consistency, accentHex: 0x34C759),
    Badge(id: "wordsmith", title: "Wordsmith", subtitle: "Write 10,000 words", systemIcon: "text.book.closed.fill", category: .mastery, accentHex: 0x64D2FF),
    Badge(id: "early_bird", title: "Early Bird", subtitle: "10 morning reviews", systemIcon: "sunrise.fill", category: .consistency, accentHex: 0xFFB03D),
    Badge(id: "level_10", title: "Rising", subtitle: "Reach level 10", systemIcon: "arrow.up.circle.fill", category: .milestone, accentHex: 0x9A8CFF),
    Badge(id: "level_25", title: "Ascendant", subtitle: "Reach level 25", systemIcon: "bolt.circle.fill", category: .milestone, accentHex: 0xFF8CD2),
    Badge(id: "health_transformer", title: "Health Transformer", subtitle: "10 health reflections", systemIcon: "heart.fill", category: .health, accentHex: 0xFF3D5A),
    Badge(id: "career_climber", title: "Career Climber", subtitle: "10 career reflections", systemIcon: "briefcase.fill", category: .career, accentHex: 0x5AC8FA),
    Badge(id: "connector", title: "Connector", subtitle: "10 relationship reflections", systemIcon: "person.2.fill", category: .relationships, accentHex: 0xFF9F0A),
  ]

  private static let byID: [String: Badge] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

  static func badge(id: String) -> Badge? { byID[id] }

  static func badges(in category: BadgeCategory) -> [Badge] {
    all.filter { $0.category == category }
  }
}
