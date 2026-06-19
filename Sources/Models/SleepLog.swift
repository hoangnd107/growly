import Foundation
import SwiftData

/// A night's sleep: bed/wake time + a 1...5 quality rating.
@Model
final class SleepLog {
  var id: UUID
  /// The night this log belongs to (normalized to start of day).
  var date: Date
  var bedTime: Date
  var wakeTime: Date
  var quality: Int
  var note: String

  init(date: Date = Date(), bedTime: Date, wakeTime: Date, quality: Int = 3, note: String = "") {
    self.id = UUID()
    self.date = Calendar.current.startOfDay(for: date)
    self.bedTime = bedTime
    self.wakeTime = wakeTime
    // Quality is derived from duration (science-based), never set manually.
    self.quality = SleepLog.quality(forHours: SleepLog.hours(bedTime: bedTime, wakeTime: wakeTime))
    self.note = note
  }

  /// Hours between bed and wake (crossing midnight if needed). Static so callers
  /// can compute a prospective duration before a log exists.
  static func hours(bedTime: Date, wakeTime: Date) -> Double {
    var interval = wakeTime.timeIntervalSince(bedTime)
    if interval < 0 { interval += 86_400 }
    return interval / 3_600
  }

  /// Hours slept; if wake is "before" bed (clock-wise) it crossed midnight.
  var durationHours: Double {
    SleepLog.hours(bedTime: bedTime, wakeTime: wakeTime)
  }

  /// Re-derive and store `quality` from the current bed/wake times. Call after
  /// editing the times so the stored value (used by averages/queries) stays in sync.
  func refreshQuality() {
    quality = SleepLog.quality(forHours: durationHours)
  }

  /// Quality computed live from the current duration (1...5). Display sites should
  /// prefer this over the stored `quality` so legacy/manual values are superseded.
  var computedQuality: Int { SleepLog.quality(forHours: durationHours) }

  /// Short label for the computed quality, e.g. "Good".
  var qualityLabel: String { SleepLog.qualityLabel(for: computedQuality) }

  /// Science-based sleep-quality score (1...5) from duration in hours.
  /// <5h Very Poor · 5–6h Poor · 6–7h Fair · 7–9h Good · 9–10h Excellent · >10h Fair (oversleep).
  static func quality(forHours hours: Double) -> Int {
    switch hours {
    case ..<5: return 1
    case 5..<6: return 2
    case 6..<7: return 3
    case 7..<9: return 4
    case 9..<10: return 5
    default: return 3   // >10h — oversleeping
    }
  }

  static func qualityLabel(for score: Int) -> String {
    switch score {
    case 1: return L("Very Poor")
    case 2: return L("Poor")
    case 3: return L("Fair")
    case 4: return L("Good")
    default: return L("Excellent")
    }
  }
}
