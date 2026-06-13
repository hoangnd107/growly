import SwiftUI
import Charts

// MARK: - Shared data points

/// One point in the 14-day mood series. `mood` is nil for days with no entry,
/// which lets the LineMark skip gaps instead of drawing through zero.
struct MoodPoint: Identifiable {
  let id = UUID()
  let day: Date
  let mood: Int?
}

/// XP earned on a single day (already summed across transactions).
struct DailyXPPoint: Identifiable {
  let id = UUID()
  let day: Date
  let xp: Int
}

/// Count of entries logged on a given Mood value, for the distribution chart.
struct MoodCountPoint: Identifiable {
  let id = UUID()
  let mood: Mood
  let count: Int
}

/// A point on the cumulative-reviews growth curve.
struct CumulativePoint: Identifiable {
  let id = UUID()
  let day: Date
  let total: Int
}

// MARK: - Mood over time (last 14 days)

struct MoodTrendChart: View {
  let points: [MoodPoint]
  let animate: Bool

  /// Only the days that actually have a mood, so PointMark/LineMark skip gaps.
  private var filled: [MoodPoint] { points.filter { $0.mood != nil } }

  var body: some View {
    Chart(filled) { point in
      LineMark(
        x: .value("Day", point.day, unit: .day),
        y: .value("Mood", point.mood ?? 0)
      )
      .interpolationMethod(.catmullRom)
      .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
      .foregroundStyle(Color.accentColor.gradient)

      PointMark(
        x: .value("Day", point.day, unit: .day),
        y: .value("Mood", point.mood ?? 0)
      )
      .symbolSize(60)
      .foregroundStyle((Mood(rawValue: point.mood ?? 3) ?? .neutral).color)
    }
    .chartYScale(domain: 1...5)
    .chartYAxis {
      AxisMarks(values: [1, 2, 3, 4, 5]) { value in
        AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.5))
        AxisValueLabel {
          if let raw = value.as(Int.self), let mood = Mood(rawValue: raw) {
            Text(mood.emoji).font(.system(size: 13))
          }
        }
      }
    }
    .chartXAxis {
      AxisMarks(values: .stride(by: .day, count: 3)) { value in
        AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.4))
        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textSecondary)
      }
    }
    .frame(height: 180)
    .animation(animate ? DLAnim.standard : nil, value: filled.count)
  }
}

// MARK: - XP per day (last 14 days)

struct XPPerDayChart: View {
  let points: [DailyXPPoint]
  let animate: Bool

  var body: some View {
    Chart(points) { point in
      BarMark(
        x: .value("Day", point.day, unit: .day),
        y: .value("XP", point.xp)
      )
      .cornerRadius(4)
      .foregroundStyle(
        LinearGradient(
          colors: [DLColor.xpGold, DLColor.warning],
          startPoint: .bottom,
          endPoint: .top
        )
      )
    }
    .chartYAxis {
      AxisMarks(position: .leading) { value in
        AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.5))
        AxisValueLabel {
          if let xp = value.as(Int.self) {
            Text("\(xp)")
              .font(.dl(.caption2))
              .foregroundStyle(DLColor.textSecondary)
          }
        }
      }
    }
    .chartXAxis {
      AxisMarks(values: .stride(by: .day, count: 3)) { _ in
        AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.4))
        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textSecondary)
      }
    }
    .frame(height: 170)
    .animation(animate ? DLAnim.standard : nil, value: points.map(\.xp))
  }
}

// MARK: - Mood distribution (horizontal bars)

struct MoodDistributionChart: View {
  let points: [MoodCountPoint]
  let animate: Bool

  private var maxCount: Int { max(1, points.map(\.count).max() ?? 1) }

  var body: some View {
    Chart(points) { point in
      BarMark(
        x: .value("Count", point.count),
        y: .value("Mood", point.mood.label)
      )
      .cornerRadius(6)
      .foregroundStyle(point.mood.color)
      .annotation(position: .trailing, alignment: .leading) {
        if point.count > 0 {
          Text("\(point.count)")
            .font(.dl(.caption2, weight: .semibold))
            .foregroundStyle(DLColor.textSecondary)
            .monospacedDigit()
        }
      }
    }
    // Stable top-to-bottom ordering: Great … Awful.
    .chartYScale(domain: Mood.allCases.reversed().map(\.label))
    .chartXScale(domain: 0...(maxCount + 1))
    .chartXAxis {
      AxisMarks { value in
        AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.4))
        AxisValueLabel {
          if let count = value.as(Int.self) {
            Text("\(count)")
              .font(.dl(.caption2))
              .foregroundStyle(DLColor.textSecondary)
          }
        }
      }
    }
    .chartYAxis {
      AxisMarks { value in
        AxisValueLabel {
          if let label = value.as(String.self) {
            Text(label)
              .font(.dl(.caption))
              .foregroundStyle(DLColor.textPrimary)
          }
        }
      }
    }
    .frame(height: 200)
    .animation(animate ? DLAnim.standard : nil, value: points.map(\.count))
  }
}

// MARK: - Compound growth curve (cumulative reviews over time)

struct GrowthCurveChart: View {
  let points: [CumulativePoint]
  let animate: Bool

  var body: some View {
    Chart(points) { point in
      AreaMark(
        x: .value("Day", point.day, unit: .day),
        y: .value("Reviews", point.total)
      )
      .interpolationMethod(.monotone)
      .foregroundStyle(
        LinearGradient(
          colors: [DLColor.success.opacity(0.35), DLColor.success.opacity(0.02)],
          startPoint: .top,
          endPoint: .bottom
        )
      )

      LineMark(
        x: .value("Day", point.day, unit: .day),
        y: .value("Reviews", point.total)
      )
      .interpolationMethod(.monotone)
      .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
      .foregroundStyle(DLColor.success.gradient)
    }
    .chartYAxis {
      AxisMarks(position: .leading) { value in
        AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.4))
        AxisValueLabel {
          if let total = value.as(Int.self) {
            Text("\(total)")
              .font(.dl(.caption2))
              .foregroundStyle(DLColor.textSecondary)
          }
        }
      }
    }
    .chartXAxis {
      AxisMarks(values: .automatic(desiredCount: 4)) { _ in
        AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.3))
        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textSecondary)
      }
    }
    .frame(height: 120)
    .animation(animate ? DLAnim.standard : nil, value: points.map(\.total))
  }
}
