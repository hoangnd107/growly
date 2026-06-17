import Foundation
import SwiftData

/// A SMART goal: Specific (title) · Measurable (current/target + unit) ·
/// Achievable/Relevant (detail) · Time-bound (deadline).
@Model
final class SmartGoal {
  var id: UUID
  var title: String
  var detail: String
  var unit: String
  var targetValue: Double
  var currentValue: Double
  var deadline: Date?
  var createdAt: Date
  var isCompleted: Bool
  var colorHex: String?

  // v1.10 additions (additive migration; all default-valued):
  var updatedAt: Date = Date()
  /// When the goal was marked complete (nil if never completed). Drives the
  /// "goals completed that day" day-detail section.
  var completedAt: Date? = nil
  /// Soft-delete timestamp (nil = active). Mirrors `DayNote.deletedAt` for the Trash.
  var deletedAt: Date? = nil
  /// Optional free-text category for grouping/filtering (mirrors `DayNote.folder`).
  var category: String? = nil

  init(
    title: String,
    detail: String = "",
    unit: String = "",
    targetValue: Double = 1,
    currentValue: Double = 0,
    deadline: Date? = nil,
    colorHex: String? = nil
  ) {
    self.id = UUID()
    self.title = title
    self.detail = detail
    self.unit = unit
    self.targetValue = targetValue
    self.currentValue = currentValue
    self.deadline = deadline
    self.createdAt = Date()
    self.isCompleted = false
    self.colorHex = colorHex
  }

  var progress: Double {
    guard targetValue > 0 else { return isCompleted ? 1 : 0 }
    return min(1, max(0, currentValue / targetValue))
  }

  var daysRemaining: Int? {
    guard let deadline else { return nil }
    return Calendar.current.dateComponents([.day], from: Date(), to: deadline).day
  }
}
