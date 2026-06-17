import Foundation

// MARK: - Streak stats (activity-based: reflections ∪ notes)

/// Streaks computed from the union of reflection days and note days, so BOTH
/// app-created and imported notes count toward the streak (feature 3). Frozen
/// days bridge gaps. This is independent of the gamified review streak
/// (`UserProgress.currentStreak`) which still drives XP/badges/freeze.
struct StreakStats: Equatable {
  var currentDaily: Int
  var longestDaily: Int
  var longestWeekly: Int

  static let zero = StreakStats(currentDaily: 0, longestDaily: 0, longestWeekly: 0)

  /// Builds the active-day set (entry days ∪ non-deleted note days ∪ frozen days)
  /// and derives the three streak metrics.
  static func compute(
    entries: [Entry],
    notes: [DayNote],
    frozenDays: [Date] = [],
    weekStartsMonday: Bool = true,
    calendar baseCalendar: Calendar = .current,
    today todayInput: Date = Date()
  ) -> StreakStats {
    var calendar = baseCalendar
    calendar.firstWeekday = weekStartsMonday ? 2 : 1

    var days = Set<Date>()
    for entry in entries { days.insert(calendar.startOfDay(for: entry.day)) }
    for note in notes where note.deletedAt == nil {
      days.insert(calendar.startOfDay(for: note.createdAt))
    }
    // Frozen days bridge gaps (consistent with the XP-freeze mechanic).
    for frozen in frozenDays { days.insert(calendar.startOfDay(for: frozen)) }
    guard !days.isEmpty else { return .zero }

    let today = calendar.startOfDay(for: todayInput)
    let sorted = days.sorted()

    // Longest consecutive-day run across all history.
    var longestDaily = 1
    var run = 1
    if sorted.count > 1 {
      for i in 1..<sorted.count {
        let diff = calendar.dateComponents([.day], from: sorted[i - 1], to: sorted[i]).day ?? 0
        run = (diff == 1) ? run + 1 : 1
        longestDaily = max(longestDaily, run)
      }
    }

    // Current streak: consecutive active days ending today (or yesterday — the
    // streak stays "alive" through today even before today is logged).
    var currentDaily = 0
    let anchor: Date?
    if days.contains(today) {
      anchor = today
    } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              days.contains(yesterday) {
      anchor = yesterday
    } else {
      anchor = nil
    }
    if var cursor = anchor {
      while days.contains(cursor) {
        currentDaily += 1
        guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
        cursor = prev
      }
    }

    // Longest consecutive-week run (a week counts if it has ≥1 active day).
    var weekStarts = Set<Date>()
    for day in days { weekStarts.insert(Self.startOfWeek(day, calendar: calendar)) }
    let sortedWeeks = weekStarts.sorted()
    var longestWeekly = sortedWeeks.isEmpty ? 0 : 1
    var weekRun = 1
    if sortedWeeks.count > 1 {
      for i in 1..<sortedWeeks.count {
        let diff = calendar.dateComponents([.day], from: sortedWeeks[i - 1], to: sortedWeeks[i]).day ?? 0
        weekRun = (diff == 7) ? weekRun + 1 : 1
        longestWeekly = max(longestWeekly, weekRun)
      }
    }

    return StreakStats(currentDaily: currentDaily, longestDaily: longestDaily, longestWeekly: longestWeekly)
  }

  private static func startOfWeek(_ date: Date, calendar: Calendar) -> Date {
    let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
    return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
  }
}

// MARK: - Stats summary (per-month counts + totals)

/// One month's entry/note counts (for the Stats bar chart).
struct MonthCount: Identifiable, Equatable {
  let month: Int        // 1...12
  let label: String     // localized short month symbol
  let entries: Int
  let notes: Int
  var id: Int { month }
  var total: Int { entries + notes }
}

/// Aggregate counts for the Stats view: a year's monthly breakdown plus all-time
/// totals (including total written words across notes).
struct StatsSummary: Equatable {
  let year: Int
  let monthly: [MonthCount]
  let totalEntries: Int
  let totalNotes: Int
  let totalNoteWords: Int
  let yearEntries: Int
  let yearNotes: Int

  static func compute(
    entries: [Entry],
    notes: [DayNote],
    year: Int,
    calendar: Calendar = .current
  ) -> StatsSummary {
    let activeNotes = notes.filter { $0.deletedAt == nil }
    let symbols = calendar.shortStandaloneMonthSymbols

    var entryByMonth: [Int: Int] = [:]
    var noteByMonth: [Int: Int] = [:]
    var yearEntries = 0
    var yearNotes = 0

    for entry in entries {
      let comps = calendar.dateComponents([.year, .month], from: entry.day)
      if comps.year == year, let month = comps.month {
        entryByMonth[month, default: 0] += 1
        yearEntries += 1
      }
    }
    for note in activeNotes {
      let comps = calendar.dateComponents([.year, .month], from: note.day)
      if comps.year == year, let month = comps.month {
        noteByMonth[month, default: 0] += 1
        yearNotes += 1
      }
    }

    let monthly = (1...12).map { month in
      MonthCount(
        month: month,
        label: symbols.indices.contains(month - 1) ? symbols[month - 1] : "\(month)",
        entries: entryByMonth[month, default: 0],
        notes: noteByMonth[month, default: 0]
      )
    }

    let totalNoteWords = activeNotes.reduce(0) { $0 + $1.wordCount }

    return StatsSummary(
      year: year,
      monthly: monthly,
      totalEntries: entries.count,
      totalNotes: activeNotes.count,
      totalNoteWords: totalNoteWords,
      yearEntries: yearEntries,
      yearNotes: yearNotes
    )
  }

  /// Years that have any entry or active note, descending (for the year picker);
  /// always includes the current year.
  static func availableYears(
    entries: [Entry],
    notes: [DayNote],
    calendar: Calendar = .current,
    now: Date = Date()
  ) -> [Int] {
    var years = Set<Int>()
    years.insert(calendar.component(.year, from: now))
    for entry in entries { years.insert(calendar.component(.year, from: entry.day)) }
    for note in notes where note.deletedAt == nil {
      years.insert(calendar.component(.year, from: note.day))
    }
    return years.sorted(by: >)
  }
}
