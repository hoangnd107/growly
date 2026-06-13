import Foundation

enum ChallengePeriod: String {
  case daily
  case weekly
  case seasonal
}

struct Challenge: Identifiable, Equatable {
  let id: String
  let title: String
  let detail: String
  let systemIcon: String
  let xpReward: Int
  let period: ChallengePeriod
}

struct ChallengeProgress: Identifiable, Equatable {
  let challenge: Challenge
  let value: Double          // 0...1
  var isComplete: Bool { value >= 1 }
  var id: String { challenge.id }
}

enum ChallengeEngine {
  static let catalog: [Challenge] = [
    Challenge(id: "daily_measurable_adjustment", title: "Make it measurable", detail: "Write an Adjustment with a number you can track.", systemIcon: "target", xpReward: 25, period: .daily),
    Challenge(id: "daily_full_loop", title: "Close the loop", detail: "Fill in all four reflection fields today.", systemIcon: "circle.dashed", xpReward: 20, period: .daily),
    Challenge(id: "weekly_five_reviews", title: "Five of seven", detail: "Complete a review on 5 of the last 7 days.", systemIcon: "calendar", xpReward: 80, period: .weekly),
    Challenge(id: "weekly_five_habits", title: "Habit momentum", detail: "Complete 5 habits this week.", systemIcon: "checkmark.circle", xpReward: 60, period: .weekly),
  ]

  static func evaluate(
    entries: [Entry],
    todayEntry: Entry?,
    habitCompletionsThisWeek: Int,
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> [ChallengeProgress] {
    let last7 = entries.filter {
      guard let days = calendar.dateComponents([.day], from: $0.day, to: calendar.startOfDay(for: now)).day else { return false }
      return days >= 0 && days < 7
    }
    let completedLast7 = last7.filter { $0.isComplete }.count

    func value(for c: Challenge) -> Double {
      switch c.id {
      case "daily_measurable_adjustment":
        let text = todayEntry?.adjustment ?? ""
        let hasNumber = text.rangeOfCharacter(from: .decimalDigits) != nil
        return hasNumber ? 1 : 0
      case "daily_full_loop":
        let filled = todayEntry?.filledCount ?? 0
        return min(1, Double(filled) / 4.0)
      case "weekly_five_reviews":
        return min(1, Double(completedLast7) / 5.0)
      case "weekly_five_habits":
        return min(1, Double(habitCompletionsThisWeek) / 5.0)
      default:
        return 0
      }
    }

    return catalog.map { ChallengeProgress(challenge: $0, value: value(for: $0)) }
  }
}
