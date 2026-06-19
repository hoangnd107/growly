import SwiftUI
import SwiftData
import Charts

// MARK: - Complete the Day streak (feature 13)

/// Insights card for the "Complete the Day" streak — consecutive days with a full
/// Win/Mistake/Lesson/Adjustment review. Distinct from the activity streak card.
struct CompleteDayStreakCard: View {
  @Query(sort: \Entry.day, order: .reverse) private var entries: [Entry]
  @Query private var notes: [DayNote]
  @Query private var progressList: [UserProgress]

  private var streak: DetailedStreak {
    StreakBundle.compute(entries: entries, notes: notes).completeDay
  }

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Label(L("Complete the Day Streak"), systemImage: "checkmark.seal.fill")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(CalendarDayMark.completeColor)

        HStack(spacing: 0) {
          metric(value: streak.current.length, label: L("Current"), tint: CalendarDayMark.completeColor)
          divider
          metric(value: streak.longest.length, label: L("Longest"), tint: DLColor.streakEnd)
        }

        Text(L("Counts every day you completed all four reflection fields."))
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
      }
    }
  }

  private func metric(value: Int, label: String, tint: Color) -> some View {
    VStack(spacing: DLSpace.xs) {
      Text("\(value)")
        .font(.system(.title, design: .rounded).weight(.bold))
        .monospacedDigit()
        .foregroundStyle(DLColor.textPrimary)
      Text(value == 1 ? L("day") : L("days"))
        .font(.dl(.caption2, weight: .medium))
        .foregroundStyle(DLColor.textTertiary)
      Text(label)
        .font(.dl(.caption2, weight: .semibold))
        .foregroundStyle(DLColor.textSecondary)
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(label): \(value)")
  }

  private var divider: some View {
    Rectangle().fill(DLColor.separator.opacity(0.6)).frame(width: 1, height: 56)
  }
}

// MARK: - Habit statistics with range filter (feature 13)

/// Per-habit completion stats over a selectable time range, with a mini bar for
/// each habit's completion rate.
struct HabitStatsCard: View {
  @Query(sort: \Habit.sortIndex) private var habits: [Habit]
  @Query private var habitLogs: [HabitLog]
  @Query private var progressList: [UserProgress]
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var range: HabitRange = .month

  private let calendar = Calendar.current
  private var today: Date { calendar.startOfDay(for: Date()) }

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  enum HabitRange: Int, CaseIterable, Identifiable {
    case week = 7
    case twoWeeks = 14
    case month = 30
    case quarter = 90
    case year = 365
    case all = 0
    var id: Int { rawValue }
    var label: String {
      switch self {
      case .week: return L("7 days")
      case .twoWeeks: return L("14 days")
      case .month: return L("30 days")
      case .quarter: return L("90 days")
      case .year: return L("1 year")
      case .all: return L("All time")
      }
    }
  }

  private var activeHabits: [Habit] {
    habits.filter { $0.deletedAt == nil && !$0.isArchived }
  }

  /// Number of days in the current range (all-time spans from the first habit log).
  private var rangeDays: Int {
    if range == .all {
      let earliest = habitLogs.map { calendar.startOfDay(for: $0.date) }.min()
      if let earliest {
        let diff = calendar.dateComponents([.day], from: earliest, to: today).day ?? 0
        return max(1, diff + 1)
      }
      return 1
    }
    return range.rawValue
  }

  private var rangeStart: Date? {
    if range == .all { return nil }
    return calendar.date(byAdding: .day, value: -(range.rawValue - 1), to: today)
  }

  private func completions(for habit: Habit) -> Int {
    habit.logs.filter { log in
      guard log.completed else { return false }
      let day = calendar.startOfDay(for: log.date)
      if let start = rangeStart { return day >= start && day <= today }
      return day <= today
    }.count
  }

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        header

        if activeHabits.isEmpty {
          Text(L("Add habits to see their completion stats here."))
            .font(.dl(.caption))
            .foregroundStyle(DLColor.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DLSpace.xs)
        } else {
          ForEach(activeHabits) { habit in
            habitRow(habit)
          }
        }
      }
    }
    .animation(reduceMotion ? nil : DLAnim.standard, value: range)
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      Label(L("Habit statistics"), systemImage: "checklist")
        .font(.dl(.headline, weight: .semibold))
        .foregroundStyle(DLColor.success)
      Spacer()
      Menu {
        Picker(L("Range"), selection: $range) {
          ForEach(HabitRange.allCases) { option in
            Text(option.label).tag(option)
          }
        }
      } label: {
        HStack(spacing: 3) {
          Text(range.label)
            .font(.dl(.caption, weight: .semibold))
          Image(systemName: "chevron.up.chevron.down")
            .font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(DLColor.success)
        .padding(.horizontal, DLSpace.sm)
        .padding(.vertical, 4)
        .background(DLColor.success.opacity(0.12), in: Capsule())
      }
      .accessibilityLabel(Lf("Range: %@", range.label))
    }
  }

  private func habitRow(_ habit: Habit) -> some View {
    let done = completions(for: habit)
    let total = max(1, rangeDays)
    let rate = min(1.0, Double(done) / Double(total))
    return VStack(alignment: .leading, spacing: DLSpace.xs) {
      HStack(spacing: DLSpace.sm) {
        Text(habit.emoji.isEmpty ? "✅" : habit.emoji)
        Text(habit.name)
          .font(.dl(.subheadline, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)
          .lineLimit(1)
        Spacer(minLength: DLSpace.sm)
        Text(Lf("%d/%d days", done, total))
          .font(.dl(.caption2, weight: .medium))
          .foregroundStyle(DLColor.textSecondary)
          .monospacedDigit()
        Text("\(Int(rate * 100))%")
          .font(.dl(.caption, weight: .bold))
          .foregroundStyle(Color(hexString: habit.colorHex))
          .monospacedDigit()
      }
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule().fill(DLColor.separator.opacity(0.3))
          Capsule()
            .fill(Color(hexString: habit.colorHex))
            .frame(width: max(4, geo.size.width * rate))
        }
      }
      .frame(height: 8)
    }
    .padding(.vertical, 2)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Lf("%@: %d of %d days, %d percent", habit.name, done, total, Int(rate * 100)))
  }
}
