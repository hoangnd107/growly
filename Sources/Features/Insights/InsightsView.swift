import SwiftUI
import SwiftData
import Charts

/// The Insights tab — an at-a-glance dashboard of the user's growth.
///
/// Sections, top to bottom:
/// 1. AI Insights  — on-device heuristic patterns from `InsightsEngine`.
/// 2. Goals summary — active/completed counts + a link to goals.
/// 3. Sleep summary — averages + a link to the sleep tracker.
/// 4. Growth score — the compound score plus a cumulative-reviews curve.
/// 5. Mood calendar — week / month / year views of mood color.
/// 6. Charts        — mood trend, XP per day, mood distribution.
///
/// Everything lives in a `NavigationStack` so the summary cards can push the
/// Sleep and Goals destinations. The whole screen is reduce-motion aware and
/// paints the user's gradient theme behind the content.
struct InsightsView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @Query(sort: \Entry.day, order: .reverse) private var entries: [Entry]
  @Query private var progressList: [UserProgress]
  @Query(sort: \XPTransaction.date) private var transactions: [XPTransaction]
  @Query private var habitLogs: [HabitLog]
  @Query(sort: \SleepLog.date, order: .reverse) private var sleeps: [SleepLog]
  @Query(sort: \SmartGoal.createdAt, order: .reverse) private var goals: [SmartGoal]
  @Query private var allNotes: [DayNote]

  /// Drives a spring entrance for the AI-insight cards.
  @State private var appeared = false

  /// Selected granularity for the mood calendar section.
  @State private var calendarScale: CalendarScale = .month
  @Namespace private var scaleNS

  /// Selected time ranges for the trend / XP charts (default 14 days, no cap).
  @State private var moodRange: ChartRange = .twoWeeks
  @State private var xpRange: ChartRange = .twoWeeks

  init() {}

  private let calendar = Calendar.current
  private var today: Date { calendar.startOfDay(for: Date()) }

  /// Animate entrances only when Reduce Motion is off.
  private var animate: Bool { !reduceMotion }

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  // MARK: Body

  var body: some View {
    NavigationStack {
      ZStack {
        ThemedBackground(theme: theme)
        if isEmpty {
          emptyState
        } else {
          content
        }
      }
      .navigationTitle(L("Insights"))
      .tint(theme.accent)
    }
    .onAppear {
      guard !appeared else { return }
      if animate {
        withAnimation(DLAnim.smooth) { appeared = true }
      } else {
        appeared = true
      }
    }
  }

  /// "Truly empty" — no reflections, notes, sleep, or goals to show anything for.
  private var isEmpty: Bool {
    entries.isEmpty && sleeps.isEmpty && goals.isEmpty
      && !allNotes.contains { $0.deletedAt == nil }
  }

  private var emptyState: some View {
    ContentUnavailableView {
      VStack(spacing: DLSpace.md) {
        EmptyGlyph(systemImage: "chart.line.uptrend.xyaxis", size: 120, tint: theme.accent)
        Text(L("No insights yet"))
          .font(.dl(.title3, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)
      }
    } description: {
      Text(L("Complete a daily review, log a night's sleep, or set a goal to start seeing your trends here."))
        .font(.dl(.subheadline))
        .foregroundStyle(DLColor.textSecondary)
    }
  }

  private var content: some View {
    ScrollView {
      VStack(spacing: DLSpace.lg) {
        aiInsightsCard
        StreakCard()
        CompleteDayStreakCard()
        goalsSummaryCard
        sleepSummaryCard
        lifeAreasCard
        HabitStatsCard()
        growthScoreCard
        moodCalendarCard
        if !entries.isEmpty {
          moodTrendCard
          xpPerDayCard
          moodDistributionCard
        }
        StatsCard()
      }
      .padding(DLSpace.md)
    }
    .scrollDismissesKeyboard(.immediately)
  }

  // MARK: 1 — AI Insights

  private var aiInsightsCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Label(L("AI insights"), systemImage: "sparkles")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(theme.accent)

        ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
          insightRow(insight)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(
              animate ? DLAnim.bouncy.delay(Double(index) * 0.06) : nil,
              value: appeared
            )
          if insight.id != insights.last?.id {
            Divider().overlay(DLColor.separator)
          }
        }
      }
    }
  }

  private func insightRow(_ insight: Insight) -> some View {
    HStack(alignment: .top, spacing: DLSpace.sm) {
      ZStack {
        Circle()
          .fill(tint(for: insight.tone).opacity(0.18))
          .frame(width: 40, height: 40)
        Image(systemName: insight.icon)
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(tint(for: insight.tone))
      }
      .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 2) {
        Text(L(insight.title))
          .font(.dl(.subheadline, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)
        Text(L(insight.message))
          .font(.dl(.caption))
          .foregroundStyle(DLColor.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .padding(.vertical, DLSpace.xs)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(L(insight.title)). \(L(insight.message))")
  }

  private func tint(for tone: InsightTone) -> Color {
    switch tone {
    case .positive: return DLColor.success
    case .suggestion: return DLColor.warning
    case .neutral: return theme.accent
    }
  }

  // MARK: 2 — Growth score

  private var growthScoreCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Label(L("Growth score"), systemImage: "chart.line.uptrend.xyaxis")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(DLColor.success)

        HStack(alignment: .firstTextBaseline, spacing: DLSpace.sm) {
          Text(growthScoreText)
            .font(.system(.largeTitle, design: .rounded).weight(.bold))
            .monospacedDigit()
            .foregroundStyle(DLColor.textPrimary)
          Text(L("pts"))
            .font(.dl(.title3, weight: .semibold))
            .foregroundStyle(DLColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Lf("Growth score %@ points", growthScoreText))

        Text(L("A compound score of your consistency and depth — it accelerates the more reviews you stack."))
          .font(.dl(.caption))
          .foregroundStyle(DLColor.textSecondary)
          .fixedSize(horizontal: false, vertical: true)

        if cumulativePoints.count > 1 {
          GrowthCurveChart(points: cumulativePoints, animate: animate)
            .accessibilityLabel(L("Cumulative reviews completed over time"))
          Text(L("Cumulative reviews completed"))
            .font(.dl(.caption2))
            .foregroundStyle(DLColor.textTertiary)
        }
      }
    }
  }

  // MARK: 3 — Mood calendar

  private enum CalendarScale: String, CaseIterable, Identifiable {
    case week, month, year
    var id: String { rawValue }
    var label: String {
      switch self {
      case .week: return L("Week")
      case .month: return L("Month")
      case .year: return L("Year")
      }
    }
  }

  /// Time window for the mood-trend and XP-per-day charts. `.all` is uncapped.
  private enum ChartRange: Int, CaseIterable, Identifiable {
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

  private var moodCalendarCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        HStack(alignment: .firstTextBaseline) {
          Label(L("Mood calendar"), systemImage: "calendar")
            .font(.dl(.headline, weight: .semibold))
            .foregroundStyle(theme.accent)
          Spacer()
        }

        calendarScalePicker

        if entries.isEmpty {
          Text(L("Log a daily review to fill your mood calendar."))
            .font(.dl(.caption))
            .foregroundStyle(DLColor.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DLSpace.sm)
        } else {
          switch calendarScale {
          case .week:
            weekMoodStrip
              .accessibilityLabel(L("Mood this week"))
          case .month:
            MoodHeatmap(entries: entries)
              .accessibilityLabel(L("Mood calendar by day"))
          case .year:
            yearMoodGrid
              .accessibilityLabel(L("Average mood by month over the last year"))
          }
        }
      }
    }
  }

  private var calendarScalePicker: some View {
    HStack(spacing: 4) {
      ForEach(CalendarScale.allCases) { scale in
        let isSelected = calendarScale == scale
        Button {
          withAnimation(animate ? DLAnim.standard : nil) { calendarScale = scale }
          Haptics.selection()
        } label: {
          Text(scale.label)
            .font(.dl(.subheadline, weight: .semibold))
            .foregroundStyle(isSelected ? Color.white : DLColor.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
              if isSelected {
                Capsule().fill(theme.accent)
                  .matchedGeometryEffect(id: "calendarScalePill", in: scaleNS)
              }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
      }
    }
    .padding(4)
    .background(DLColor.surfaceElevated, in: Capsule())
    .overlay(Capsule().strokeBorder(DLColor.separator.opacity(0.6), lineWidth: 1))
  }

  /// The seven days of the current week (Monday → Sunday), each tinted by that
  /// day's mood. Always exactly this week — never a multi-week overview.
  private var weekMoodStrip: some View {
    var moodByDay: [Date: Int] = [:]
    for entry in entries {
      moodByDay[calendar.startOfDay(for: entry.day)] = entry.moodRaw
    }
    return HStack(spacing: DLSpace.xs) {
      ForEach(currentWeekDays, id: \.self) { day in
        let key = calendar.startOfDay(for: day)
        let isFuture = key > today
        let isToday = calendar.isDate(key, inSameDayAs: today)
        let option = moodByDay[key].flatMap { MoodCatalog.shared.option(forValue: $0) }
        VStack(spacing: 6) {
          Text(shortWeekday(day))
            .font(.dl(.caption2, weight: .semibold))
            .foregroundStyle(DLColor.textTertiary)
          ZStack {
            RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous)
              .fill(isFuture ? DLColor.separator.opacity(0.15)
                             : (option?.color ?? DLColor.separator.opacity(0.35)))
              .frame(height: 44)
              .overlay(
                RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous)
                  .strokeBorder(isToday ? theme.accent : DLColor.separator.opacity(0.3),
                                lineWidth: isToday ? 2 : 0.5)
              )
            if let option, !isFuture {
              Text(option.emoji).font(.system(size: 17))
            }
          }
          Text(day, format: .dateTime.day())
            .font(.dl(.caption2, weight: isToday ? .bold : .regular))
            .foregroundStyle(isToday ? theme.accent : DLColor.textSecondary)
            .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .opacity(isFuture ? 0.5 : 1)
      }
    }
  }

  /// Monday → Sunday of the week containing today.
  private var currentWeekDays: [Date] {
    let weekday = calendar.component(.weekday, from: today) // 1 = Sun … 7 = Sat
    let daysSinceMonday = (weekday + 5) % 7                 // Mon → 0 … Sun → 6
    guard let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) else {
      return [today]
    }
    return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
  }

  private func shortWeekday(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = LocalizationManager.shared.locale ?? .current
    formatter.setLocalizedDateFormatFromTemplate("EEE")
    return formatter.string(from: date)
  }

  /// A 12-month mini grid: each cell is tinted by that month's average mood.
  private var yearMoodGrid: some View {
    let columns = Array(repeating: GridItem(.flexible(), spacing: DLSpace.sm), count: 4)
    return LazyVGrid(columns: columns, spacing: DLSpace.sm) {
      ForEach(yearMonths) { month in
        VStack(spacing: 4) {
          RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous)
            .fill(month.color)
            .frame(height: 34)
            .overlay(
              RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous)
                .strokeBorder(DLColor.separator.opacity(0.3), lineWidth: 0.5)
            )
          Text(month.label)
            .font(.dl(.caption2, weight: .medium))
            .foregroundStyle(DLColor.textSecondary)
        }
      }
    }
  }

  // MARK: 4 — Existing charts

  private var moodTrendCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        rangeHeader(L("Mood over time"), icon: "face.smiling", tint: theme.accent, range: $moodRange)
        MoodTrendChart(points: moodPoints(for: moodRange), animate: animate)
          .accessibilityLabel(L("Mood trend"))
      }
    }
  }

  private var xpPerDayCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        rangeHeader(L("XP per day"), icon: "bolt.fill", tint: DLColor.xpGold, range: $xpRange)
        XPPerDayChart(points: xpPoints(for: xpRange), animate: animate)
          .accessibilityLabel(L("Experience points earned per day"))
      }
    }
  }

  /// A chart header with the title on the left and a tappable range menu on the
  /// right (defaults to 14 days, up to all-time).
  private func rangeHeader(_ title: String, icon: String, tint: Color, range: Binding<ChartRange>) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Label(title, systemImage: icon)
        .font(.dl(.headline, weight: .semibold))
        .foregroundStyle(tint)
      Spacer()
      Menu {
        Picker(L("Range"), selection: range) {
          ForEach(ChartRange.allCases) { option in
            Text(option.label).tag(option)
          }
        }
      } label: {
        HStack(spacing: 3) {
          Text(range.wrappedValue.label)
            .font(.dl(.caption, weight: .semibold))
          Image(systemName: "chevron.up.chevron.down")
            .font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, DLSpace.sm)
        .padding(.vertical, 4)
        .background(tint.opacity(0.12), in: Capsule())
      }
      .accessibilityLabel(Lf("Range: %@", range.wrappedValue.label))
    }
  }

  private var moodDistributionCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        chartHeader(L("Mood distribution"), subtitle: L("All entries"), icon: "chart.bar.fill")
        MoodDistributionChart(points: moodCountPoints, animate: animate)
          .accessibilityLabel(L("How often each mood was logged across all entries"))
      }
    }
  }

  // MARK: 5 — Sleep summary

  private var sleepSummaryCard: some View {
    NavigationLink {
      SleepTrackerView()
    } label: {
      GlassCard {
        VStack(alignment: .leading, spacing: DLSpace.md) {
          HStack {
            Label(L("Sleep"), systemImage: "bed.double.fill")
              .font(.dl(.headline, weight: .semibold))
              .foregroundStyle(theme.accent)
            Spacer()
            Image(systemName: "chevron.right")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(DLColor.textTertiary)
          }

          if sleeps.isEmpty {
            Text(L("No sleep logged yet. Track a night to see your rest patterns."))
              .font(.dl(.subheadline))
              .foregroundStyle(DLColor.textSecondary)
              .fixedSize(horizontal: false, vertical: true)
          } else {
            HStack(spacing: DLSpace.xl) {
              metric(
                value: String(format: "%.1f", avgSleepHours),
                unit: L("hrs avg"),
                tint: theme.accent
              )
              metric(
                value: String(format: "%.1f", avgSleepQuality),
                unit: L("quality"),
                tint: DLColor.xpGold
              )
              metric(
                value: "\(sleeps.count)",
                unit: L("nights"),
                tint: DLColor.success
              )
            }
          }
        }
      }
    }
    .buttonStyle(ScaleButtonStyle(scale: 0.98))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(sleepAccessibilityLabel)
    .accessibilityAddTraits(.isButton)
  }

  // MARK: Life areas (feature 21)

  private var lifeAreasCard: some View {
    NavigationLink {
      LifeAreaInsightsView()
    } label: {
      GlassCard {
        HStack {
          Label(L("Life areas"), systemImage: "chart.xyaxis.line")
            .font(.dl(.headline, weight: .semibold))
            .foregroundStyle(theme.accent)
          Spacer()
          Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(DLColor.textTertiary)
        }
      }
    }
    .buttonStyle(ScaleButtonStyle(scale: 0.98))
    .accessibilityLabel(L("Life areas. Opens your life-area reviews."))
  }

  // MARK: 6 — Goals summary

  private var goalsSummaryCard: some View {
    NavigationLink {
      GoalsView()
    } label: {
      GlassCard {
        VStack(alignment: .leading, spacing: DLSpace.md) {
          HStack {
            Label(L("Goals"), systemImage: "target")
              .font(.dl(.headline, weight: .semibold))
              .foregroundStyle(theme.accent)
            Spacer()
            Image(systemName: "chevron.right")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(DLColor.textTertiary)
          }

          if goals.isEmpty {
            Text(L("No goals yet. Set a SMART goal to track your progress."))
              .font(.dl(.subheadline))
              .foregroundStyle(DLColor.textSecondary)
              .fixedSize(horizontal: false, vertical: true)
          } else {
            HStack(spacing: DLSpace.xl) {
              metric(value: "\(activeGoalsCount)", unit: L("active"), tint: theme.accent)
              metric(value: "\(completedGoalsCount)", unit: L("done"), tint: DLColor.success)
            }

            if let top = topGoal {
              VStack(alignment: .leading, spacing: DLSpace.xs) {
                Text(top.title)
                  .font(.dl(.subheadline, weight: .semibold))
                  .foregroundStyle(DLColor.textPrimary)
                  .lineLimit(1)
                XPProgressBar(value: top.progress, height: 8)
                  .animation(animate ? DLAnim.standard : nil, value: top.progress)
                Text("\(Int(top.progress * 100))%")
                  .font(.dl(.caption2, weight: .semibold))
                  .foregroundStyle(DLColor.textSecondary)
                  .monospacedDigit()
              }
            }
          }
        }
      }
    }
    .buttonStyle(ScaleButtonStyle(scale: 0.98))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(goalsAccessibilityLabel)
    .accessibilityAddTraits(.isButton)
  }

  // MARK: Shared building blocks

  private func metric(value: String, unit: String, tint: Color) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(value)
        .font(.system(.title2, design: .rounded).weight(.bold))
        .monospacedDigit()
        .foregroundStyle(tint)
      Text(unit)
        .font(.dl(.caption2, weight: .medium))
        .foregroundStyle(DLColor.textSecondary)
    }
  }

  private func chartHeader(_ title: String, subtitle: String, icon: String, tint: Color = Color.accentColor) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Label(title, systemImage: icon)
        .font(.dl(.headline, weight: .semibold))
        .foregroundStyle(tint)
      Spacer()
      Text(subtitle)
        .font(.dl(.caption, weight: .medium))
        .foregroundStyle(DLColor.textTertiary)
    }
  }

  // MARK: - Derived data

  private var insights: [Insight] {
    InsightsEngine.generate(entries: entries, habitLogs: habitLogs, sleeps: sleeps)
  }

  private var growthScoreText: String {
    let score = progressList.first?.growthScore ?? 0
    return String(format: "%.0f", score)
  }

  /// Calendar days for a chart range, oldest → newest. `.all` spans from the
  /// earliest entry/transaction to today; falls back to 14 days when empty.
  private func days(for range: ChartRange) -> [Date] {
    let count: Int
    if range == .all {
      let earliest = [
        entries.map(\.day).min(),
        transactions.map { calendar.startOfDay(for: $0.date) }.min()
      ].compactMap { $0 }.min()
      if let earliest {
        let diff = calendar.dateComponents([.day], from: earliest, to: today).day ?? 13
        count = max(7, diff + 1)
      } else {
        count = 14
      }
    } else {
      count = range.rawValue
    }
    return (0..<count).reversed().compactMap {
      calendar.date(byAdding: .day, value: -$0, to: today)
    }
  }

  private func moodPoints(for range: ChartRange) -> [MoodPoint] {
    days(for: range).map { day in
      let entry = entries.first { calendar.isDate($0.day, inSameDayAs: day) }
      return MoodPoint(day: day, mood: entry?.moodRaw)
    }
  }

  private func xpPoints(for range: ChartRange) -> [DailyXPPoint] {
    // Sum transaction amounts per day; days with none read as zero.
    var totals: [Date: Int] = [:]
    for tx in transactions {
      let key = calendar.startOfDay(for: tx.date)
      totals[key, default: 0] += tx.amount
    }
    return days(for: range).map { day in
      DailyXPPoint(day: day, xp: totals[day, default: 0])
    }
  }

  private var moodCountPoints: [MoodCountPoint] {
    var counts: [Int: Int] = [:]
    for entry in entries where entry.isComplete {
      counts[entry.moodRaw, default: 0] += 1
    }
    // Fall back to counting all entries if none are complete yet.
    if counts.isEmpty {
      for entry in entries { counts[entry.moodRaw, default: 0] += 1 }
    }
    return MoodCatalog.shared.options.map { MoodCountPoint(mood: $0, count: counts[$0.value, default: 0]) }
  }

  /// Cumulative count of completed reviews, oldest → newest, for the growth curve.
  private var cumulativePoints: [CumulativePoint] {
    let completed = entries
      .filter { $0.isComplete }
      .sorted { $0.day < $1.day }
    var running = 0
    return completed.map { entry in
      running += 1
      return CumulativePoint(day: entry.day, total: running)
    }
  }

  // Sleep metrics

  private var avgSleepHours: Double {
    guard !sleeps.isEmpty else { return 0 }
    return sleeps.map(\.durationHours).reduce(0, +) / Double(sleeps.count)
  }

  private var avgSleepQuality: Double {
    guard !sleeps.isEmpty else { return 0 }
    return Double(sleeps.map(\.computedQuality).reduce(0, +)) / Double(sleeps.count)
  }

  private var sleepAccessibilityLabel: String {
    if sleeps.isEmpty {
      return L("Sleep. No sleep logged yet. Opens the sleep tracker.")
    }
    return Lf(
      "Sleep. Averaging %.1f hours and %.1f quality over %d nights. Opens the sleep tracker.",
      avgSleepHours, avgSleepQuality, sleeps.count
    )
  }

  // Goal metrics

  private var activeGoalsCount: Int { goals.filter { !$0.isCompleted }.count }
  private var completedGoalsCount: Int { goals.filter { $0.isCompleted }.count }

  /// The most-progressed active goal, falling back to the newest if none active.
  private var topGoal: SmartGoal? {
    goals
      .filter { !$0.isCompleted }
      .max { $0.progress < $1.progress }
      ?? goals.first
  }

  private var goalsAccessibilityLabel: String {
    if goals.isEmpty {
      return L("Goals. No goals yet. Opens your goals.")
    }
    return Lf(
      "Goals. %d active, %d completed. Opens your goals.",
      activeGoalsCount, completedGoalsCount
    )
  }

  // Year mood grid

  private struct YearMonth: Identifiable {
    let id: Int
    let label: String
    let color: Color
  }

  /// The last 12 months (oldest → newest), each colored by its average mood.
  /// Months with no entries render as a faint placeholder.
  private var yearMonths: [YearMonth] {
    // Average mood per (year, month).
    var sums: [DateComponents: (total: Int, count: Int)] = [:]
    for entry in entries {
      let comps = calendar.dateComponents([.year, .month], from: entry.day)
      let cur = sums[comps] ?? (0, 0)
      sums[comps] = (cur.total + entry.moodRaw, cur.count + 1)
    }

    let monthSymbols = calendar.shortMonthSymbols
    var result: [YearMonth] = []
    result.reserveCapacity(12)

    for offset in (0..<12).reversed() {
      guard let date = calendar.date(byAdding: .month, value: -offset, to: today) else { continue }
      let comps = calendar.dateComponents([.year, .month], from: date)
      let monthIndex = (comps.month ?? 1) - 1
      let label = monthSymbols.indices.contains(monthIndex) ? monthSymbols[monthIndex] : ""

      let color: Color
      if let bucket = sums[comps], bucket.count > 0 {
        let avg = Int((Double(bucket.total) / Double(bucket.count)).rounded())
        color = MoodCatalog.shared.option(forValue: avg)?.color ?? DLColor.separator.opacity(0.3)
      } else {
        color = DLColor.separator.opacity(0.3)
      }
      result.append(YearMonth(id: offset, label: label, color: color))
    }
    return result
  }
}
