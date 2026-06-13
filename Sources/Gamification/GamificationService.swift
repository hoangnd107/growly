import Foundation
import SwiftData

/// The result of completing a review — drives the celebration UI.
struct ReviewResult: Equatable {
  let xpGained: Int
  let breakdown: XPBreakdown
  let multiplier: Double
  let leveledUp: Bool
  let oldLevel: Int
  let newLevel: Int
  let newBadges: [Badge]
  let streak: Int
  let streakIncreased: Bool

  static let none = ReviewResult(
    xpGained: 0,
    breakdown: XPBreakdown(baseItems: [], multiplier: 1),
    multiplier: 1,
    leveledUp: false,
    oldLevel: 1,
    newLevel: 1,
    newBadges: [],
    streak: 0,
    streakIncreased: false
  )
}

/// Orchestrates XP, streaks and badge unlocks. Pure-ish: it mutates the passed
/// `UserProgress` and inserts records into the given `ModelContext`.
@MainActor
enum GamificationService {
  static func completeReview(
    entry: Entry,
    habitsCompleted: [Habit],
    progress: UserProgress,
    allEntries: [Entry],
    existingBadgeIDs: Set<String>,
    context: ModelContext,
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> ReviewResult {
    // Guard against awarding the same entry twice.
    guard entry.xpAwarded == 0 else { return .none }

    let oldLevel = LevelSystem.levelInfo(totalXP: progress.totalXP).level

    let streakUpdate = StreakEngine.update(
      lastReviewDay: progress.lastReviewDay,
      currentStreak: progress.currentStreak,
      longestStreak: progress.longestStreak,
      today: now,
      calendar: calendar
    )

    let breakdown = XPEngine.reviewBreakdown(
      entry: entry,
      habitsCompleted: habitsCompleted,
      streak: streakUpdate.newStreak,
      now: now,
      calendar: calendar
    )
    let gained = breakdown.total

    // Apply to progress.
    progress.totalXP += gained
    progress.currentStreak = streakUpdate.newStreak
    progress.longestStreak = streakUpdate.newLongest
    progress.lastReviewDay = calendar.startOfDay(for: now)
    progress.totalHabitCompletions += habitsCompleted.count
    if calendar.component(.hour, from: now) < 12 {
      progress.earlyReviewCount += 1
    }

    entry.xpAwarded = gained
    entry.updatedAt = now

    context.insert(XPTransaction(amount: gained, reason: .dailyReview, multiplier: breakdown.multiplier, date: now))

    let newLevelInfo = LevelSystem.levelInfo(totalXP: progress.totalXP)
    let leveledUp = newLevelInfo.level > oldLevel

    // Evaluate badges against the updated picture.
    var entries = allEntries
    if !entries.contains(where: { $0.id == entry.id }) { entries.append(entry) }
    let stats = computeStats(progress: progress, allEntries: entries, level: newLevelInfo.level)
    let earned = BadgeEngine.earnedBadgeIDs(stats)
    let newIDs = earned.subtracting(existingBadgeIDs)

    var newBadges: [Badge] = []
    for id in newIDs.sorted() {
      context.insert(BadgeRecord(badgeID: id, earnedAt: now))
      if let badge = BadgeCatalog.badge(id: id) { newBadges.append(badge) }
    }

    progress.growthScore = growthScore(stats: stats)

    return ReviewResult(
      xpGained: gained,
      breakdown: breakdown,
      multiplier: breakdown.multiplier,
      leveledUp: leveledUp,
      oldLevel: oldLevel,
      newLevel: newLevelInfo.level,
      newBadges: newBadges,
      streak: streakUpdate.newStreak,
      streakIncreased: streakUpdate.increased
    )
  }

  static func computeStats(progress: UserProgress, allEntries: [Entry], level: Int) -> GamificationStats {
    let completed = allEntries.filter { $0.isComplete }.count
    let lessons = allEntries.filter { !$0.lesson.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    let adjustmentsDone = allEntries.filter { $0.adjustmentDone }.count
    let totalWords = allEntries.reduce(0) { $0 + $1.wordCount }

    var tagCounts: [String: Int] = [:]
    for e in allEntries {
      for t in e.tags { tagCounts[t.lowercased(), default: 0] += 1 }
    }

    return GamificationStats(
      totalReviews: completed,
      currentStreak: progress.currentStreak,
      longestStreak: progress.longestStreak,
      lessonsCount: lessons,
      adjustmentsCompleted: adjustmentsDone,
      habitCompletions: progress.totalHabitCompletions,
      totalWords: totalWords,
      level: level,
      earlyReviews: progress.earlyReviewCount,
      tagCounts: tagCounts
    )
  }

  /// A compound "growth" score that rewards consistency and depth over volume.
  static func growthScore(stats: GamificationStats) -> Double {
    let base = Double(stats.totalReviews)
    let streakBonus = Double(stats.longestStreak) * 0.5
    let depth = Double(stats.lessonsCount) * 0.3
    return (base + streakBonus + depth).rounded()
  }
}
