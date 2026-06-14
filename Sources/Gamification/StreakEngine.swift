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
  ///
  /// `frozenDays` are days the user protected with a Streak Freeze: if every
  /// missed day between the last review and today is frozen, the streak bridges
  /// the gap instead of resetting.
  static func update(
    lastReviewDay: Date?,
    currentStreak: Int,
    longestStreak: Int,
    frozenDays: Set<Date> = [],
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
    if diff <= 0 {
      // Reviewing for a day before the last review — leave the streak untouched.
      return StreakUpdate(newStreak: currentStreak, newLongest: longestStreak, increased: false)
    }

    // Are all the missed days (strictly between last and today) frozen?
    let frozen = Set(frozenDays.map { calendar.startOfDay(for: $0) })
    var bridged = true
    if diff > 1 {
      for offset in 1..<diff {
        guard let gapDay = calendar.date(byAdding: .day, value: offset, to: last) else { continue }
        if !frozen.contains(calendar.startOfDay(for: gapDay)) { bridged = false; break }
      }
    }

    if diff == 1 || bridged {
      let s = currentStreak + 1
      return StreakUpdate(newStreak: s, newLongest: max(s, longestStreak), increased: true)
    } else {
      // A non-frozen day was missed — streak restarts.
      return StreakUpdate(newStreak: 1, newLongest: max(1, longestStreak), increased: true)
    }
  }
}
