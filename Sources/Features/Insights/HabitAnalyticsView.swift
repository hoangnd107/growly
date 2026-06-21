import SwiftUI
import SwiftData

// MARK: - Habit Analytics
//
// Per-habit analytics report shown as a full calendar year (item 4), matching
// the Consistency heatmap. A shared YearStepper scopes every card to one year;
// each card shows a completion-rate pill, a 53-week heatmap tinted with the
// habit's own color, and a caption summarizing that year's completions, best
// streak, and strongest weekday.
//
// Self-contained: fetches its own habits via @Query, so it can be pushed with
// `HabitAnalyticsView()` from any NavigationLink inside an existing stack.

struct HabitAnalyticsView: View {
  @Query private var habits: [Habit]
  @State private var selectedYear = Calendar.current.component(.year, from: Date())

  private let calendar = Calendar.current

  /// Active habits only (not archived, not trashed), in display order.
  private var activeHabits: [Habit] {
    habits
      .filter { !$0.isArchived && $0.deletedAt == nil }
      .sorted { $0.sortIndex < $1.sortIndex }
  }

  /// Years that have any completion across all active habits, plus the current
  /// year — for the stepper bounds.
  private var availableYears: [Int] {
    var ys = Set<Int>()
    for habit in activeHabits {
      for log in habit.logs where log.completed {
        ys.insert(calendar.component(.year, from: log.date))
      }
    }
    ys.insert(calendar.component(.year, from: Date()))
    return ys.sorted()
  }

  private var minYear: Int { availableYears.min() ?? selectedYear }
  private var maxYear: Int { calendar.component(.year, from: Date()) }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DLSpace.lg) {
        EditorialHeader("ANALYTICS", L("Habits")) {
          YearStepper(year: $selectedYear, minYear: minYear, maxYear: maxYear)
        }

        Hairline()

        if activeHabits.isEmpty {
          emptyState
        } else {
          ForEach(activeHabits) { habit in
            HabitAnalyticsCard(habit: habit, year: selectedYear)
          }
        }
      }
      .padding(.horizontal, DLSpace.lg)
      .padding(.vertical, DLSpace.lg)
    }
    .background(ThemedBackground())
    .navigationBarTitleDisplayMode(.inline)
    .animation(.default, value: selectedYear)
    .onAppear {
      if !availableYears.contains(selectedYear), let latest = availableYears.last {
        selectedYear = latest
      }
    }
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
  let year: Int

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

  /// Completed days falling inside `year`.
  private var completedDaysInYear: Set<Date> {
    completedDays.filter { calendar.component(.year, from: $0) == year }
  }

  /// Days counted toward the completion rate for `year`: the whole year for past
  /// years, Jan 1…today for the current year, 1 for a future year.
  private var yearDayCount: Int {
    let nowYear = calendar.component(.year, from: Date())
    guard let jan1 = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else { return 365 }
    if year > nowYear { return 1 }
    let end: Date
    if year < nowYear {
      end = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) ?? jan1
    } else {
      end = calendar.startOfDay(for: Date())
    }
    return max(1, (calendar.dateComponents([.day], from: jan1, to: end).day ?? 0) + 1)
  }

  private var completionRate: Double {
    Double(completedDaysInYear.count) / Double(yearDayCount)
  }

  /// Longest run of consecutive completed days within `year`.
  private var bestStreakInYear: Int {
    DetailedStreak.compute(days: completedDaysInYear).longest.length
  }

  /// Localized name of the weekday with the most completions in `year`, or nil.
  private var bestWeekday: String? {
    let days = completedDaysInYear
    guard !days.isEmpty else { return nil }
    var counts: [Int: Int] = [:]
    for day in days {
      counts[calendar.component(.weekday, from: day), default: 0] += 1
    }
    guard let topWeekday = counts.max(by: { $0.value < $1.value })?.key else { return nil }
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
        YearActivityHeatmap(year: year) { day in
          completedDays.contains(day) ? habitColor : DLColor.separator.opacity(0.35)
        }
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
      .accessibilityLabel(Lf("%d percent complete this year", percent))
  }

  private var captionRow: some View {
    HStack(spacing: DLSpace.md) {
      captionStat(value: "\(completedDaysInYear.count)", label: L("Completed"))
      captionStat(value: "\(bestStreakInYear)", label: L("Best streak"))
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
