import SwiftUI
import SwiftData
import Charts

/// A detailed mood report. Combines mood data points from every `Entry` (which
/// always carries a mood) plus every non-deleted `DayNote` that has a mood, then
/// reports headline stats, a daily-average trend, the per-mood distribution, and
/// the average mood per weekday — all filtered by a sliding range control.
///
/// Self-contained: it owns its `@Query` fetches so it can be pushed as
/// `MoodAnalysisView()` from a NavigationLink inside an existing NavigationStack.
struct MoodAnalysisView: View {
  @Query private var entries: [Entry]
  @Query private var notes: [DayNote]
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var range: StatsRange = .month

  private var animate: Bool { !reduceMotion }
  private let calendar = Calendar.current

  // MARK: - Data assembly

  /// One mood reading on a specific calendar day.
  private struct MoodSample {
    let day: Date
    let value: Int
  }

  /// All mood samples (entries + mood-bearing live notes) within the active range.
  private var samples: [MoodSample] {
    let start = range.startDate(now: Date(), calendar: calendar)
    var out: [MoodSample] = []

    for entry in entries {
      let day = calendar.startOfDay(for: entry.day)
      if let start, day < calendar.startOfDay(for: start) { continue }
      out.append(MoodSample(day: day, value: entry.moodRaw))
    }

    for note in notes where note.deletedAt == nil {
      guard let raw = note.moodRaw else { continue }
      let day = calendar.startOfDay(for: note.createdAt)
      if let start, day < calendar.startOfDay(for: start) { continue }
      out.append(MoodSample(day: day, value: raw))
    }

    return out
  }

  // MARK: - Derived series

  /// One point per logged day, carrying that day's average mood.
  private struct DailyAverage: Identifiable {
    let day: Date
    let average: Double
    var id: Date { day }
  }

  private var dailyAverages: [DailyAverage] {
    let grouped = Dictionary(grouping: samples, by: \.day)
    return grouped
      .map { day, items in
        let avg = Double(items.map(\.value).reduce(0, +)) / Double(items.count)
        return DailyAverage(day: day, average: avg)
      }
      .sorted { $0.day < $1.day }
  }

  /// Distribution count keyed by mood value.
  private var countByValue: [Int: Int] {
    var dict: [Int: Int] = [:]
    for sample in samples { dict[sample.value, default: 0] += 1 }
    return dict
  }

  /// Average mood per weekday, ordered Mon…Sun. `average` is nil when no data.
  private struct WeekdayAverage: Identifiable {
    let order: Int          // 0 = Monday … 6 = Sunday
    let name: String        // localized short weekday symbol
    let average: Double?
    var id: Int { order }
  }

  private var weekdayAverages: [WeekdayAverage] {
    // Bucket samples by Mon…Sun position.
    var sums = [Int](repeating: 0, count: 7)
    var counts = [Int](repeating: 0, count: 7)
    for sample in samples {
      let order = mondayFirstIndex(for: sample.day)
      sums[order] += sample.value
      counts[order] += 1
    }

    let symbols = orderedShortWeekdaySymbols()
    return (0..<7).map { i in
      let avg = counts[i] > 0 ? Double(sums[i]) / Double(counts[i]) : nil
      let name = symbols.indices.contains(i) ? symbols[i] : ""
      return WeekdayAverage(order: i, name: name, average: avg)
    }
  }

  /// Maps a date's weekday to a Monday-first index (0 = Mon … 6 = Sun).
  private func mondayFirstIndex(for date: Date) -> Int {
    // Calendar.weekday: 1 = Sunday … 7 = Saturday.
    let weekday = calendar.component(.weekday, from: date)
    return (weekday + 5) % 7
  }

  /// Short weekday symbols reordered to start on Monday, matching `order`.
  private func orderedShortWeekdaySymbols() -> [String] {
    // shortWeekdaySymbols is Sunday-first; rotate so Monday leads.
    let base = calendar.shortWeekdaySymbols // [Sun, Mon, …, Sat]
    guard base.count == 7 else { return base }
    return Array(base[1...6]) + [base[0]]
  }

  // MARK: - Headline figures

  private var averageMood: Double? {
    guard !samples.isEmpty else { return nil }
    return Double(samples.map(\.value).reduce(0, +)) / Double(samples.count)
  }

  private var daysLogged: Int { Set(samples.map(\.day)).count }

  /// The day with the highest average mood (ties broken by most recent).
  private var bestDay: DailyAverage? {
    dailyAverages.max { lhs, rhs in
      if lhs.average == rhs.average { return lhs.day < rhs.day }
      return lhs.average < rhs.average
    }
  }

  /// Difference between the second-half and first-half average of the range,
  /// in mood points. Positive = improving. Nil when there aren't two halves.
  private var trendDelta: Double? {
    let sorted = dailyAverages
    guard sorted.count >= 2 else { return nil }
    let mid = sorted.count / 2
    let firstHalf = sorted[0..<mid]
    let secondHalf = sorted[mid...]
    guard !firstHalf.isEmpty, !secondHalf.isEmpty else { return nil }
    let firstAvg = firstHalf.map(\.average).reduce(0, +) / Double(firstHalf.count)
    let secondAvg = secondHalf.map(\.average).reduce(0, +) / Double(secondHalf.count)
    return secondAvg - firstAvg
  }

  private var headlineTiles: [StatTileData] {
    let avgValue = averageMood.map { String(format: "%.1f", $0) } ?? "—"
    let avgEmoji = averageMood.flatMap { MoodCatalog.shared.option(forValue: Int($0.rounded()))?.emoji }

    let bestValue: String
    let bestSub: String?
    if let best = bestDay {
      bestValue = MoodCatalog.shared.option(forValue: Int(best.average.rounded()))?.emoji ?? "—"
      bestSub = shortDate(best.day)
    } else {
      bestValue = "—"
      bestSub = nil
    }

    let trendValue: String
    let trendTint: Color
    if let delta = trendDelta, abs(delta) >= 0.05 {
      let arrow = delta > 0 ? "▲" : "▼"
      trendValue = "\(arrow) \(String(format: "%.1f", abs(delta)))"
      trendTint = delta > 0 ? DLColor.success : DLColor.warning
    } else if trendDelta != nil {
      trendValue = "→"
      trendTint = DLColor.textSecondary
    } else {
      trendValue = "—"
      trendTint = DLColor.textPrimary
    }

    return [
      StatTileData(
        value: avgValue,
        label: L("Average mood"),
        sublabel: avgEmoji,
        tint: DLColor.accent
      ),
      StatTileData(
        value: "\(daysLogged)",
        label: L("Days logged")
      ),
      StatTileData(
        value: bestValue,
        label: L("Best mood day"),
        sublabel: bestSub
      ),
      StatTileData(
        value: trendValue,
        label: L("Trend vs first half"),
        tint: trendTint
      ),
    ]
  }

  // MARK: - Body

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DLSpace.lg) {
        EditorialHeader(L("MOOD"), L("Mood Report"))

        SlidingSegmentedControl(
          items: StatsRange.allCases,
          label: { $0.label },
          selection: $range,
          accent: DLColor.accent
        )
        .accessibilityLabel(L("Mood range"))

        if samples.isEmpty {
          emptyState
        } else {
          StatTileGrid(tiles: headlineTiles)

          Hairline()
          trendSection

          Hairline()
          distributionSection

          Hairline()
          weekdaySection
        }
      }
      .padding(.horizontal, DLSpace.lg)
      .padding(.vertical, DLSpace.lg)
    }
    .background(ThemedBackground())
    .navigationBarTitleDisplayMode(.inline)
    .animation(animate ? DLAnim.standard : nil, value: range)
  }

  // MARK: - Sections

  private var emptyState: some View {
    VStack(spacing: DLSpace.md) {
      Image(systemName: "face.dashed")
        .font(.system(size: 40, weight: .light))
        .foregroundStyle(DLColor.textTertiary)
      Text(L("No mood data in this range"))
        .font(.serif(.title3, weight: .semibold))
        .foregroundStyle(DLColor.textPrimary)
        .multilineTextAlignment(.center)
      Text(L("Log a reflection or add a mood to a note to see your report."))
        .font(.dl(.subheadline))
        .foregroundStyle(DLColor.textSecondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, DLSpace.xl)
  }

  private var trendSection: some View {
    VStack(alignment: .leading, spacing: DLSpace.md) {
      SectionLabel(L("Trend"))
      Chart(dailyAverages) { point in
        AreaMark(
          x: .value("Day", point.day, unit: .day),
          y: .value("Mood", point.average)
        )
        .interpolationMethod(.catmullRom)
        .foregroundStyle(
          LinearGradient(
            colors: [DLColor.accent.opacity(0.30), DLColor.accent.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom
          )
        )

        LineMark(
          x: .value("Day", point.day, unit: .day),
          y: .value("Mood", point.average)
        )
        .interpolationMethod(.catmullRom)
        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
        .foregroundStyle(DLColor.accent)
      }
      .chartYScale(domain: 1...Double(MoodCatalog.shared.maxValue))
      .chartYAxis {
        AxisMarks(values: MoodCatalog.shared.options.map { Double($0.value) }) { value in
          AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.4))
          AxisValueLabel {
            if let raw = value.as(Double.self),
               let mood = MoodCatalog.shared.option(forValue: Int(raw)) {
              Text(mood.emoji).font(.system(size: 12))
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
      .animation(animate ? DLAnim.standard : nil, value: dailyAverages.map(\.average))
    }
  }

  private var distributionSection: some View {
    VStack(alignment: .leading, spacing: DLSpace.md) {
      SectionLabel(L("Distribution"))
      let maxCount = max(1, countByValue.values.max() ?? 1)
      VStack(spacing: DLSpace.sm) {
        ForEach(MoodCatalog.shared.options) { option in
          let count = countByValue[option.value, default: 0]
          distributionRow(option: option, count: count, maxCount: maxCount)
        }
      }
    }
  }

  private func distributionRow(option: MoodOption, count: Int, maxCount: Int) -> some View {
    HStack(spacing: DLSpace.md) {
      Text(option.emoji)
        .font(.system(size: 20))
        .frame(width: 28)

      Text(option.displayName)
        .font(.dl(.subheadline, weight: .medium))
        .foregroundStyle(DLColor.textPrimary)
        .frame(width: 96, alignment: .leading)
        .lineLimit(1)

      GeometryReader { geo in
        let fraction = maxCount > 0 ? CGFloat(count) / CGFloat(maxCount) : 0
        ZStack(alignment: .leading) {
          Capsule()
            .fill(DLColor.separator.opacity(0.35))
            .frame(height: 10)
          Capsule()
            .fill(
              LinearGradient(
                colors: [option.color, option.color.opacity(0.55)],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .frame(width: max(count > 0 ? 10 : 0, geo.size.width * fraction), height: 10)
        }
        .frame(maxHeight: .infinity, alignment: .center)
      }
      .frame(height: 16)

      Text("\(count)")
        .font(.dl(.subheadline, weight: .semibold))
        .foregroundStyle(DLColor.textSecondary)
        .monospacedDigit()
        .frame(width: 32, alignment: .trailing)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Lf("%@: %d", option.displayName, count))
  }

  private var weekdaySection: some View {
    VStack(alignment: .leading, spacing: DLSpace.md) {
      SectionLabel(L("By weekday"))

      let plotted = weekdayAverages.filter { $0.average != nil }
      Chart(weekdayAverages) { item in
        BarMark(
          x: .value("Weekday", item.name),
          y: .value("Mood", item.average ?? 0)
        )
        .cornerRadius(4)
        // Vertical gradient fill (item 5); empty weekdays collapse to nothing.
        .foregroundStyle(
          LinearGradient(
            colors: [DLColor.accent, DLColor.accent.opacity(0.55)],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .opacity(item.average == nil ? 0 : 1)
      }
      .chartXScale(domain: weekdayAverages.map(\.name))
      .chartYScale(domain: 0...Double(MoodCatalog.shared.maxValue))
      .chartYAxis {
        AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
          AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.4))
          AxisValueLabel {
            if let raw = value.as(Double.self) {
              Text(String(format: "%.0f", raw))
                .font(.dl(.caption2))
                .foregroundStyle(DLColor.textSecondary)
            }
          }
        }
      }
      .chartXAxis {
        AxisMarks { value in
          AxisValueLabel {
            if let label = value.as(String.self) {
              Text(label)
                .font(.dl(.caption2))
                .foregroundStyle(DLColor.textSecondary)
            }
          }
        }
      }
      .frame(height: 190)
      .animation(animate ? DLAnim.standard : nil, value: plotted.map(\.average))

      if let caption = weekdayCaption {
        Text(caption)
          .font(.dl(.caption))
          .foregroundStyle(DLColor.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  /// "Mondays are your best day; Thursdays your hardest." style note.
  private var weekdayCaption: String? {
    let active = weekdayAverages.compactMap { wa -> (String, Double)? in
      guard let avg = wa.average else { return nil }
      return (wa.name, avg)
    }
    guard let best = active.max(by: { $0.1 < $1.1 }),
          let worst = active.min(by: { $0.1 < $1.1 }) else { return nil }
    if best.0 == worst.0 {
      return Lf("Best weekday: %@ (%.1f)", best.0, best.1)
    }
    return Lf("Best: %@ (%.1f) · Hardest: %@ (%.1f)", best.0, best.1, worst.0, worst.1)
  }

  // MARK: - Helpers

  private func shortDate(_ date: Date) -> String {
    date.formatted(.dateTime.month(.abbreviated).day())
  }
}
