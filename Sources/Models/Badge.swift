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
  /// Badges in the same family form an upgrade ladder (Bronze → Silver → Gold).
  /// `nil` for standalone badges.
  var family: String? = nil
  /// Position within the family ladder (1 = first tier). Higher tiers need more.
  var tier: Int = 1

  var color: Color { Color(hex: accentHex) }
}

enum BadgeCatalog {
  static let all: [Badge] = [
    // Milestones
    Badge(id: "first_reflection", title: "First Reflection", subtitle: "Complete your very first daily review", systemIcon: "sparkles", category: .milestone, accentHex: 0xFFC83D),

    // Streak ladder (consecutive active days)
    Badge(id: "sage_7", title: "7-Day Sage", subtitle: "Reach a 7-day streak", systemIcon: "flame.fill", category: .consistency, accentHex: 0xFF6B3D, family: "streak", tier: 1),
    Badge(id: "perfectionist_30", title: "Perfectionist", subtitle: "Reach a 30-day streak", systemIcon: "crown.fill", category: .consistency, accentHex: 0xFFD23D, family: "streak", tier: 2),
    Badge(id: "centurion_100", title: "Centurion", subtitle: "Reach a 100-day streak", systemIcon: "rosette", category: .consistency, accentHex: 0xFF8C3D, family: "streak", tier: 3),

    // Lessons / adjustments (mastery)
    Badge(id: "insight_master", title: "Insight Master", subtitle: "Capture 50 lessons in your reviews", systemIcon: "lightbulb.fill", category: .mastery, accentHex: 0x5AC8FA),
    Badge(id: "adjuster_25", title: "The Adjuster", subtitle: "Check off 25 next-day adjustments", systemIcon: "arrow.triangle.2.circlepath", category: .mastery, accentHex: 0xAF8CFF),

    // Habits ladder
    Badge(id: "habit_starter_25", title: "Habit Starter", subtitle: "Complete habits 25 times", systemIcon: "checkmark.circle.fill", category: .consistency, accentHex: 0x66D17A, family: "habits", tier: 1),
    Badge(id: "habit_hero", title: "Habit Hero", subtitle: "Complete habits 100 times", systemIcon: "checkmark.seal.fill", category: .consistency, accentHex: 0x34C759, family: "habits", tier: 2),

    // Words ladder (entries + notes)
    Badge(id: "wordsmith", title: "Wordsmith", subtitle: "Write 10,000 words across reviews and notes", systemIcon: "text.book.closed.fill", category: .mastery, accentHex: 0x64D2FF, family: "words", tier: 1),
    Badge(id: "novelist_50k", title: "Novelist", subtitle: "Write 50,000 words across reviews and notes", systemIcon: "books.vertical.fill", category: .mastery, accentHex: 0x32ADE6, family: "words", tier: 2),

    // Notes ladder
    Badge(id: "note_taker_10", title: "Note Taker", subtitle: "Save 10 notes (including imports)", systemIcon: "note.text", category: .mastery, accentHex: 0x0A84FF, family: "notes", tier: 1),
    Badge(id: "chronicler_100", title: "Chronicler", subtitle: "Save 100 notes (including imports)", systemIcon: "books.vertical", category: .mastery, accentHex: 0x5E5CE6, family: "notes", tier: 2),

    // Early bird
    Badge(id: "early_bird", title: "Early Bird", subtitle: "Complete 10 reviews before noon", systemIcon: "sunrise.fill", category: .consistency, accentHex: 0xFFB03D),

    // Level ladder
    Badge(id: "level_10", title: "Rising", subtitle: "Reach level 10", systemIcon: "arrow.up.circle.fill", category: .milestone, accentHex: 0x9A8CFF, family: "level", tier: 1),
    Badge(id: "level_25", title: "Ascendant", subtitle: "Reach level 25", systemIcon: "bolt.circle.fill", category: .milestone, accentHex: 0xFF8CD2, family: "level", tier: 2),
    Badge(id: "level_50", title: "Luminary", subtitle: "Reach level 50", systemIcon: "star.circle.fill", category: .milestone, accentHex: 0xFF6BD6, family: "level", tier: 3),

    // Life-area badges (count matching tags across reviews and notes)
    Badge(id: "health_transformer", title: "Health Transformer", subtitle: "Tag 10 reviews or notes with #health", systemIcon: "heart.fill", category: .health, accentHex: 0xFF3D5A),
    Badge(id: "career_climber", title: "Career Climber", subtitle: "Tag 10 reviews or notes with #career or #work", systemIcon: "briefcase.fill", category: .career, accentHex: 0x5AC8FA),
    Badge(id: "connector", title: "Connector", subtitle: "Tag 10 reviews or notes with #relationships", systemIcon: "person.2.fill", category: .relationships, accentHex: 0xFF9F0A),
  ]

  private static let byID: [String: Badge] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

  static func badge(id: String) -> Badge? { byID[id] }

  static func badges(in category: BadgeCategory) -> [Badge] {
    all.filter { $0.category == category }
  }

  /// Badges in a family, ascending by tier.
  static func family(_ family: String) -> [Badge] {
    all.filter { $0.family == family }.sorted { $0.tier < $1.tier }
  }
}
