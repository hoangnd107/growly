import Foundation

struct StreakUpdate: Equatable {
  let newStreak: Int
  let newLongest: Int
  let increased: Bool
}

enum StreakEngine {
  /// XP multiplier earned from the current streak length.
  static func multiplier(for streak: Int) -> Double {
    if streak >= 30 { return 2.0 }
    if streak >= 7 { return 1.5 }
    return 1.0
  }

  /// The next milestone that unlocks a higher multiplier (nil if maxed).
  static func nextMilestone(for streak: Int) -> Int? {
    if streak < 7 { return 7 }
    if streak < 30 { return 30 }
    return nil
  }

  /// Compute the streak after completing a review on `today`.
  static func update(
    lastReviewDay: Date?,
    currentStreak: Int,
    longestStreak: Int,
    today: Date = Date(),
    calendar: Calendar = .current
  ) -> StreakUpdate {
    let day = calendar.startOfDay(for: today)

    guard let last = lastReviewDay.map({ calendar.startOfDay(for: $0) }) else {
      return StreakUpdate(newStreak: 1, newLongest: max(1, longestStreak), increased: true)
    }

    if last == day {
      // Already reviewed today — no change.
      return StreakUpdate(newStreak: currentStreak, newLongest: longestStreak, increased: false)
    }

    let diff = calendar.dateComponents([.day], from: last, to: day).day ?? 0
    if diff == 1 {
      let s = currentStreak + 1
      return StreakUpdate(newStreak: s, newLongest: max(s, longestStreak), increased: true)
    } else {
      // Missed one or more days — streak restarts.
      return StreakUpdate(newStreak: 1, newLongest: max(1, longestStreak), increased: true)
    }
  }
}
