import XCTest
@testable import Growly

final class GamificationTests: XCTestCase {

  // MARK: Levels

  func testLevelStartsAtOne() {
    XCTAssertEqual(LevelSystem.levelInfo(totalXP: 0).level, 1)
  }

  func testLevelRequirements() {
    XCTAssertEqual(LevelSystem.requirement(toReach: 1), 0)
    XCTAssertEqual(LevelSystem.requirement(toReach: 2), 100)
    XCTAssertEqual(LevelSystem.requirement(toReach: 3), 125)
  }

  func testLevelProgression() {
    let info = LevelSystem.levelInfo(totalXP: 100)
    XCTAssertEqual(info.level, 2)
    XCTAssertEqual(info.xpIntoLevel, 0)
    XCTAssertEqual(info.xpForNextLevel, 125)

    let mid = LevelSystem.levelInfo(totalXP: 160)
    XCTAssertEqual(mid.level, 2)
    XCTAssertEqual(mid.xpIntoLevel, 60)
    XCTAssertEqual(mid.progress, 60.0 / 125.0, accuracy: 0.0001)
  }

  // MARK: Streaks

  func testStreakMultiplier() {
    XCTAssertEqual(StreakEngine.multiplier(for: 1), 1.0)
    XCTAssertEqual(StreakEngine.multiplier(for: 6), 1.0)
    XCTAssertEqual(StreakEngine.multiplier(for: 7), 1.5)
    XCTAssertEqual(StreakEngine.multiplier(for: 29), 1.5)
    XCTAssertEqual(StreakEngine.multiplier(for: 30), 2.0)
  }

  func testStreakUpdate() {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
    let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: today)!

    XCTAssertEqual(StreakEngine.update(lastReviewDay: nil, currentStreak: 0, longestStreak: 0, today: today).newStreak, 1)

    let continued = StreakEngine.update(lastReviewDay: yesterday, currentStreak: 3, longestStreak: 3, today: today)
    XCTAssertEqual(continued.newStreak, 4)
    XCTAssertEqual(continued.newLongest, 4)
    XCTAssertTrue(continued.increased)

    let broken = StreakEngine.update(lastReviewDay: twoDaysAgo, currentStreak: 5, longestStreak: 8, today: today)
    XCTAssertEqual(broken.newStreak, 1)
    XCTAssertEqual(broken.newLongest, 8)

    let sameDay = StreakEngine.update(lastReviewDay: today, currentStreak: 4, longestStreak: 6, today: today)
    XCTAssertEqual(sameDay.newStreak, 4)
    XCTAssertFalse(sameDay.increased)
  }

  // MARK: XP

  private func dateAt(hour: Int) -> Date {
    var comps = DateComponents()
    comps.year = 2026; comps.month = 6; comps.day = 14; comps.hour = hour
    return Calendar.current.date(from: comps)!
  }

  func testXPEarlyAndQuality() {
    let entry = Entry(win: "I shipped the project on time", mistake: "", lesson: "", adjustment: "")
    let breakdown = XPEngine.reviewBreakdown(entry: entry, habitsCompleted: [], streak: 1, now: dateAt(hour: 9))
    // base 50 + early 20 + quality win 12 = 82
    XCTAssertEqual(breakdown.subtotal, 82)
    XCTAssertEqual(breakdown.total, 82)
  }

  func testXPLateWithStreakMultiplier() {
    let entry = Entry(win: "a solid win right here", mistake: "", lesson: "", adjustment: "")
    let breakdown = XPEngine.reviewBreakdown(entry: entry, habitsCompleted: [], streak: 7, now: dateAt(hour: 22))
    // late: base 50 + quality 12 = 62, x1.5 = 93
    XCTAssertEqual(breakdown.subtotal, 62)
    XCTAssertEqual(breakdown.total, 93)
  }

  // MARK: Badges

  func testFirstReflectionBadge() {
    let stats = GamificationStats(totalReviews: 1, currentStreak: 1, longestStreak: 1, lessonsCount: 0, adjustmentsCompleted: 0, habitCompletions: 0, totalWords: 0, noteCount: 0, level: 1, earlyReviews: 0, tagCounts: [:])
    XCTAssertTrue(BadgeEngine.earnedBadgeIDs(stats).contains("first_reflection"))
  }

  func testStreakBadges() {
    var stats = GamificationStats(totalReviews: 10, currentStreak: 7, longestStreak: 7, lessonsCount: 0, adjustmentsCompleted: 0, habitCompletions: 0, totalWords: 0, noteCount: 0, level: 3, earlyReviews: 0, tagCounts: [:])
    XCTAssertTrue(BadgeEngine.earnedBadgeIDs(stats).contains("sage_7"))
    XCTAssertFalse(BadgeEngine.earnedBadgeIDs(stats).contains("perfectionist_30"))
    stats.longestStreak = 30
    XCTAssertTrue(BadgeEngine.earnedBadgeIDs(stats).contains("perfectionist_30"))
  }

  func testBadgeProgress() {
    let stats = GamificationStats(totalReviews: 0, currentStreak: 0, longestStreak: 15, lessonsCount: 0, adjustmentsCompleted: 0, habitCompletions: 0, totalWords: 0, noteCount: 0, level: 1, earlyReviews: 0, tagCounts: [:])
    XCTAssertEqual(BadgeEngine.progress(for: "perfectionist_30", stats: stats), 0.5, accuracy: 0.0001)
  }
}
