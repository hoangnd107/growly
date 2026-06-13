import Foundation

struct XPLineItem: Identifiable, Equatable {
  let id = UUID()
  let reason: XPReason
  let amount: Int
  let detail: String
}

struct XPBreakdown: Equatable {
  let baseItems: [XPLineItem]
  let multiplier: Double

  var subtotal: Int { baseItems.reduce(0) { $0 + $1.amount } }
  var total: Int { Int((Double(subtotal) * multiplier).rounded()) }
  var bonusFromMultiplier: Int { total - subtotal }
}

/// Pure XP math for a completed daily review.
enum XPEngine {
  static let dailyReviewXP = 50
  static let earlyBonusXP = 20
  static let qualityFieldXP = 12
  static let morningIntentionXP = 10

  /// Reviews completed before this hour earn the early-bird bonus.
  static let earlyCutoffHour = 20
  /// A reflection field counts as "quality" at or above this many words.
  static let qualityWordThreshold = 4

  static func isQuality(_ text: String) -> Bool {
    text.split(whereSeparator: { $0 == " " || $0 == "\n" }).count >= qualityWordThreshold
  }

  static func reviewBreakdown(
    entry: Entry,
    habitsCompleted: [Habit],
    streak: Int,
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> XPBreakdown {
    var items: [XPLineItem] = [
      XPLineItem(reason: .dailyReview, amount: dailyReviewXP, detail: "Daily review"),
    ]

    let hour = calendar.component(.hour, from: now)
    if hour < earlyCutoffHour {
      items.append(XPLineItem(reason: .earlyBonus, amount: earlyBonusXP, detail: "Early bird bonus"))
    }

    for kind in ReflectionKind.allCases where isQuality(entry.text(for: kind)) {
      items.append(XPLineItem(reason: .qualityField, amount: qualityFieldXP, detail: "Quality \(kind.title)"))
    }

    if !entry.morningIntention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      items.append(XPLineItem(reason: .morningIntention, amount: morningIntentionXP, detail: "Morning intention"))
    }

    for habit in habitsCompleted {
      items.append(XPLineItem(reason: .habitComplete, amount: habit.xpValue, detail: habit.name))
    }

    return XPBreakdown(baseItems: items, multiplier: StreakEngine.multiplier(for: streak))
  }
}
