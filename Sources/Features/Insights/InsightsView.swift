import SwiftUI
import SwiftData
import Charts

/// The Insights tab — an at-a-glance dashboard of the user's growth.
///
/// Sections, top to bottom:
/// 1. AI Insights  — on-device heuristic patterns from `InsightsEngine`.
/// 2. Manage hub   — Goals / Habits / Sleep / Life areas.
/// 3. Detailed reports — editorial analytics destinations.
/// 4. Lifetime     — Total XP / Level / Reviews / Notes (moved from the Me tab).
/// 5. Streaks      — overall + per-type Note / Review / Mood runs (moved from Progress).
/// 6. Growth score, XP per day, and Stats.
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

  /// Selected time range for the XP-per-day chart (default 14 days, no cap).
  @State private var xpRange: ChartRange = .twoWeeks

  /// Presents the habit manager sheet from the Manage hub (it owns a NavigationStack).
  @State private var showHabitManager = false

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
        manageHubCard
        reportsCard
        lifetimeCard
        StreakCard()
        StreakDetailView()
        growthScoreCard
        if !entries.isEmpty {
          xpPerDayCard
        }
        StatsCard()
      }
      .padding(DLSpace.md)
    }
    .scrollDismissesKeyboard(.immediately)
    .sheet(isPresented: $showHabitManager) { HabitManagerView() }
  }

  // MARK: Manage hub (restructure)
  //
  // The single command center for every tracked entity. Goals / Sleep / Life
  // areas push their canonical homes; Habits opens its manager sheet (it owns a
  // NavigationStack). Replaces the scattered goals/sleep/life-area summary cards
  // and surfaces Habits management here now that the Me tab no longer hosts it.

  private var manageHubCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 0) {
        Label(L("Manage"), systemImage: "square.grid.2x2")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(theme.accent)
          .padding(.bottom, DLSpace.xs)

        NavigationLink { GoalsView() } label: {
          manageRowLabel(L("Goals"), subtitle: goalsManageSubtitle, systemImage: "target", tint: theme.accent)
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.98))
        Hairline()

        Button { showHabitManager = true } label: {
          manageRowLabel(L("Habits"), subtitle: L("Add, edit & reorder your habits"), systemImage: "checklist", tint: DLColor.success)
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.98))
        Hairline()

        NavigationLink { SleepTrackerView() } label: {
          manageRowLabel(L("Sleep"), subtitle: sleepManageSubtitle, systemImage: "bed.double.fill", tint: Color(hex: 0x5AC8FA))
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.98))
        Hairline()

        NavigationLink { LifeAreaReportView() } label: {
          manageRowLabel(L("Life areas"), subtitle: L("Review & track health, work, and more"), systemImage: "chart.xyaxis.line", tint: DLColor.warning)
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.98))
      }
    }
  }

  private func manageRowLabel(_ title: String, subtitle: String, systemImage: String, tint: Color) -> some View {
    HStack(spacing: DLSpace.md) {
      ZStack {
        Circle().fill(tint.opacity(0.18)).frame(width: 40, height: 40)
        Image(systemName: systemImage)
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(tint)
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.dl(.body, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)
        Text(subtitle)
          .font(.dl(.caption))
          .foregroundStyle(DLColor.textSecondary)
          .lineLimit(1)
      }
      Spacer(minLength: 0)
      Image(systemName: "chevron.right")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(DLColor.textTertiary)
    }
    .padding(.vertical, DLSpace.sm)
    .contentShape(Rectangle())
  }

  private var goalsManageSubtitle: String {
    goals.isEmpty ? L("Set a SMART goal to track progress")
                  : Lf("%d active, %d completed", activeGoalsCount, completedGoalsCount)
  }

  private var sleepManageSubtitle: String {
    sleeps.isEmpty ? L("Log a night to see your rest patterns")
                   : Lf("%.1f hrs avg over %d nights", avgSleepHours, sleeps.count)
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

  // MARK: 1b — Detailed reports (new editorial analytics views)

  private var reportsCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 0) {
        Label(L("Detailed reports"), systemImage: "chart.bar.doc.horizontal")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(theme.accent)
          .padding(.bottom, DLSpace.xs)
        reportLink(emoji: "📋", L("Weekly Life Review")) { WeeklyLifeReviewView() }
        Hairline()
        reportLink(emoji: "🧭", L("Life OS Score")) { LifeOSScoreView() }
        Hairline()
        reportLink(emoji: "🙂", L("Mood analysis")) { MoodAnalysisView() }
        Hairline()
        reportLink(emoji: "🌙", L("Sleep analysis")) { SleepAnalysisView() }
        Hairline()
        reportLink(emoji: "✅", L("Habit analytics")) { HabitAnalyticsView() }
        Hairline()
        reportLink(emoji: "✍️", L("Writing stats")) { WritingStatsView() }
        Hairline()
        reportLink(emoji: "◈", L("Life areas")) { LifeAreaReportView() }
        Hairline()
        reportLink(emoji: "▦", L("Consistency")) { ConsistencyView() }
      }
    }
  }

  @ViewBuilder
  private func reportLink<Destination: View>(
    emoji: String,
    _ title: String,
    @ViewBuilder destination: @escaping () -> Destination
  ) -> some View {
    NavigationLink {
      destination()
    } label: {
      HStack(spacing: DLSpace.md) {
        Text(emoji).font(.system(size: 20)).frame(width: 26)
        Text(title)
          .font(.dl(.body, weight: .medium))
          .foregroundStyle(DLColor.textPrimary)
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(DLColor.textTertiary)
      }
      .padding(.vertical, DLSpace.md)
      .contentShape(Rectangle())
    }
    .buttonStyle(ScaleButtonStyle(scale: 0.98))
  }

  // MARK: Lifetime (moved from the Me tab)

  /// Lifetime identity stats — Total XP, Level, Reviews, Notes — as an editorial
  /// ledger. Moved here from the Me tab so the aggregate stats live in Insights.
  private var lifetimeCard: some View {
    let progress = progressList.first
    let level = progress?.levelInfo.level ?? 1
    return VStack(alignment: .leading, spacing: DLSpace.sm) {
      SectionLabel(L("Lifetime"))
      CompactStatRow(tiles: [
        StatTileData(value: "\(progress?.totalXP ?? 0)", label: L("Total XP"), tint: DLColor.xpGold),
        StatTileData(value: "\(level)", label: L("Level"), tint: DLColor.accent),
        StatTileData(value: "\(entries.count)", label: L("Reviews")),
        StatTileData(value: "\(allNotes.filter { $0.deletedAt == nil }.count)", label: L("Notes")),
      ])
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

  // MARK: Chart range

  /// Time window for the XP-per-day chart. `.all` is uncapped.
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

  // MARK: 4 — Existing charts

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

}
