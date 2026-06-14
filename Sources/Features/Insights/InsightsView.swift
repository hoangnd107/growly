import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @Query(sort: \Entry.day, order: .reverse) private var entries: [Entry]
  @Query private var progressList: [UserProgress]
  @Query(sort: \XPTransaction.date) private var transactions: [XPTransaction]

  // Habit logs from the last 7 days, used to compute weekly challenge progress.
  @Query private var recentHabitLogs: [HabitLog]

  init() {
    let weekAgo = Calendar.current.startOfDay(
      for: Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
    )
    _recentHabitLogs = Query(
      filter: #Predicate<HabitLog> { $0.completed && $0.date >= weekAgo }
    )
  }

  private let calendar = Calendar.current
  private var today: Date { calendar.startOfDay(for: Date()) }

  /// Animate chart entrances only when Reduce Motion is off.
  private var animate: Bool { !reduceMotion }

  // MARK: Body

  var body: some View {
    NavigationStack {
      ZStack {
        DLColor.background.ignoresSafeArea()
        if entries.isEmpty {
          emptyState
        } else {
          content
        }
      }
      .navigationTitle(L("Insights"))
    }
  }

  private var emptyState: some View {
    ContentUnavailableView {
      Label(L("No insights yet"), systemImage: "chart.line.uptrend.xyaxis")
    } description: {
      Text(L("Complete a daily review to start seeing your mood, XP, and growth trends here."))
    }
  }

  private var content: some View {
    ScrollView {
      VStack(spacing: DLSpace.lg) {
        coachCard
        moodTrendCard
        xpPerDayCard
        moodDistributionCard
        moodCalendarCard
        growthScoreCard
        challengesCard
      }
      .padding(DLSpace.md)
    }
  }

  // MARK: 1 — Weekly AI coach

  private var coachCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        Label(L("Weekly coach"), systemImage: "sparkles")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(Color.accentColor)
        Text(AICoach.weeklySummary(entries: entries))
          .font(.dl(.body))
          .foregroundStyle(DLColor.textPrimary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  // MARK: 2 — Mood over time

  private var moodTrendCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        chartHeader(L("Mood over time"), subtitle: L("Last 14 days"), icon: "face.smiling")
        MoodTrendChart(points: moodPoints, animate: animate)
          .accessibilityLabel(L("Mood trend over the last 14 days"))
      }
    }
  }

  // MARK: 3 — XP per day

  private var xpPerDayCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        chartHeader(L("XP per day"), subtitle: L("Last 14 days"), icon: "bolt.fill", tint: DLColor.xpGold)
        XPPerDayChart(points: xpPoints, animate: animate)
          .accessibilityLabel(L("Experience points earned per day over the last 14 days"))
      }
    }
  }

  // MARK: 4 — Mood distribution

  private var moodDistributionCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        chartHeader(L("Mood distribution"), subtitle: L("All entries"), icon: "chart.bar.fill")
        MoodDistributionChart(points: moodCountPoints, animate: animate)
          .accessibilityLabel(L("How often each mood was logged across all entries"))
      }
    }
  }

  // MARK: 4b — Mood calendar (heatmap)

  private var moodCalendarCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        chartHeader(L("Mood calendar"), subtitle: L("Last 16 weeks"), icon: "calendar")
        MoodHeatmap(entries: entries)
      }
    }
  }

  // MARK: 5 — Growth score

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

  // MARK: 6 — Challenges

  private var challengesCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Label(L("Challenges"), systemImage: "flag.checkered")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(Color.accentColor)

        ForEach(challengeProgress) { item in
          challengeRow(item)
          if item.id != challengeProgress.last?.id {
            Divider().overlay(DLColor.separator)
          }
        }
      }
    }
  }

  private func challengeRow(_ item: ChallengeProgress) -> some View {
    VStack(alignment: .leading, spacing: DLSpace.sm) {
      HStack(spacing: DLSpace.sm) {
        Image(systemName: item.challenge.systemIcon)
          .font(.system(size: 18))
          .foregroundStyle(item.isComplete ? DLColor.success : DLColor.textSecondary)
          .frame(width: 26)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 2) {
          Text(item.challenge.title)
            .font(.dl(.subheadline, weight: .semibold))
            .foregroundStyle(DLColor.textPrimary)
          Text(item.challenge.detail)
            .font(.dl(.caption))
            .foregroundStyle(DLColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer()

        if item.isComplete {
          Image(systemName: "checkmark.seal.fill")
            .foregroundStyle(DLColor.success)
            .accessibilityHidden(true)
        } else {
          Text("+\(item.challenge.xpReward)")
            .font(.dl(.caption2, weight: .semibold))
            .foregroundStyle(DLColor.xpGold)
        }
      }

      XPProgressBar(value: item.value, height: 8)
        .animation(animate ? DLAnim.standard : nil, value: item.value)
    }
    .padding(.vertical, DLSpace.xs)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "\(item.challenge.title). \(item.challenge.detail). "
      + (item.isComplete ? "Complete." : "\(Int(item.value * 100)) percent, rewards \(item.challenge.xpReward) XP.")
    )
  }

  // MARK: Shared header

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

  private var growthScoreText: String {
    let score = progressList.first?.growthScore ?? 0
    return String(format: "%.0f", score)
  }

  /// The 14 calendar days ending today, oldest → newest.
  private var last14Days: [Date] {
    (0..<14).reversed().compactMap {
      calendar.date(byAdding: .day, value: -$0, to: today)
    }
  }

  private var moodPoints: [MoodPoint] {
    last14Days.map { day in
      let entry = entries.first { calendar.isDate($0.day, inSameDayAs: day) }
      return MoodPoint(day: day, mood: entry?.moodRaw)
    }
  }

  private var xpPoints: [DailyXPPoint] {
    // Sum transaction amounts per day; days with none read as zero.
    var totals: [Date: Int] = [:]
    for tx in transactions {
      let key = calendar.startOfDay(for: tx.date)
      totals[key, default: 0] += tx.amount
    }
    return last14Days.map { day in
      DailyXPPoint(day: day, xp: totals[day, default: 0])
    }
  }

  private var moodCountPoints: [MoodCountPoint] {
    var counts: [Int: Int] = [:]
    for entry in entries where !entry.win.isEmpty || !entry.mistake.isEmpty
      || !entry.lesson.isEmpty || !entry.adjustment.isEmpty {
      counts[entry.moodRaw, default: 0] += 1
    }
    // Fall back to counting all entries if none have reflection text yet.
    if counts.isEmpty {
      for entry in entries { counts[entry.moodRaw, default: 0] += 1 }
    }
    return Mood.allCases.map { MoodCountPoint(mood: $0, count: counts[$0.rawValue, default: 0]) }
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

  private var todayEntry: Entry? {
    entries.first { calendar.isDate($0.day, inSameDayAs: today) }
  }

  private var habitCompletionsThisWeek: Int { recentHabitLogs.count }

  private var challengeProgress: [ChallengeProgress] {
    ChallengeEngine.evaluate(
      entries: entries,
      todayEntry: todayEntry,
      habitCompletionsThisWeek: habitCompletionsThisWeek
    )
  }
}
