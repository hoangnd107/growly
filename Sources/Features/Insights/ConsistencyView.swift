import SwiftUI
import SwiftData

// MARK: - Consistency (year activity heatmap)

/// A year-long, GitHub-contributions-style heatmap of the days you wrote a daily
/// review (`Entry`). Notes have their own consistency section in Writing stats, so
/// this view is now review-only. A year filter (shared `YearStepper`) scopes the
/// heatmap and the headline tiles. Self-contained: fetches its own data with
/// `@Query`, so it can be pushed via `NavigationLink { ConsistencyView() }`.
struct ConsistencyView: View {
  @Query(sort: \Entry.day, order: .reverse) private var entries: [Entry]
  @Query private var progressList: [UserProgress]

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var selectedYear = Calendar.current.component(.year, from: Date())

  private let calendar = Calendar.current

  private var progress: UserProgress? { progressList.first }

  // MARK: Derived data

  /// Only **completed** reviews count toward consistency: a day is "done" when all
  /// four WMLA reflection fields are filled (`Entry.isComplete`). A day with just a
  /// mood/energy logged (e.g. via bulk log) creates an Entry but is *not* a review,
  /// so it must not light a cell here (round 8, item 4).
  private var completeEntries: [Entry] {
    entries.filter { $0.isComplete }
  }

  /// The set of completed-review days, normalized to start-of-day. Notes are
  /// tracked separately in Writing stats.
  private var activeDays: Set<Date> {
    var days = Set<Date>()
    days.reserveCapacity(completeEntries.count)
    for entry in completeEntries { days.insert(calendar.startOfDay(for: entry.day)) }
    return days
  }

  private var streakStats: StreakStats {
    StreakStats.compute(
      entries: completeEntries,
      notes: [],
      frozenDays: progress?.streakFreezeDates ?? [],
      weekStartsMonday: progress?.weekStartsMonday ?? true
    )
  }

  /// Years that have any activity, plus the current year — for the stepper bounds.
  private var availableYears: [Int] {
    var ys = Set(activeDays.map { calendar.component(.year, from: $0) })
    ys.insert(calendar.component(.year, from: Date()))
    return ys.sorted()
  }

  private var minYear: Int { availableYears.min() ?? selectedYear }
  private var maxYear: Int { calendar.component(.year, from: Date()) }

  /// Active days within `selectedYear`.
  private var daysInSelectedYear: Int {
    activeDays.filter { calendar.component(.year, from: $0) == selectedYear }.count
  }

  /// Days elapsed in `selectedYear` (full year for past years, Jan 1…today for
  /// the current year), used as the "% of year" denominator.
  private var daysElapsedInSelectedYear: Int {
    let nowYear = calendar.component(.year, from: Date())
    guard let jan1 = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1)) else { return 1 }
    if selectedYear > nowYear { return 1 }
    let endDate: Date
    if selectedYear < nowYear {
      endDate = calendar.date(from: DateComponents(year: selectedYear, month: 12, day: 31)) ?? jan1
    } else {
      endDate = calendar.startOfDay(for: Date())
    }
    let elapsed = (calendar.dateComponents([.day], from: jan1, to: endDate).day ?? 0) + 1
    return max(1, elapsed)
  }

  var body: some View {
    let stats = streakStats
    let thisYear = daysInSelectedYear
    let elapsed = daysElapsedInSelectedYear
    let percent = Int((Double(thisYear) / Double(elapsed) * 100).rounded())

    ScrollView {
      VStack(alignment: .leading, spacing: DLSpace.lg) {
        EditorialHeader(L("CONSISTENCY"), L("Consistency")) {
          YearStepper(year: $selectedYear, minYear: minYear, maxYear: maxYear, years: availableYears)
        }

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
        SectionLabel(String(selectedYear))

        YearActivityHeatmap(year: selectedYear, reduceMotion: reduceMotion) { day in
          activeDays.contains(day) ? DLColor.accent : DLColor.track
        }

        // 3) What counts.
        Text(L("Each cell is a day. A day is filled when you completed a daily review."))
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(DLSpace.lg)
    }
    .background(ThemedBackground())
    .navigationBarTitleDisplayMode(.inline)
    .animation(reduceMotion ? nil : DLAnim.standard, value: selectedYear)
    .onAppear {
      if !availableYears.contains(selectedYear), let latest = availableYears.last {
        selectedYear = latest
      }
    }
  }
}
