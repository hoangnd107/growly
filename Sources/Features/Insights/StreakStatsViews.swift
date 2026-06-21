import SwiftUI
import SwiftData

// MARK: - Streak card (current / longest daily + longest weekly)

/// Self-contained streak summary used by both Insights (as a card) and History
/// (as a mode). Counts every day with a reflection OR a note, so imported and
/// app notes both contribute (feature 3).
struct StreakCard: View {
  @Query(sort: \Entry.day, order: .reverse) private var entries: [Entry]
  @Query private var notes: [DayNote]
  @Query private var progressList: [UserProgress]

  private var progress: UserProgress? { progressList.first }
  private var theme: GradientTheme { progress?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal") }

  private var stats: StreakStats {
    StreakStats.compute(
      entries: entries,
      notes: notes,
      frozenDays: progress?.streakFreezeDates ?? [],
      weekStartsMonday: progress?.weekStartsMonday ?? true
    )
  }

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Label(L("Streak"), systemImage: "flame.fill")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(DLColor.streakStart)

        HStack(spacing: 0) {
          metric(value: stats.currentDaily, label: L("Current streak"), unit: L("days"), tint: DLColor.streakStart, icon: "flame.fill")
          divider
          metric(value: stats.longestDaily, label: L("Longest streak"), unit: L("days"), tint: DLColor.streakEnd, icon: "trophy.fill")
          divider
          metric(value: stats.longestWeekly, label: L("Longest weekly streak"), unit: L("weeks"), tint: theme.accent, icon: "calendar")
        }

        Text(L("Counts every day you wrote a reflection or a note."))
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
      }
    }
  }

  private func metric(value: Int, label: String, unit: String, tint: Color, icon: String) -> some View {
    VStack(spacing: DLSpace.xs) {
      Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
      Text("\(value)")
        .font(.system(.title, design: .rounded).weight(.bold))
        .monospacedDigit()
        .foregroundStyle(DLColor.textPrimary)
        .contentTransition(.numericText())
        .lineLimit(1)
        .minimumScaleFactor(0.5)
      Text(unit)
        .font(.dl(.caption2, weight: .medium))
        .foregroundStyle(DLColor.textTertiary)
      Text(label)
        .font(.dl(.caption2, weight: .medium))
        .foregroundStyle(DLColor.textSecondary)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(label): \(value) \(unit)")
  }

  private var divider: some View {
    Rectangle().fill(DLColor.separator.opacity(0.6)).frame(width: 1, height: 64)
  }
}

// MARK: - Detailed streak view (History → Streak)

/// Three streak cards — Note, Complete-the-Day, and Mood — each showing current
/// and longest runs with their date ranges (feature 8).
struct StreakDetailView: View {
  @Query(sort: \Entry.day, order: .reverse) private var entries: [Entry]
  @Query private var notes: [DayNote]
  @Query private var progressList: [UserProgress]

  private var theme: GradientTheme { progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal") }

  private var bundle: StreakBundle {
    StreakBundle.compute(entries: entries, notes: notes)
  }

  var body: some View {
    VStack(spacing: DLSpace.md) {
      card(title: L("Note Streak"), icon: "note.text", tint: CalendarDayMark.noteColor, streak: bundle.note)
      card(title: L("Complete the Day Streak"), icon: "checkmark.seal.fill", tint: CalendarDayMark.completeColor, streak: bundle.completeDay)
      card(title: L("Mood Streak"), icon: "face.smiling", tint: CalendarDayMark.moodColor, streak: bundle.mood)
    }
  }

  private func card(title: String, icon: String, tint: Color, streak: DetailedStreak) -> some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Label(title, systemImage: icon)
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(tint)

        HStack(spacing: 0) {
          runColumn(value: streak.current.length, label: L("Current"), run: streak.current, tint: tint)
          Rectangle().fill(DLColor.separator.opacity(0.6)).frame(width: 1, height: 64)
          runColumn(value: streak.longest.length, label: L("Longest"), run: streak.longest, tint: DLColor.streakEnd)
        }
      }
    }
  }

  private func runColumn(value: Int, label: String, run: StreakRun, tint: Color) -> some View {
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
      Text(rangeText(run))
        .font(.dl(.caption2))
        .foregroundStyle(DLColor.textTertiary)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(label): \(value) \(value == 1 ? L("day") : L("days")). \(rangeText(run))")
  }

  private func rangeText(_ run: StreakRun) -> String {
    guard run.length > 0, let start = run.start, let end = run.end else { return L("—") }
    if Calendar.current.isDate(start, inSameDayAs: end) {
      return StreakDetailView.dayFormat(start)
    }
    return Lf("%@ to %@", StreakDetailView.dayFormat(start), StreakDetailView.dayFormat(end))
  }

  /// dd/MM/yyyy formatting per the spec.
  static func dayFormat(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = LocalizationManager.shared.locale ?? .current
    f.dateFormat = "dd/MM/yyyy"
    return f.string(from: date)
  }
}

// MARK: - Stats card (per-month bar chart + totals)

/// Self-contained Stats summary used by both Insights and History: a monthly
/// entries/notes bar chart for a chosen year plus all-time totals (entries,
/// notes, and total words written in notes).
struct StatsCard: View {
  @Query(sort: \Entry.day, order: .reverse) private var entries: [Entry]
  @Query private var notes: [DayNote]
  @Query private var progressList: [UserProgress]
  @Query private var sleeps: [SleepLog]
  @Query private var habitLogs: [HabitLog]
  @Query(sort: \Habit.sortIndex) private var habits: [Habit]
  @Query(sort: \SmartGoal.createdAt, order: .reverse) private var goals: [SmartGoal]
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Year view drills into months; All-time view shows one bar per year (item 4).
  private enum StatsScope: String, CaseIterable, Identifiable {
    case year, allTime
    var id: String { rawValue }
    var label: String { self == .year ? L("By year") : L("All time") }
  }

  @State private var year: Int = Calendar.current.component(.year, from: Date())
  @State private var scope: StatsScope = .year
  /// The tapped month column's label in Year view (nil = no detail shown).
  @State private var selectedMonth: String?
  /// The tapped year column's label in All-time view (drills into that year).
  @State private var selectedYearLabel: String?
  private let calendar = Calendar.current

  private var theme: GradientTheme { progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal") }
  private var animate: Bool { !reduceMotion }
  private var years: [Int] { StatsSummary.availableYears(entries: entries, notes: notes) }
  private var summary: StatsSummary { StatsSummary.compute(entries: entries, notes: notes, year: year) }
  private var yearlyPoints: [MonthCount] { StatsSummary.yearlyCounts(entries: entries, notes: notes) }

  private var minYear: Int { years.min() ?? year }
  private var maxYear: Int { years.max() ?? year }

  /// The tapped month's counts in Year view, used to scope the totals (item 3).
  /// Nil in All-time view or when no month is selected → totals fall back to the
  /// year / all-time aggregates.
  private var selectedMonthCount: MonthCount? {
    guard scope == .year, let selectedMonth else { return nil }
    return summary.monthly.first { $0.label == selectedMonth }
  }

  private var totalReviewsValue: Int {
    selectedMonthCount?.entries ?? (scope == .year ? summary.yearEntries : summary.totalEntries)
  }
  private var totalNotesValue: Int {
    selectedMonthCount?.notes ?? (scope == .year ? summary.yearNotes : summary.totalNotes)
  }
  private var totalWordsValue: Int {
    selectedMonthCount?.words ?? (scope == .year ? summary.yearNoteWords : summary.totalNoteWords)
  }

  /// Caption under the totals: the tapped month, the whole year, or all-time.
  private var statsFooter: String {
    if let mc = selectedMonthCount {
      return Lf("%d reviews · %d notes in %@ %d", mc.entries, mc.notes, mc.label, year)
    }
    return scope == .year
      ? Lf("%d reviews · %d notes in %d", summary.yearEntries, summary.yearNotes, year)
      : Lf("%d reviews · %d notes all-time", summary.totalEntries, summary.totalNotes)
  }

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        header

        if scope == .year {
          MonthlyCountChart(
            points: summary.monthly,
            entriesLabel: L("Reviews"),
            notesLabel: L("Notes"),
            entriesColor: theme.accent,
            notesColor: DLColor.xpGold,
            animate: animate,
            selection: $selectedMonth
          )

          if let selectedMonth, let detail = monthDetail(for: selectedMonth) {
            monthDetailPanel(detail)
              .transition(.opacity.combined(with: .move(edge: .top)))
          }
        } else {
          MonthlyCountChart(
            points: yearlyPoints,
            entriesLabel: L("Reviews"),
            notesLabel: L("Notes"),
            entriesColor: theme.accent,
            notesColor: DLColor.xpGold,
            animate: animate,
            selection: $selectedYearLabel
          )

          Text(L("Tap a year to see its months."))
            .font(.dl(.caption2))
            .foregroundStyle(DLColor.textTertiary)
        }

        HStack(spacing: 0) {
          totalMetric(value: totalReviewsValue, label: L("Total reviews"), tint: theme.accent)
          divider
          totalMetric(value: totalNotesValue, label: L("Total notes"), tint: DLColor.xpGold)
          divider
          totalMetric(value: totalWordsValue, label: L("Words in notes"), tint: DLColor.success)
        }

        Text(statsFooter)
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
          .monospacedDigit()
      }
    }
    .animation(animate ? DLAnim.standard : nil, value: selectedMonth)
    .animation(animate ? DLAnim.standard : nil, value: scope)
    .onChange(of: scope) { _, newScope in
      selectedYearLabel = nil
      selectedMonth = newScope == .year ? defaultMonthLabel(for: year) : nil
    }
    .onChange(of: selectedYearLabel) { _, newValue in
      guard let label = newValue, let tapped = Int(label) else { return }
      withAnimation(animate ? DLAnim.standard : nil) {
        year = tapped
        scope = .year
        selectedYearLabel = nil
        selectedMonth = defaultMonthLabel(for: tapped)
      }
      Haptics.selection()
    }
    .onAppear {
      if !years.contains(year), let first = years.first { year = first }
      if selectedMonth == nil { selectedMonth = defaultMonthLabel(for: year) }
    }
  }

  private var header: some View {
    VStack(spacing: DLSpace.sm) {
      HStack {
        Label(L("Stats"), systemImage: "chart.bar.fill")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(theme.accent)
        Spacer()
        if scope == .year {
          HStack(spacing: DLSpace.sm) {
            yearButton(systemName: "chevron.left", enabled: year > minYear) { stepYear(-1) }
            Text(verbatim: String(year))
              .font(.dl(.subheadline, weight: .bold))
              .foregroundStyle(DLColor.textPrimary)
              .monospacedDigit()
              .frame(minWidth: 44)
            yearButton(systemName: "chevron.right", enabled: year < maxYear) { stepYear(1) }
          }
          .transition(.opacity)
        }
      }
      SlidingSegmentedControl(
        items: StatsScope.allCases,
        label: { $0.label },
        selection: $scope,
        accent: theme.accent
      )
      .accessibilityLabel(L("Stats range"))
    }
  }

  private func stepYear(_ delta: Int) {
    let next = year + delta
    guard next >= minYear, next <= maxYear else { return }
    withAnimation(animate ? DLAnim.standard : nil) {
      year = next
      selectedMonth = defaultMonthLabel(for: next)
    }
    Haptics.selection()
  }

  /// Default month detail = the current month when viewing the current year, so
  /// opening Stats already shows this month's summary (feedback item 4).
  private func defaultMonthLabel(for year: Int) -> String? {
    let now = Date()
    guard calendar.component(.year, from: now) == year else { return nil }
    let m = calendar.component(.month, from: now)
    let symbols = calendar.shortStandaloneMonthSymbols
    return symbols.indices.contains(m - 1) ? symbols[m - 1] : nil
  }

  private func yearButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(enabled ? theme.accent : DLColor.textTertiary)
        .frame(width: 32, height: 32)
        .background(DLColor.surfaceElevated.opacity(0.6), in: Circle())
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
    .accessibilityLabel(systemName == "chevron.left" ? L("Previous year") : L("Next year"))
  }

  private func totalMetric(value: Int, label: String, tint: Color) -> some View {
    VStack(spacing: 2) {
      Text("\(value)")
        .font(.system(.title2, design: .rounded).weight(.bold))
        .monospacedDigit()
        .foregroundStyle(tint)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
      Text(label)
        .font(.dl(.caption2, weight: .medium))
        .foregroundStyle(DLColor.textSecondary)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(label): \(value)")
  }

  private var divider: some View {
    Rectangle().fill(DLColor.separator.opacity(0.6)).frame(width: 1, height: 40)
  }

  // MARK: - Month detail (B2)

  private struct MonthMoodCount: Identifiable {
    let option: MoodOption
    let count: Int
    var id: Int { option.value }
  }

  private struct MonthHabitCount: Identifiable {
    let name: String
    let count: Int
    var id: String { name }
  }

  private struct MonthDetailData {
    let label: String
    let noteLongest: Int
    let completeLongest: Int
    let moodCounts: [MonthMoodCount]
    let avgSleepHours: Double
    let avgSleepQuality: Double
    let sleepNights: Int
    let habitCompletions: Int
    let topHabits: [MonthHabitCount]
    let goalsCompleted: Int
  }

  private func isIn(_ date: Date, month: Int) -> Bool {
    let comps = calendar.dateComponents([.year, .month], from: date)
    return comps.year == year && comps.month == month
  }

  /// Builds the expandable detail for the tapped month label.
  private func monthDetail(for label: String) -> MonthDetailData? {
    guard let mc = summary.monthly.first(where: { $0.label == label }) else { return nil }
    let month = mc.month
    let activeNotes = notes.filter { $0.deletedAt == nil }

    // Longest streaks within the month.
    var noteDays = Set<Date>()
    var completeDays = Set<Date>()
    for note in activeNotes where isIn(note.createdAt, month: month) {
      noteDays.insert(calendar.startOfDay(for: note.createdAt))
    }
    for entry in entries where entry.isComplete && isIn(entry.day, month: month) {
      completeDays.insert(calendar.startOfDay(for: entry.day))
    }
    let noteLongest = DetailedStreak.compute(days: noteDays).longest.length
    let completeLongest = DetailedStreak.compute(days: completeDays).longest.length

    // Mood distribution for the month.
    var moodByValue: [Int: Int] = [:]
    for entry in entries where isIn(entry.day, month: month) {
      moodByValue[entry.moodRaw, default: 0] += 1
    }
    for note in activeNotes where isIn(note.createdAt, month: month) {
      if let m = note.moodRaw { moodByValue[m, default: 0] += 1 }
    }
    let moodCounts = MoodCatalog.shared.options
      .map { MonthMoodCount(option: $0, count: moodByValue[$0.value, default: 0]) }
      .filter { $0.count > 0 }

    // Sleep stats.
    let monthSleeps = sleeps.filter { isIn($0.date, month: month) }
    let avgHours = monthSleeps.isEmpty ? 0 : monthSleeps.map(\.durationHours).reduce(0, +) / Double(monthSleeps.count)
    let avgQuality = monthSleeps.isEmpty ? 0 : Double(monthSleeps.map(\.computedQuality).reduce(0, +)) / Double(monthSleeps.count)

    // Habit completions + top habits.
    var habitCountByID: [UUID: Int] = [:]
    var habitTotal = 0
    for log in habitLogs where log.completed && isIn(log.date, month: month) {
      habitTotal += 1
      if let id = log.habit?.id { habitCountByID[id, default: 0] += 1 }
    }
    let topHabits: [MonthHabitCount] = habitCountByID
      .sorted { $0.value > $1.value }
      .prefix(3)
      .compactMap { pair in
        guard let habit = habits.first(where: { $0.id == pair.key }) else { return nil }
        return MonthHabitCount(name: "\(habit.emoji) \(habit.name)", count: pair.value)
      }

    // Goals completed in the month.
    let goalsCompleted = goals.filter {
      $0.deletedAt == nil && $0.isCompleted && ($0.completedAt.map { isIn($0, month: month) } ?? false)
    }.count

    return MonthDetailData(
      label: label,
      noteLongest: noteLongest,
      completeLongest: completeLongest,
      moodCounts: moodCounts,
      avgSleepHours: avgHours,
      avgSleepQuality: avgQuality,
      sleepNights: monthSleeps.count,
      habitCompletions: habitTotal,
      topHabits: topHabits,
      goalsCompleted: goalsCompleted
    )
  }

  private func monthDetailPanel(_ d: MonthDetailData) -> some View {
    VStack(alignment: .leading, spacing: DLSpace.md) {
      Text(Lf("%@ %d", d.label, year))
        .font(.dl(.subheadline, weight: .bold))
        .foregroundStyle(DLColor.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)

      detailRow(icon: "flame.fill", tint: DLColor.streakStart,
                text: Lf("Longest streaks · %d-day notes, %d-day complete", d.noteLongest, d.completeLongest))

      if !d.moodCounts.isEmpty {
        HStack(spacing: DLSpace.sm) {
          Image(systemName: "face.smiling").font(.system(size: 14)).foregroundStyle(theme.accent)
          ForEach(d.moodCounts) { item in
            HStack(spacing: 2) {
              Text(item.option.emoji).font(.system(size: 15))
              Text("\(item.count)")
                .font(.dl(.caption2, weight: .semibold))
                .foregroundStyle(DLColor.textSecondary)
                .monospacedDigit()
            }
          }
          Spacer(minLength: 0)
        }
      }

      if d.sleepNights > 0 {
        detailRow(icon: "bed.double.fill", tint: theme.accent,
                  text: Lf("Sleep · %.1f h avg, %.1f quality over %d nights", d.avgSleepHours, d.avgSleepQuality, d.sleepNights))
      }

      if d.habitCompletions > 0 {
        VStack(alignment: .leading, spacing: 4) {
          detailRow(icon: "checklist", tint: DLColor.success,
                    text: Lf("Habits · %d completions", d.habitCompletions))
          ForEach(d.topHabits) { habit in
            Text("\(habit.name) · \(habit.count)")
              .font(.dl(.caption2))
              .foregroundStyle(DLColor.textTertiary)
              .lineLimit(1)
          }
        }
      }

      if d.goalsCompleted > 0 {
        detailRow(icon: "checkmark.seal.fill", tint: DLColor.success,
                  text: Lf("Goals · %d completed", d.goalsCompleted))
      }
    }
    .padding(DLSpace.md)
    .background(DLColor.surfaceElevated.opacity(0.5), in: RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous))
  }

  private func detailRow(icon: String, tint: Color, text: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: DLSpace.sm) {
      Image(systemName: icon).font(.system(size: 14)).foregroundStyle(tint)
      Text(text)
        .font(.dl(.caption))
        .foregroundStyle(DLColor.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
    }
  }
}
