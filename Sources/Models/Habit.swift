import Foundation
import SwiftData

@Model
final class Habit {
  var id: UUID
  var name: String
  var emoji: String
  var colorHex: String
  var createdAt: Date
  var isArchived: Bool
  var sortIndex: Int
  /// XP awarded each time this habit is completed (10–20).
  var xpValue: Int

  /// When set, the habit is in the Trash (soft-deleted) — restorable until purged.
  /// Additive migration: older habits default to nil (active).
  var deletedAt: Date? = nil

  @Relationship(deleteRule: .cascade, inverse: \HabitLog.habit)
  var logs: [HabitLog]

  init(
    name: String,
    emoji: String = "✅",
    colorHex: String = "7E5BEF",
    xpValue: Int = 12,
    sortIndex: Int = 0
  ) {
    self.id = UUID()
    self.name = name
    self.emoji = emoji
    self.colorHex = colorHex
    self.createdAt = Date()
    self.isArchived = false
    self.sortIndex = sortIndex
    self.xpValue = xpValue
    self.logs = []
  }

  /// Whether this habit has a completed log on the given day.
  func isCompleted(on day: Date, calendar: Calendar = .current) -> Bool {
    let target = calendar.startOfDay(for: day)
    return logs.contains { $0.completed && calendar.isDate($0.date, inSameDayAs: target) }
  }
}
