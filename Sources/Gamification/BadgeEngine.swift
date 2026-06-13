import Foundation

/// A snapshot of the numbers badge rules are evaluated against.
struct GamificationStats: Equatable {
  var totalReviews: Int
  var currentStreak: Int
  var longestStreak: Int
  var lessonsCount: Int
  var adjustmentsCompleted: Int
  var habitCompletions: Int
  var totalWords: Int
  var level: Int
  var earlyReviews: Int
  var tagCounts: [String: Int]
}

enum BadgeEngine {
  /// All badge IDs the user qualifies for, given current stats.
  static func earnedBadgeIDs(_ s: GamificationStats) -> Set<String> {
    var ids = Set<String>()
    if s.totalReviews >= 1 { ids.insert("first_reflection") }
    if s.longestStreak >= 7 { ids.insert("sage_7") }
    if s.longestStreak >= 30 { ids.insert("perfectionist_30") }
    if s.lessonsCount >= 50 { ids.insert("insight_master") }
    if s.adjustmentsCompleted >= 25 { ids.insert("adjuster_25") }
    if s.habitCompletions >= 100 { ids.insert("habit_hero") }
    if s.totalWords >= 10_000 { ids.insert("wordsmith") }
    if s.earlyReviews >= 10 { ids.insert("early_bird") }
    if s.level >= 10 { ids.insert("level_10") }
    if s.level >= 25 { ids.insert("level_25") }
    if (s.tagCounts["health"] ?? 0) >= 10 { ids.insert("health_transformer") }
    if (s.tagCounts["career"] ?? 0) >= 10 { ids.insert("career_climber") }
    if (s.tagCounts["relationships"] ?? 0) >= 10 { ids.insert("connector") }
    return ids
  }

  /// Progress (0–1) toward a badge, for the "locked" gallery state.
  static func progress(for badgeID: String, stats s: GamificationStats) -> Double {
    func frac(_ value: Int, _ target: Int) -> Double {
      target <= 0 ? 1 : min(1, Double(value) / Double(target))
    }
    switch badgeID {
    case "first_reflection": return frac(s.totalReviews, 1)
    case "sage_7": return frac(s.longestStreak, 7)
    case "perfectionist_30": return frac(s.longestStreak, 30)
    case "insight_master": return frac(s.lessonsCount, 50)
    case "adjuster_25": return frac(s.adjustmentsCompleted, 25)
    case "habit_hero": return frac(s.habitCompletions, 100)
    case "wordsmith": return frac(s.totalWords, 10_000)
    case "early_bird": return frac(s.earlyReviews, 10)
    case "level_10": return frac(s.level, 10)
    case "level_25": return frac(s.level, 25)
    case "health_transformer": return frac(s.tagCounts["health"] ?? 0, 10)
    case "career_climber": return frac(s.tagCounts["career"] ?? 0, 10)
    case "connector": return frac(s.tagCounts["relationships"] ?? 0, 10)
    default: return 0
    }
  }
}
