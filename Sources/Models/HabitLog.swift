import Foundation
import SwiftData

@Model
final class HabitLog {
  var id: UUID
  var date: Date
  var completed: Bool
  var habit: Habit?

  init(date: Date = Date(), completed: Bool = true, habit: Habit? = nil) {
    self.id = UUID()
    self.date = Calendar.current.startOfDay(for: date)
    self.completed = completed
    self.habit = habit
  }
}
