import SwiftUI
import SwiftData

// MARK: - Habit Analytics
//
// Per-habit analytics report: a range filter at the top, then one editorial
// GlassCard per active habit. Each card shows a completion-rate pill, an
// 84-day calendar heatmap tinted with the habit's own color, and a caption
// summarizing current streak, best streak, and the strongest weekday.
//
// Self-contained: fetches its own habits via @Query, so it can be pushed with
// `HabitAnalyticsView()` from any NavigationLink inside an existing stack.

struct HabitAnalyticsView: View {
  @Query private var habits: [Habit]
  @State private var range: StatsRange = .month

  /// Active habits only (not archived, not trashed), in display order.
  private var activeHabits: [Habit] {
    habits
      .filter { !$0.isArchived && $0.deletedAt == nil }
      .sorted { $0.sortIndex < $1.sortIndex }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DLSpace.lg) {
        EditorialHeader("ANALYTICS", L("Habits"))

        SlidingSegmentedControl(
          items: StatsRange.allCases,
          label: { $0.label },
          selection: $range,
          accent: DLColor.accent
        )

        Hairline()

        if activeHabits.isEmpty {
          emptyState
        } else {
          ForEach(activeHabits) { habit in
            HabitAnalyticsCard(habit: habit, range: range)
          }
        }
      }
      .padding(.horizontal, DLSpace.lg)
      .padding(.vertical, DLSpace.lg)
    }
    .background(ThemedBackground())
    .navigationBarTitleDisplayMode(.inline)
  }

  private var emptyState: some View {
    VStack(spacing: DLSpace.sm) {
      Text("📊").font(.system(size: 44))
      Text(L("No habits yet"))
        .font(.serif(.title3, weight: .semibold))
        .foregroundStyle(DLColor.textPrimary)
      Text(L("Create a habit to see its analytics here."))
        .font(.dl(.subheadline))
        .foregroundStyle(DLColor.textSecondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, DLSpace.xl)
  }
}

// MARK: - Per-habit card

private struct HabitAnalyticsCard: View {
  let habit: Habit
  let range: StatsRange

  private let calendar = Calendar.current

  /// The habit's accent color, parsed from its stored hex string.
  private var habitColor: Color { Color(hexString: habit.colorHex) }

  // MARK: Derived data

  /// Set of days (start-of-day) on which this habit was completed.
  private var completedDays: Set<Date> {
    Set(
      habit.logs
        .filter { $0.completed }
        .map { calendar.startOfDay(for: $0.date) }
    )
  }

  /// Days included by the current range: from the range start (or first log)
  /// through today, inclusive.
  private var rangeDays: [Date] {
    let today = calendar.startOfDay(for: Date())
    let start: Date
    if let rangeStart = range.startDate(now: today, calendar: calendar) {
      start = calendar.startOfDay(for: rangeStart)
    } else {
      // .all — fall back to the earliest completed day, or today if none.
      start = completedDays.min() ?? today
    }
    guard start <= today else { return [today] }
    var days: [Date] = []
    var cursor = start
    while cursor <= today {
      days.append(cursor)
      guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
      cursor = next
    }
    return days
  }

  /// Completed days inside the current range.
  private var completedInRange: Int {
    let completed = completedDays
    return rangeDays.reduce(0) { $0 + (completed.contains($1) ? 1 : 0) }
  }

  /// Completion rate over the range, 0...1.
  private var completionRate: Double {
    guard !rangeDays.isEmpty else { return 0 }
    return Double(completedInRange) / Double(rangeDays.count)
  }

  /// The most-recent 84 days (12 weeks), oldest first, most recent last.
  private var heatmapDays: [Date] {
    let today = calendar.startOfDay(for: Date())
    return (0..<84)
      .compactMap { calendar.date(byAdding: .day, value: -(83 - $0), to: today) }
  }

  /// Current streak: consecutive completed days ending today (or yesterday).
  private var currentStreak: Int {
    let completed = completedDays
    let today = calendar.startOfDay(for: Date())
    // Allow the streak to still be "alive" if today isn't logged yet.
    var cursor: Date
    if completed.contains(today) {
      cursor = today
    } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              completed.contains(yesterday) {
      cursor = yesterday
    } else {
      return 0
    }
    var streak = 0
    while completed.contains(cursor) {
      streak += 1
      guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
      cursor = prev
    }
    return streak
  }

  /// Longest run of consecutive completed days across all history.
  private var bestStreak: Int {
    let sorted = completedDays.sorted()
    guard !sorted.isEmpty else { return 0 }
    var best = 1
    var run = 1
    for i in 1..<sorted.count {
      if let prev = calendar.date(byAdding: .day, value: 1, to: sorted[i - 1]),
         calendar.isDate(prev, inSameDayAs: sorted[i]) {
        run += 1
      } else {
        run = 1
      }
      best = max(best, run)
    }
    return best
  }

  /// Localized name of the weekday with the most completions, or nil if none.
  private var bestWeekday: String? {
    guard !completedDays.isEmpty else { return nil }
    var counts: [Int: Int] = [:]
    for day in completedDays {
      let wd = calendar.component(.weekday, from: day)
      counts[wd, default: 0] += 1
    }
    guard let topWeekday = counts.max(by: { $0.value < $1.value })?.key else { return nil }
    // weekday is 1-based; symbols array is 0-based.
    let symbols = calendar.weekdaySymbols
    let index = topWeekday - 1
    guard symbols.indices.contains(index) else { return nil }
    return symbols[index]
  }

  // MARK: Body

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        headerRow
        heatmap
        captionRow
      }
    }
  }

  private var headerRow: some View {
    HStack(spacing: DLSpace.sm) {
      Text(habit.emoji)
        .font(.system(size: 24))
      Text(habit.name)
        .font(.serif(.title3, weight: .semibold))
        .foregroundStyle(DLColor.textPrimary)
        .lineLimit(1)
      Spacer(minLength: DLSpace.sm)
      completionPill
    }
  }

  private var completionPill: some View {
    let percent = Int((completionRate * 100).rounded())
    return Text("\(percent)%")
      .font(.dl(.caption, weight: .bold))
      .monospacedDigit()
      .foregroundStyle(habitColor)
      .padding(.horizontal, DLSpace.sm)
      .padding(.vertical, DLSpace.xs)
      .background(habitColor.opacity(0.14), in: Capsule())
      .overlay(Capsule().strokeBorder(habitColor.opacity(0.35), lineWidth: 1))
      .accessibilityLabel(Lf("%d percent complete this period", percent))
  }

  // 12 columns x 7 rows. Column-major so each column is one week, time flows
  // left-to-right; most recent day lands in the last filled cell.
  private var heatmap: some View {
    let days = heatmapDays
    let completed = completedDays
    let columns = 12
    let rows = 7
    return Grid(horizontalSpacing: 3, verticalSpacing: 3) {
      ForEach(0..<rows, id: \.self) { row in
        GridRow {
          ForEach(0..<columns, id: \.self) { col in
            let index = col * rows + row
            if index < days.count {
              let day = days[index]
              RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(completed.contains(day) ? habitColor : DLColor.separator)
                .frame(height: 14)
            } else {
              Color.clear.frame(height: 14)
            }
          }
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Lf("%d of last 84 days completed", days.filter { completed.contains($0) }.count))
  }

  private var captionRow: some View {
    HStack(spacing: DLSpace.md) {
      captionStat(value: "\(currentStreak)", label: L("Current streak"))
      captionStat(value: "\(bestStreak)", label: L("Best streak"))
      captionStat(value: bestWeekday ?? "—", label: L("Best day"))
    }
  }

  private func captionStat(value: String, label: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value)
        .font(.serif(.body, weight: .semibold))
        .foregroundStyle(DLColor.textPrimary)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      Text(label)
        .font(.dl(.caption2))
        .foregroundStyle(DLColor.textTertiary)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
