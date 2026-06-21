import SwiftUI
import SwiftData
import Charts

/// A detailed sleep report: headline ledger, nightly duration, quality trend, and
/// a sleep-vs-next-day-mood correlation. Self-contained — pushed via NavigationLink
/// inside an existing NavigationStack, so it provides only a ScrollView body.
struct SleepAnalysisView: View {
  @Query(sort: \SleepLog.date, order: .forward) private var sleepLogs: [SleepLog]
  @Query(sort: \Entry.day, order: .forward) private var entries: [Entry]

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var range: StatsRange = .month

  // MARK: - Derived data

  private var calendar: Calendar { .current }

  /// Sleep logs falling within the selected range, oldest first.
  private var rangeLogs: [SleepLog] {
    guard let start = range.startDate() else { return sleepLogs }
    let startDay = calendar.startOfDay(for: start)
    return sleepLogs.filter { $0.date >= startDay }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DLSpace.lg) {
        EditorialHeader(L("ANALYSIS"), L("Sleep"))

        SlidingSegmentedControl(
          items: StatsRange.allCases,
          label: { $0.label },
          selection: $range,
          accent: DLColor.accent
        )

        if rangeLogs.isEmpty {
          emptyState
        } else {
          content
        }
      }
      .padding(DLSpace.lg)
    }
    .background(ThemedBackground())
    .navigationBarTitleDisplayMode(.inline)
  }

  // MARK: - Content

  @ViewBuilder
  private var content: some View {
    headlineGrid

    Hairline()

    VStack(alignment: .leading, spacing: DLSpace.md) {
      SectionLabel(L("Duration"))
      durationChart
    }

    Hairline()

    VStack(alignment: .leading, spacing: DLSpace.md) {
      SectionLabel(L("Quality"))
      qualityChart
    }

    if let insight = moodInsight {
      Hairline()
      VStack(alignment: .leading, spacing: DLSpace.md) {
        SectionLabel(L("Sleep & mood"))
        moodInsightCard(insight)
      }
    }
  }

  // MARK: - 1) Headline ledger

  private var headlineGrid: some View {
    StatTileGrid(tiles: [
      StatTileData(
        value: Lf("%.1fh", avgDuration),
        label: L("Avg duration"),
        tint: DLColor.cool
      ),
      StatTileData(
        value: "\(avgQuality)/5",
        label: L("Avg quality"),
        sublabel: SleepLog.qualityLabel(for: avgQuality)
      ),
      StatTileData(
        value: timeString(from: avgBedtimeMinutes),
        label: L("Avg bedtime")
      ),
      StatTileData(
        value: timeString(from: avgWakeMinutes),
        label: L("Avg wake")
      ),
    ])
  }

  private var avgDuration: Double {
    let durations = rangeLogs.map(\.durationHours)
    guard !durations.isEmpty else { return 0 }
    return durations.reduce(0, +) / Double(durations.count)
  }

  /// Average of the live-computed quality, rounded to the nearest 1...5 score.
  private var avgQuality: Int {
    let qualities = rangeLogs.map(\.computedQuality)
    guard !qualities.isEmpty else { return 0 }
    let mean = Double(qualities.reduce(0, +)) / Double(qualities.count)
    return min(5, max(1, Int(mean.rounded())))
  }

  /// Average bedtime as minutes-from-midnight. Times after noon are treated as
  /// the prior evening (shifted by -24h) so a 23:00 / 00:30 spread averages near
  /// midnight rather than near noon.
  private var avgBedtimeMinutes: Int? {
    averageClockMinutes(rangeLogs.map(\.bedTime), wrapEvening: true)
  }

  private var avgWakeMinutes: Int? {
    averageClockMinutes(rangeLogs.map(\.wakeTime), wrapEvening: false)
  }

  /// Averages a set of clock times into minutes-from-midnight (0..<1440).
  /// When `wrapEvening` is true, late times (>= noon) are counted as negative so
  /// an across-midnight cluster averages correctly.
  private func averageClockMinutes(_ dates: [Date], wrapEvening: Bool) -> Int? {
    guard !dates.isEmpty else { return nil }
    var total = 0
    for date in dates {
      let comps = calendar.dateComponents([.hour, .minute], from: date)
      var minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
      if wrapEvening && minutes >= 12 * 60 { minutes -= 24 * 60 }
      total += minutes
    }
    var mean = Int((Double(total) / Double(dates.count)).rounded())
    mean %= (24 * 60)
    if mean < 0 { mean += 24 * 60 }
    return mean
  }

  private func timeString(from minutes: Int?) -> String {
    guard let minutes else { return "—" }
    let h = minutes / 60
    let m = minutes % 60
    return String(format: "%02d:%02d", h, m)
  }

  // MARK: - 2) Duration chart

  private var durationChart: some View {
    Chart {
      ForEach(rangeLogs, id: \.id) { log in
        BarMark(
          x: .value("Night", log.date, unit: .day),
          y: .value("Hours", log.durationHours)
        )
        .cornerRadius(3)
        .foregroundStyle(
          LinearGradient(
            colors: [DLColor.cool, DLColor.cool.opacity(0.55)],
            startPoint: .top,
            endPoint: .bottom
          )
        )
      }

      RuleMark(y: .value("Target", 8))
        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
        .foregroundStyle(DLColor.textTertiary.opacity(0.6))
        .annotation(position: .top, alignment: .trailing) {
          Text(L("8h"))
            .font(.dl(.caption2))
            .foregroundStyle(DLColor.textTertiary)
        }
    }
    .chartYAxis {
      AxisMarks(position: .leading) { value in
        AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.4))
        AxisValueLabel {
          if let hours = value.as(Double.self) {
            Text("\(Int(hours))h")
              .font(.dl(.caption2))
              .foregroundStyle(DLColor.textSecondary)
          }
        }
      }
    }
    .chartXAxis {
      AxisMarks(values: .automatic(desiredCount: 5)) { _ in
        AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.4))
        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textSecondary)
      }
    }
    .frame(height: 190)
    .animation(reduceMotion ? nil : DLAnim.standard, value: rangeLogs.map(\.durationHours))
  }

  // MARK: - 3) Quality trend

  private var qualityChart: some View {
    Chart {
      ForEach(rangeLogs, id: \.id) { log in
        AreaMark(
          x: .value("Night", log.date, unit: .day),
          y: .value("Quality", log.computedQuality)
        )
        .interpolationMethod(.catmullRom)
        .foregroundStyle(
          LinearGradient(
            colors: [DLColor.cool.opacity(0.30), DLColor.cool.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom
          )
        )

        LineMark(
          x: .value("Night", log.date, unit: .day),
          y: .value("Quality", log.computedQuality)
        )
        .interpolationMethod(.catmullRom)
        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
        .foregroundStyle(DLColor.cool)

        PointMark(
          x: .value("Night", log.date, unit: .day),
          y: .value("Quality", log.computedQuality)
        )
        .symbolSize(28)
        .foregroundStyle(DLColor.cool)
      }
    }
    .chartYScale(domain: 1...5)
    .chartYAxis {
      AxisMarks(values: [1, 2, 3, 4, 5]) { value in
        AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.4))
        AxisValueLabel {
          if let score = value.as(Int.self) {
            Text("\(score)")
              .font(.dl(.caption2))
              .foregroundStyle(DLColor.textSecondary)
          }
        }
      }
    }
    .chartXAxis {
      AxisMarks(values: .automatic(desiredCount: 5)) { _ in
        AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.4))
        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textSecondary)
      }
    }
    .frame(height: 180)
    .animation(reduceMotion ? nil : DLAnim.standard, value: rangeLogs.map(\.computedQuality))
  }

  // MARK: - 4) Sleep & mood correlation

  /// Average next-day mood for nights with >= 7h vs < 7h sleep.
  private struct MoodInsight {
    let wellRestedAvg: Double
    let wellRestedCount: Int
    let tiredAvg: Double
    let tiredCount: Int
    var difference: Double { wellRestedAvg - tiredAvg }
  }

  private var moodInsight: MoodInsight? {
    // Index entries by their day for O(1) next-day lookup.
    var moodByDay: [Date: Int] = [:]
    for entry in entries {
      moodByDay[calendar.startOfDay(for: entry.day)] = entry.moodRaw
    }

    var wellRested: [Int] = []
    var tired: [Int] = []
    for log in rangeLogs {
      guard let nextDay = calendar.date(byAdding: .day, value: 1, to: log.date) else { continue }
      guard let mood = moodByDay[calendar.startOfDay(for: nextDay)] else { continue }
      if log.durationHours >= 7 {
        wellRested.append(mood)
      } else {
        tired.append(mood)
      }
    }

    guard !wellRested.isEmpty, !tired.isEmpty else { return nil }
    let wellAvg = Double(wellRested.reduce(0, +)) / Double(wellRested.count)
    let tiredAvg = Double(tired.reduce(0, +)) / Double(tired.count)
    return MoodInsight(
      wellRestedAvg: wellAvg,
      wellRestedCount: wellRested.count,
      tiredAvg: tiredAvg,
      tiredCount: tired.count
    )
  }

  @ViewBuilder
  private func moodInsightCard(_ insight: MoodInsight) -> some View {
    let diff = insight.difference
    let absDiff = abs(diff)
    let sentence: String = {
      if absDiff < 0.05 {
        return L("Your next-day mood is about the same whether you sleep 7+ hours or less.")
      } else if diff > 0 {
        return Lf(
          "After nights with 7+ hours of sleep, your next-day mood averages %.1f points higher than after shorter nights.",
          absDiff
        )
      } else {
        return Lf(
          "After nights with under 7 hours of sleep, your next-day mood averages %.1f points higher — your data doesn't show a rested-day boost.",
          absDiff
        )
      }
    }()

    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Text(sentence)
          .font(.dl(.body))
          .foregroundStyle(DLColor.textPrimary)
          .fixedSize(horizontal: false, vertical: true)

        HStack(spacing: DLSpace.lg) {
          moodStat(
            value: insight.wellRestedAvg,
            label: Lf("7h+ nights (%d)", insight.wellRestedCount),
            tint: DLColor.cool
          )
          moodStat(
            value: insight.tiredAvg,
            label: Lf("Under 7h (%d)", insight.tiredCount),
            tint: DLColor.textSecondary
          )
        }
      }
    }
  }

  private func moodStat(value: Double, label: String, tint: Color) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(Lf("%.1f", value))
        .font(.serif(.title2, weight: .semibold))
        .foregroundStyle(tint)
        .monospacedDigit()
      Text(label)
        .font(.dl(.caption))
        .foregroundStyle(DLColor.textSecondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Empty state

  private var emptyState: some View {
    VStack(spacing: DLSpace.md) {
      Image(systemName: "moon.zzz")
        .font(.system(size: 40, weight: .light))
        .foregroundStyle(DLColor.cool)
      Text(L("No sleep logged in this range"))
        .font(.serif(.title3, weight: .semibold))
        .foregroundStyle(DLColor.textPrimary)
      Text(L("Log a few nights to see your duration, quality, and how rest shapes your mood."))
        .font(.dl(.subheadline))
        .foregroundStyle(DLColor.textSecondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, DLSpace.xl)
  }
}
