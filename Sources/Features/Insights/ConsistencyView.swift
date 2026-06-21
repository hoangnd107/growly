import SwiftUI
import SwiftData

// MARK: - Consistency (year activity heatmap)

/// A year-long, GitHub-contributions-style heatmap of the days you journaled.
/// A day counts when it has a reflection (`Entry`) OR a non-deleted note
/// (`DayNote`). Self-contained: fetches its own data with `@Query`, so it can be
/// pushed via `NavigationLink { ConsistencyView() }`.
///
/// Pure `Calendar` math, no Charts dependency — the heatmap is a grid of tiny
/// rounded cells (53 week-columns × 7 day-rows for the trailing ~1 year).
struct ConsistencyView: View {
  @Query(sort: \Entry.day, order: .reverse) private var entries: [Entry]
  @Query private var notes: [DayNote]
  @Query private var progressList: [UserProgress]

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var progress: UserProgress? { progressList.first }

  // MARK: Derived data (computed once per render)

  /// The set of active days: Entry.day ∪ non-deleted DayNote.day, normalized to
  /// start-of-day. Built once and shared by the headline stats and the heatmap.
  private var activeDays: Set<Date> {
    let calendar = Calendar.current
    var days = Set<Date>()
    days.reserveCapacity(entries.count + notes.count)
    for entry in entries { days.insert(calendar.startOfDay(for: entry.day)) }
    for note in notes where note.deletedAt == nil {
      days.insert(calendar.startOfDay(for: note.day))
    }
    return days
  }

  private var streakStats: StreakStats {
    StreakStats.compute(
      entries: entries,
      notes: notes,
      frozenDays: progress?.streakFreezeDates ?? [],
      weekStartsMonday: progress?.weekStartsMonday ?? true
    )
  }

  /// How many of the active days fall in the current calendar year.
  private func daysThisYear(_ days: Set<Date>, calendar: Calendar, now: Date) -> Int {
    let year = calendar.component(.year, from: now)
    return days.filter { calendar.component(.year, from: $0) == year }.count
  }

  /// Total days elapsed so far in the current year (Jan 1 … today, inclusive),
  /// used as the denominator for the "% of year" tile.
  private func daysElapsedThisYear(calendar: Calendar, now: Date) -> Int {
    let today = calendar.startOfDay(for: now)
    let comps = DateComponents(year: calendar.component(.year, from: today), month: 1, day: 1)
    guard let jan1 = calendar.date(from: comps) else { return 1 }
    let elapsed = (calendar.dateComponents([.day], from: jan1, to: today).day ?? 0) + 1
    return max(1, elapsed)
  }

  var body: some View {
    let calendar = Calendar.current
    let now = Date()
    let days = activeDays
    let stats = streakStats
    let thisYear = daysThisYear(days, calendar: calendar, now: now)
    let elapsed = daysElapsedThisYear(calendar: calendar, now: now)
    let percent = Int((Double(thisYear) / Double(elapsed) * 100).rounded())

    ScrollView {
      VStack(alignment: .leading, spacing: DLSpace.lg) {
        EditorialHeader(L("CONSISTENCY"), L("Consistency"))

        // 1) Headline ledger.
        StatTileGrid(tiles: [
          StatTileData(
            value: "\(thisYear)",
            label: L("Days this year"),
            sublabel: Lf("of %d", elapsed)
          ),
          StatTileData(
            value: "\(percent)%",
            label: L("Of the year"),
            tint: DLColor.accent
          ),
          StatTileData(
            value: "\(stats.currentDaily)",
            label: L("Current streak"),
            sublabel: L("days"),
            tint: DLColor.streakStart
          ),
          StatTileData(
            value: "\(stats.longestDaily)",
            label: L("Longest streak"),
            sublabel: L("days"),
            tint: DLColor.streakEnd
          ),
        ])

        Hairline()

        // 2) The year heatmap.
        SectionLabel(L("This year"))

        YearHeatmap(activeDays: days, reduceMotion: reduceMotion)

        // 3) What counts.
        Text(L("Each cell is a day. A day is filled when you wrote a reflection or any note."))
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(DLSpace.lg)
    }
    .background(ThemedBackground())
    .navigationBarTitleDisplayMode(.inline)
  }
}

// MARK: - Year heatmap

/// A 53-week × 7-day grid for the trailing ~1 year. The rightmost column is the
/// week containing today; rows run from the calendar's first weekday. Active
/// days are tinted with the accent (two levels: today's week pops slightly),
/// inactive days use a faint separator. Scrolls horizontally if it overflows.
private struct YearHeatmap: View {
  let activeDays: Set<Date>
  let reduceMotion: Bool

  /// Number of week columns (~1 year).
  private let weekCount = 53
  private let cell: CGFloat = 11
  private let gap: CGFloat = 3

  private let calendar = Calendar.current

  var body: some View {
    let weeks = buildWeeks()

    ScrollView(.horizontal, showsIndicators: false) {
      VStack(alignment: .leading, spacing: gap) {
        monthLabels(for: weeks)
        HStack(alignment: .top, spacing: gap) {
          ForEach(weeks) { week in
            VStack(spacing: gap) {
              ForEach(week.days) { day in
                cellView(day)
              }
            }
          }
        }
      }
      .padding(.vertical, DLSpace.xs)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilitySummary(weeks: weeks))
  }

  // MARK: Cells

  private func cellView(_ day: HeatmapDay) -> some View {
    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
      .fill(fill(for: day))
      .frame(width: cell, height: cell)
      .overlay(
        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
          .strokeBorder(DLColor.separator.opacity(0.25), lineWidth: day.isFuture ? 0 : 0.5)
      )
      .opacity(day.isFuture ? 0 : 1)
  }

  /// On/off fill with a subtle two-level scheme: active days in the most recent
  /// 4 weeks get the full accent, older active days a softer accent.
  private func fill(for day: HeatmapDay) -> Color {
    guard !day.isFuture else { return .clear }
    if day.isActive {
      return day.isRecent ? DLColor.accent : DLColor.accent.opacity(0.55)
    }
    return DLColor.separator.opacity(0.35)
  }

  // MARK: Month tick labels

  /// One label per column slot; shows the abbreviated month name only at the
  /// first column whose week-start lands in a new month.
  private func monthLabels(for weeks: [HeatmapWeek]) -> some View {
    let symbols = calendar.shortStandaloneMonthSymbols
    var lastMonth = -1
    var labels: [String] = []
    for week in weeks {
      let month = calendar.component(.month, from: week.weekStart)
      if month != lastMonth {
        lastMonth = month
        labels.append(symbols.indices.contains(month - 1) ? symbols[month - 1] : "")
      } else {
        labels.append("")
      }
    }
    // Each slot reserves exactly one column's width (so labels stay registered
    // over the grid below), but the month name is drawn un-clamped on top and
    // overflows rightward over the following blank slots — otherwise an 11pt-wide
    // frame forces "Jan" to wrap one letter per line (vertical text).
    return HStack(spacing: gap) {
      ForEach(Array(labels.enumerated()), id: \.offset) { _, text in
        Color.clear
          .frame(width: cell, height: 12)
          .overlay(alignment: .topLeading) {
            Text(text)
              .font(.dl(.caption2))
              .foregroundStyle(DLColor.textTertiary)
              .lineLimit(1)
              .fixedSize()
          }
      }
    }
  }

  // MARK: Grid construction

  private func buildWeeks() -> [HeatmapWeek] {
    let today = calendar.startOfDay(for: Date())
    let days = activeDays

    let startOfThisWeek = startOfWeek(containing: today)
    guard let firstWeekStart = calendar.date(
      byAdding: .weekOfYear, value: -(weekCount - 1), to: startOfThisWeek
    ) else { return [] }

    // Threshold for the "recent" (full-accent) tier: last 4 weeks.
    let recentCutoff = calendar.date(byAdding: .weekOfYear, value: -3, to: startOfThisWeek) ?? startOfThisWeek

    var result: [HeatmapWeek] = []
    result.reserveCapacity(weekCount)

    for weekIndex in 0..<weekCount {
      guard let weekStart = calendar.date(
        byAdding: .weekOfYear, value: weekIndex, to: firstWeekStart
      ) else { continue }

      var dayCells: [HeatmapDay] = []
      dayCells.reserveCapacity(7)
      for offset in 0..<7 {
        guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { continue }
        let key = calendar.startOfDay(for: date)
        dayCells.append(
          HeatmapDay(
            date: key,
            isActive: days.contains(key),
            isRecent: key >= recentCutoff,
            isFuture: key > today
          )
        )
      }
      result.append(HeatmapWeek(weekStart: weekStart, days: dayCells))
    }
    return result
  }

  /// Start of the week containing `date`, honoring the calendar's `firstWeekday`.
  private func startOfWeek(containing date: Date) -> Date {
    let start = calendar.startOfDay(for: date)
    let weekday = calendar.component(.weekday, from: start)
    let diff = (weekday - calendar.firstWeekday + 7) % 7
    return calendar.date(byAdding: .day, value: -diff, to: start) ?? start
  }

  private func accessibilitySummary(weeks: [HeatmapWeek]) -> String {
    let logged = weeks
      .flatMap { $0.days }
      .filter { !$0.isFuture && $0.isActive }
      .count
    return Lf("Activity calendar. %d days journaled in the last %d weeks.", logged, weekCount)
  }
}

// MARK: - Heatmap data points

private struct HeatmapWeek: Identifiable {
  let id = UUID()
  let weekStart: Date
  let days: [HeatmapDay]
}

private struct HeatmapDay: Identifiable {
  var id: Date { date }
  let date: Date
  let isActive: Bool
  let isRecent: Bool
  let isFuture: Bool
}
