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
    self.quality = quality
    self.note = note
  }

  /// Hours slept; if wake is "before" bed (clock-wise) it crossed midnight.
  var durationHours: Double {
    var interval = wakeTime.timeIntervalSince(bedTime)
    if interval < 0 { interval += 86_400 }
    return interval / 3_600
  }
}
