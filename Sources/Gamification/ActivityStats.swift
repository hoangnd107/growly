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

// MARK: - Detailed streaks (with date ranges, per activity type)

/// One run of consecutive active days, with its endpoints (nil when length is 0).
struct StreakRun: Equatable {
  var length: Int
  var start: Date?
  var end: Date?

  static let empty = StreakRun(length: 0, start: nil, end: nil)
}

/// Current + longest streak for a single activity type, each with a date range.
/// Powers the History "Streak" detail cards (feature 8).
struct DetailedStreak: Equatable {
  var current: StreakRun
  var longest: StreakRun

  static let empty = DetailedStreak(current: .empty, longest: .empty)

  /// Computes current and longest consecutive-day runs from a set of active days.
  static func compute(
    days: Set<Date>,
    calendar baseCalendar: Calendar = .current,
    today todayInput: Date = Date()
  ) -> DetailedStreak {
    let calendar = baseCalendar
    let normalized = Set(days.map { calendar.startOfDay(for: $0) })
    guard !normalized.isEmpty else { return .empty }

    let sorted = normalized.sorted()

    // Longest run across all history.
    var longest = StreakRun(length: 1, start: sorted[0], end: sorted[0])
    var runStart = sorted[0]
    var runLength = 1
    if sorted.count > 1 {
      for i in 1..<sorted.count {
        let diff = calendar.dateComponents([.day], from: sorted[i - 1], to: sorted[i]).day ?? 0
        if diff == 1 {
          runLength += 1
        } else {
          runStart = sorted[i]
          runLength = 1
        }
        if runLength > longest.length {
          longest = StreakRun(length: runLength, start: runStart, end: sorted[i])
        }
      }
    }

    // Current run: consecutive days ending today (or yesterday — still "alive").
    let today = calendar.startOfDay(for: todayInput)
    let anchor: Date?
    if normalized.contains(today) {
      anchor = today
    } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              normalized.contains(yesterday) {
      anchor = yesterday
    } else {
      anchor = nil
    }

    var current = StreakRun.empty
    if let end = anchor {
      var cursor = end
      var length = 0
      var start = end
      while normalized.contains(cursor) {
        length += 1
        start = cursor
        guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
        cursor = prev
      }
      current = StreakRun(length: length, start: start, end: end)
    }

    return DetailedStreak(current: current, longest: longest)
  }
}

/// The three streak types shown in History → Streak (feature 8): notes, completed
/// reviews (full WMLA), and recorded mood — each with current/longest + ranges.
struct StreakBundle: Equatable {
  var note: DetailedStreak
  var completeDay: DetailedStreak
  var mood: DetailedStreak

  static func compute(
    entries: [Entry],
    notes: [DayNote],
    calendar: Calendar = .current,
    today: Date = Date()
  ) -> StreakBundle {
    let activeNotes = notes.filter { $0.deletedAt == nil }

    // Note days: any active note (app-created or imported).
    var noteDays = Set<Date>()
    for note in activeNotes { noteDays.insert(calendar.startOfDay(for: note.createdAt)) }

    // Complete-the-day: entries with all four WMLA fields filled.
    var completeDays = Set<Date>()
    for entry in entries where entry.isComplete {
      completeDays.insert(calendar.startOfDay(for: entry.day))
    }

    // Mood days: any entry (mood always recorded) or any note with a mood set.
    var moodDays = Set<Date>()
    for entry in entries { moodDays.insert(calendar.startOfDay(for: entry.day)) }
    for note in activeNotes where note.moodRaw != nil {
      moodDays.insert(calendar.startOfDay(for: note.createdAt))
    }

    return StreakBundle(
      note: DetailedStreak.compute(days: noteDays, calendar: calendar, today: today),
      completeDay: DetailedStreak.compute(days: completeDays, calendar: calendar, today: today),
      mood: DetailedStreak.compute(days: moodDays, calendar: calendar, today: today)
    )
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

  /// One bar per year for the Stats "all-time" view (feedback item 4). Reuses
  /// `MonthCount` with the `month` slot holding the year and the label showing it,
  /// so the existing monthly bar chart renders it unchanged.
  static func yearlyCounts(
    entries: [Entry],
    notes: [DayNote],
    calendar: Calendar = .current
  ) -> [MonthCount] {
    let activeNotes = notes.filter { $0.deletedAt == nil }
    var entryByYear: [Int: Int] = [:]
    var noteByYear: [Int: Int] = [:]
    for entry in entries {
      entryByYear[calendar.component(.year, from: entry.day), default: 0] += 1
    }
    for note in activeNotes {
      noteByYear[calendar.component(.year, from: note.day), default: 0] += 1
    }
    let years = Set(entryByYear.keys).union(noteByYear.keys).sorted()
    return years.map { y in
      MonthCount(
        month: y,
        label: String(y),
        entries: entryByYear[y, default: 0],
        notes: noteByYear[y, default: 0]
      )
    }
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
