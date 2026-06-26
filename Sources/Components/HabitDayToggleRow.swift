import SwiftUI
import SwiftData

/// A tappable habit row that marks a habit complete (or undoes it) for a given day.
///
/// The checkmark is driven by **optimistic local state** so it flips the instant
/// you tap — instead of waiting for the SwiftData write and the resulting `@Query`
/// refresh to propagate back, which made ticking a habit feel laggy. The model is
/// updated and saved right after, in the same run loop, but the UI no longer waits
/// on it. View identity is stable (keyed by `habit.id` in the enclosing `ForEach`),
/// so the local state survives the parent's re-render.
struct HabitDayToggleRow: View {
  @Environment(\.modelContext) private var context
  let habit: Habit
  let day: Date

  @State private var done: Bool

  init(habit: Habit, day: Date) {
    self.habit = habit
    self.day = day
    _done = State(initialValue: habit.isCompleted(on: day))
  }

  var body: some View {
    Button(action: toggle) {
      HStack(spacing: DLSpace.md) {
        Text(habit.emoji.isEmpty ? "✅" : habit.emoji)
          .font(.system(size: 24))
        Text(habit.name)
          .font(.dl(.body))
          .foregroundStyle(DLColor.textPrimary)
          .lineLimit(1)
        Spacer(minLength: DLSpace.sm)
        Text("+\(habit.xpValue)")
          .font(.dl(.caption2, weight: .semibold))
          .foregroundStyle(DLColor.xpGold)
        Image(systemName: done ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 26))
          .foregroundStyle(done ? DLColor.success : DLColor.textTertiary)
          .contentTransition(.symbolEffect(.replace))
      }
      .padding(.vertical, DLSpace.sm)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(habit.name)
    .accessibilityValue(done ? L("Done") : "")
  }

  private func toggle() {
    done.toggle()
    Haptics.selection()
    let target = Calendar.current.startOfDay(for: day)
    if let log = habit.logs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: target) }) {
      log.completed = done
    } else {
      context.insert(HabitLog(date: target, completed: done, habit: habit))
    }
    try? context.save()
  }
}
