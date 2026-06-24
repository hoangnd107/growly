import Foundation

/// A snapshot of the numbers badge rules are evaluated against.
struct GamificationStats: Equatable {
  var totalReviews: Int
  var currentStreak: Int
  var longestStreak: Int
  var lessonsCount: Int
  var adjustmentsCompleted: Int
  var habitCompletions: Int
  /// Words written across reviews AND notes (feature 17).
  var totalWords: Int
  /// Active notes saved, including imports (feature 17).
  var noteCount: Int
  var level: Int
  var earlyReviews: Int
  /// Lowercased tag → count, aggregated across both reviews and notes.
  var tagCounts: [String: Int]
}

enum BadgeEngine {
  /// All badge IDs the user qualifies for, given current stats. Each family is a
  /// ladder; meeting a higher tier's threshold also implies the lower tiers.
  static func earnedBadgeIDs(_ s: GamificationStats) -> Set<String> {
    var ids = Set<String>()
    // Reviews ladder
    if s.totalReviews >= 1 { ids.insert("first_reflection") }
    if s.totalReviews >= 50 { ids.insert("reviewer_50") }
    if s.totalReviews >= 200 { ids.insert("reviewer_200") }
    if s.totalReviews >= 365 { ids.insert("reviewer_365") }
    // Streak ladder
    if s.longestStreak >= 7 { ids.insert("sage_7") }
    if s.longestStreak >= 30 { ids.insert("perfectionist_30") }
    if s.longestStreak >= 100 { ids.insert("centurion_100") }
    if s.longestStreak >= 365 { ids.insert("unbroken_365") }
    // Lessons ladder
    if s.lessonsCount >= 50 { ids.insert("insight_master") }
    if s.lessonsCount >= 200 { ids.insert("wisdom_keeper_200") }
    // Adjustments ladder
    if s.adjustmentsCompleted >= 25 { ids.insert("adjuster_25") }
    if s.adjustmentsCompleted >= 100 { ids.insert("course_corrector_100") }
    // Habit ladder
    if s.habitCompletions >= 25 { ids.insert("habit_starter_25") }
    if s.habitCompletions >= 100 { ids.insert("habit_hero") }
    if s.habitCompletions >= 365 { ids.insert("habit_master_365") }
    // Words ladder
    if s.totalWords >= 10_000 { ids.insert("wordsmith") }
    if s.totalWords >= 50_000 { ids.insert("novelist_50k") }
    if s.totalWords >= 150_000 { ids.insert("laureate_150k") }
    // Notes ladder
    if s.noteCount >= 10 { ids.insert("note_taker_10") }
    if s.noteCount >= 100 { ids.insert("chronicler_100") }
    if s.noteCount >= 500 { ids.insert("archivist_500") }
    // Level ladder
    if s.level >= 10 { ids.insert("level_10") }
    if s.level >= 25 { ids.insert("level_25") }
    if s.level >= 50 { ids.insert("level_50") }
    if s.level >= 100 { ids.insert("level_100") }
    return ids
  }

  /// Progress (0–1) toward a badge, for the "locked" gallery state.
  static func progress(for badgeID: String, stats s: GamificationStats) -> Double {
    func frac(_ value: Int, _ target: Int) -> Double {
      target <= 0 ? 1 : min(1, Double(value) / Double(target))
    }
    switch badgeID {
    case "first_reflection": return frac(s.totalReviews, 1)
    case "reviewer_50": return frac(s.totalReviews, 50)
    case "reviewer_200": return frac(s.totalReviews, 200)
    case "reviewer_365": return frac(s.totalReviews, 365)
    case "sage_7": return frac(s.longestStreak, 7)
    case "perfectionist_30": return frac(s.longestStreak, 30)
    case "centurion_100": return frac(s.longestStreak, 100)
    case "unbroken_365": return frac(s.longestStreak, 365)
    case "insight_master": return frac(s.lessonsCount, 50)
    case "wisdom_keeper_200": return frac(s.lessonsCount, 200)
    case "adjuster_25": return frac(s.adjustmentsCompleted, 25)
    case "course_corrector_100": return frac(s.adjustmentsCompleted, 100)
    case "habit_starter_25": return frac(s.habitCompletions, 25)
    case "habit_hero": return frac(s.habitCompletions, 100)
    case "habit_master_365": return frac(s.habitCompletions, 365)
    case "wordsmith": return frac(s.totalWords, 10_000)
    case "novelist_50k": return frac(s.totalWords, 50_000)
    case "laureate_150k": return frac(s.totalWords, 150_000)
    case "note_taker_10": return frac(s.noteCount, 10)
    case "chronicler_100": return frac(s.noteCount, 100)
    case "archivist_500": return frac(s.noteCount, 500)
    case "level_10": return frac(s.level, 10)
    case "level_25": return frac(s.level, 25)
    case "level_50": return frac(s.level, 50)
    case "level_100": return frac(s.level, 100)
    default: return 0
    }
  }
}
