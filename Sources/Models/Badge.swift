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
  /// Badges in the same family form an upgrade ladder. Completing one tier
  /// surfaces the next (harder) tier as the new goal, while the earned tier is
  /// kept. Every badge belongs to a family so it can always be upgraded.
  var family: String? = nil
  /// Position within the family ladder (1 = first tier). Higher tiers need more.
  var tier: Int = 1

  var color: Color { Color(hex: accentHex) }
}

enum BadgeCatalog {
  static let all: [Badge] = [
    // Reviews ladder (total daily reviews completed)
    Badge(id: "first_reflection", title: "First Reflection", subtitle: "Complete your very first daily review", systemIcon: "sparkles", category: .milestone, accentHex: 0xFFC83D, family: "reviews", tier: 1),
    Badge(id: "reviewer_50", title: "Reflective", subtitle: "Complete 50 daily reviews", systemIcon: "checkmark.circle", category: .milestone, accentHex: 0xFFB23D, family: "reviews", tier: 2),
    Badge(id: "reviewer_200", title: "Devoted", subtitle: "Complete 200 daily reviews", systemIcon: "checkmark.circle.fill", category: .milestone, accentHex: 0xFF9F3D, family: "reviews", tier: 3),
    Badge(id: "reviewer_365", title: "A Year of Growth", subtitle: "Complete 365 daily reviews", systemIcon: "calendar.circle.fill", category: .milestone, accentHex: 0xFF8C3D, family: "reviews", tier: 4),

    // Streak ladder (consecutive active days)
    Badge(id: "sage_7", title: "7-Day Sage", subtitle: "Reach a 7-day streak", systemIcon: "flame.fill", category: .consistency, accentHex: 0xFF6B3D, family: "streak", tier: 1),
    Badge(id: "perfectionist_30", title: "Perfectionist", subtitle: "Reach a 30-day streak", systemIcon: "crown.fill", category: .consistency, accentHex: 0xFFD23D, family: "streak", tier: 2),
    Badge(id: "centurion_100", title: "Centurion", subtitle: "Reach a 100-day streak", systemIcon: "rosette", category: .consistency, accentHex: 0xFF8C3D, family: "streak", tier: 3),
    Badge(id: "unbroken_365", title: "Unbroken", subtitle: "Reach a 365-day streak", systemIcon: "infinity.circle.fill", category: .consistency, accentHex: 0xFF5A3D, family: "streak", tier: 4),

    // Lessons ladder (lessons captured in reviews)
    Badge(id: "insight_master", title: "Insight Master", subtitle: "Capture 50 lessons in your reviews", systemIcon: "lightbulb.fill", category: .mastery, accentHex: 0x5AC8FA, family: "lessons", tier: 1),
    Badge(id: "wisdom_keeper_200", title: "Wisdom Keeper", subtitle: "Capture 200 lessons in your reviews", systemIcon: "brain.head.profile", category: .mastery, accentHex: 0x3DA8E0, family: "lessons", tier: 2),

    // Adjustments ladder (next-day adjustments completed)
    Badge(id: "adjuster_25", title: "The Adjuster", subtitle: "Check off 25 next-day adjustments", systemIcon: "arrow.triangle.2.circlepath", category: .mastery, accentHex: 0xAF8CFF, family: "adjust", tier: 1),
    Badge(id: "course_corrector_100", title: "Course Corrector", subtitle: "Check off 100 next-day adjustments", systemIcon: "gearshape.2.fill", category: .mastery, accentHex: 0x9A6BFF, family: "adjust", tier: 2),

    // Habits ladder
    Badge(id: "habit_starter_25", title: "Habit Starter", subtitle: "Complete habits 25 times", systemIcon: "checkmark.circle.fill", category: .consistency, accentHex: 0x66D17A, family: "habits", tier: 1),
    Badge(id: "habit_hero", title: "Habit Hero", subtitle: "Complete habits 100 times", systemIcon: "checkmark.seal.fill", category: .consistency, accentHex: 0x34C759, family: "habits", tier: 2),
    Badge(id: "habit_master_365", title: "Habit Master", subtitle: "Complete habits 365 times", systemIcon: "trophy.fill", category: .consistency, accentHex: 0x28A745, family: "habits", tier: 3),

    // Words ladder (entries + notes)
    Badge(id: "wordsmith", title: "Wordsmith", subtitle: "Write 10,000 words across reviews and notes", systemIcon: "text.book.closed.fill", category: .mastery, accentHex: 0x64D2FF, family: "words", tier: 1),
    Badge(id: "novelist_50k", title: "Novelist", subtitle: "Write 50,000 words across reviews and notes", systemIcon: "books.vertical.fill", category: .mastery, accentHex: 0x32ADE6, family: "words", tier: 2),
    Badge(id: "laureate_150k", title: "Laureate", subtitle: "Write 150,000 words across reviews and notes", systemIcon: "graduationcap.fill", category: .mastery, accentHex: 0x1E90D0, family: "words", tier: 3),

    // Notes ladder
    Badge(id: "note_taker_10", title: "Note Taker", subtitle: "Save 10 notes (including imports)", systemIcon: "note.text", category: .mastery, accentHex: 0x0A84FF, family: "notes", tier: 1),
    Badge(id: "chronicler_100", title: "Chronicler", subtitle: "Save 100 notes (including imports)", systemIcon: "books.vertical", category: .mastery, accentHex: 0x5E5CE6, family: "notes", tier: 2),
    Badge(id: "archivist_500", title: "Archivist", subtitle: "Save 500 notes (including imports)", systemIcon: "archivebox.fill", category: .mastery, accentHex: 0x4A48C0, family: "notes", tier: 3),

    // Level ladder
    Badge(id: "level_10", title: "Rising", subtitle: "Reach level 10", systemIcon: "arrow.up.circle.fill", category: .milestone, accentHex: 0x9A8CFF, family: "level", tier: 1),
    Badge(id: "level_25", title: "Ascendant", subtitle: "Reach level 25", systemIcon: "bolt.circle.fill", category: .milestone, accentHex: 0xFF8CD2, family: "level", tier: 2),
    Badge(id: "level_50", title: "Luminary", subtitle: "Reach level 50", systemIcon: "star.circle.fill", category: .milestone, accentHex: 0xFF6BD6, family: "level", tier: 3),
    Badge(id: "level_100", title: "Legend", subtitle: "Reach level 100", systemIcon: "crown.fill", category: .milestone, accentHex: 0xFF4FB0, family: "level", tier: 4),
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

  /// Badges to surface in a gallery: every earned badge, plus the lowest unearned
  /// tier in each family (the current goal). Higher locked tiers stay hidden until
  /// their predecessor is earned, so completing a badge "upgrades" it to a new
  /// goal while the earned tiers remain on display.
  static func visible(earned: Set<String>) -> [Badge] {
    var result: [Badge] = []
    var nextShownFamilies = Set<String>()
    for badge in all {
      if earned.contains(badge.id) {
        result.append(badge)
        continue
      }
      guard let fam = badge.family else { result.append(badge); continue }
      guard !nextShownFamilies.contains(fam) else { continue }
      let lowerEarned = family(fam)
        .filter { $0.tier < badge.tier }
        .allSatisfy { earned.contains($0.id) }
      if lowerEarned {
        nextShownFamilies.insert(fam)
        result.append(badge)
      }
    }
    return result
  }
}
