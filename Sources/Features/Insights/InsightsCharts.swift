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

/// Count of entries logged on a given mood, for the distribution chart.
struct MoodCountPoint: Identifiable {
  let id = UUID()
  let mood: MoodOption
  let count: Int
}

/// A point on the cumulative-reviews growth curve.
struct CumulativePoint: Identifiable {
  let id = UUID()
  let day: Date
  let total: Int
}

// MARK: - Selection helpers

/// Small floating bubble used to label a tapped chart value. Reuses the app's
/// glassy surface so it reads as part of the design system.
private struct ChartSelectionBubble<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    content
      .padding(.horizontal, DLSpace.sm)
      .padding(.vertical, DLSpace.xs)
      .background(
        RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous)
          .fill(.ultraThinMaterial)
      )
      .overlay(
        RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous)
          .strokeBorder(DLColor.separator.opacity(0.6), lineWidth: 1)
      )
      .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
      .fixedSize()
  }
}

/// Returns the element of `points` whose `day` falls on the same calendar day as
/// `date`, choosing the nearest day when there is no exact match.
private func nearest<T>(
  to date: Date?,
  in points: [T],
  day keyPath: KeyPath<T, Date>
) -> T? {
  guard let date else { return nil }
  let calendar = Calendar.current
  if let exact = points.first(where: { calendar.isDate($0[keyPath: keyPath], inSameDayAs: date) }) {
    return exact
  }
  return points.min { lhs, rhs in
    abs(lhs[keyPath: keyPath].timeIntervalSince(date)) < abs(rhs[keyPath: keyPath].timeIntervalSince(date))
  }
}

private let chartDateLabel: Date.FormatStyle =
  .dateTime.month(.abbreviated).day()

// MARK: - Mood over time (last 14 days)

struct MoodTrendChart: View {
  let points: [MoodPoint]
  let animate: Bool

  /// Tap-selected day on the x-axis (bound to `.chartXSelection`).
  @State private var selectedDate: Date?

  /// Only the days that actually have a mood, so PointMark/LineMark skip gaps.
  private var filled: [MoodPoint] { points.filter { $0.mood != nil } }

  /// The filled point closest to the current selection, if any.
  private var selectedPoint: MoodPoint? {
    nearest(to: selectedDate, in: filled, day: \.day)
  }

  var body: some View {
    Chart {
      ForEach(filled) { point in
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
        .foregroundStyle(MoodCatalog.shared.option(forValue: point.mood ?? 3)?.color ?? DLColor.textTertiary)
      }

      // Tapped marker: a vertical rule plus an annotation bubble.
      if let selected = selectedPoint, let raw = selected.mood,
         let mood = MoodCatalog.shared.option(forValue: raw) {
        RuleMark(x: .value("Day", selected.day, unit: .day))
          .foregroundStyle(DLColor.textTertiary.opacity(0.5))
          .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
          .annotation(
            position: .top,
            spacing: 6,
            overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
          ) {
            ChartSelectionBubble {
              VStack(alignment: .leading, spacing: 2) {
                Text(selected.day, format: chartDateLabel)
                  .font(.dl(.caption2))
                  .foregroundStyle(DLColor.textSecondary)
                HStack(spacing: 4) {
                  Text(mood.emoji).font(.system(size: 14))
                  Text(mood.displayName)
                    .font(.dl(.caption, weight: .semibold))
                    .foregroundStyle(mood.color)
                }
              }
            }
          }

        PointMark(
          x: .value("Day", selected.day, unit: .day),
          y: .value("Mood", raw)
        )
        .symbolSize(120)
        .foregroundStyle(mood.color)
      }
    }
    .chartXSelection(value: $selectedDate)
    .chartYScale(domain: 1...MoodCatalog.shared.maxValue)
    .chartYAxis {
      AxisMarks(values: MoodCatalog.shared.options.map(\.value)) { value in
        AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.5))
        AxisValueLabel {
          if let raw = value.as(Int.self), let mood = MoodCatalog.shared.option(forValue: raw) {
            Text(mood.emoji).font(.system(size: 13))
          }
        }
      }
    }
    .chartXAxis {
      AxisMarks(values: .automatic(desiredCount: 6)) { _ in
        AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.4))
        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textSecondary)
      }
    }
    .frame(height: 180)
    .animation(animate ? DLAnim.standard : nil, value: filled.count)
    .animation(animate ? DLAnim.quick : nil, value: selectedDate)
  }
}

// MARK: - XP per day (last 14 days)

struct XPPerDayChart: View {
  let points: [DailyXPPoint]
  let animate: Bool

  /// Tap-selected day on the x-axis (bound to `.chartXSelection`).
  @State private var selectedDate: Date?

  private var selectedPoint: DailyXPPoint? {
    nearest(to: selectedDate, in: points, day: \.day)
  }

  var body: some View {
    Chart {
      ForEach(points) { point in
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

      // Tapped marker: a vertical rule plus an annotation bubble with the XP.
      if let selected = selectedPoint {
        RuleMark(x: .value("Day", selected.day, unit: .day))
          .foregroundStyle(DLColor.textTertiary.opacity(0.5))
          .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
          .annotation(
            position: .top,
            spacing: 6,
            overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
          ) {
            ChartSelectionBubble {
              VStack(alignment: .leading, spacing: 2) {
                Text(selected.day, format: chartDateLabel)
                  .font(.dl(.caption2))
                  .foregroundStyle(DLColor.textSecondary)
                Text("\(selected.xp) XP")
                  .font(.dl(.caption, weight: .semibold))
                  .foregroundStyle(DLColor.xpGold)
                  .monospacedDigit()
              }
            }
          }
      }
    }
    .chartXSelection(value: $selectedDate)
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
      AxisMarks(values: .automatic(desiredCount: 6)) { _ in
        AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.4))
        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textSecondary)
      }
    }
    .frame(height: 170)
    .animation(animate ? DLAnim.standard : nil, value: points.map(\.xp))
    .animation(animate ? DLAnim.quick : nil, value: selectedDate)
  }
}

// MARK: - Mood distribution (horizontal bars)

struct MoodDistributionChart: View {
  let points: [MoodCountPoint]
  let animate: Bool

  /// Tap-selected mood value. Categorical (count) charts have no meaningful
  /// `.chartXSelection` on the value axis, so we drive selection from a tap on
  /// the plot area via `.chartOverlay` instead and emphasize the chosen bar.
  @State private var selectedValue: Int?

  private var maxCount: Int { max(1, points.map(\.count).max() ?? 1) }

  var body: some View {
    Chart(points) { point in
      BarMark(
        x: .value("Count", point.count),
        y: .value("Mood", point.mood.displayName)
      )
      .cornerRadius(6)
      .foregroundStyle(point.mood.color)
      // Dim the non-selected bars once a selection exists.
      .opacity(selectedValue == nil || selectedValue == point.mood.value ? 1 : 0.35)
      .annotation(position: .trailing, alignment: .leading) {
        if point.count > 0 {
          Text("\(point.count)")
            .font(.dl(.caption2, weight: selectedValue == point.mood.value ? .bold : .semibold))
            .foregroundStyle(selectedValue == point.mood.value ? point.mood.color : DLColor.textSecondary)
            .monospacedDigit()
        }
      }
    }
    // Stable top-to-bottom ordering: best … worst.
    .chartYScale(domain: MoodCatalog.shared.options.reversed().map(\.displayName))
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
    // Map a tap's vertical position to the bar it landed on and toggle it.
    .chartOverlay { proxy in
      GeometryReader { geo in
        Rectangle()
          .fill(.clear)
          .contentShape(Rectangle())
          .onTapGesture { location in
            guard let plotFrame = proxy.plotFrame else { return }
            let origin = geo[plotFrame].origin
            let yInPlot = location.y - origin.y
            if let label: String = proxy.value(atY: yInPlot),
               let mood = MoodCatalog.shared.options.first(where: { $0.displayName == label }) {
              selectedValue = (selectedValue == mood.value) ? nil : mood.value
            } else {
              selectedValue = nil
            }
          }
      }
    }
    .frame(height: 200)
    .animation(animate ? DLAnim.standard : nil, value: points.map(\.count))
    .animation(animate ? DLAnim.quick : nil, value: selectedValue)
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

// MARK: - Monthly entries/notes (Stats)

/// A stacked monthly bar chart of entry vs note counts across a year. Feeds the
/// Stats card; consumes `MonthCount` from `ActivityStats`.
struct MonthlyCountChart: View {
  let points: [MonthCount]
  let entriesLabel: String
  let notesLabel: String
  let entriesColor: Color
  let notesColor: Color
  let animate: Bool
  /// Tapped month label (feature 9). Optional so the chart works without selection.
  var selection: Binding<String?>? = nil

  private var selectedLabel: String? { selection?.wrappedValue }

  var body: some View {
    Chart {
      ForEach(points) { point in
        BarMark(
          x: .value("Month", point.label),
          y: .value("Count", point.entries)
        )
        .foregroundStyle(by: .value("Type", entriesLabel))
        .cornerRadius(3)
        .opacity(selectedLabel == nil || selectedLabel == point.label ? 1 : 0.35)

        BarMark(
          x: .value("Month", point.label),
          y: .value("Count", point.notes)
        )
        .foregroundStyle(by: .value("Type", notesLabel))
        .cornerRadius(3)
        .opacity(selectedLabel == nil || selectedLabel == point.label ? 1 : 0.35)
      }
    }
    .chartXSelectionOptional(selection)
    .chartForegroundStyleScale([entriesLabel: entriesColor, notesLabel: notesColor])
    .chartXScale(domain: points.map(\.label))
    .chartLegend(position: .bottom, spacing: DLSpace.sm)
    .chartYAxis {
      AxisMarks(position: .leading) { value in
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
    .chartXAxis {
      AxisMarks { value in
        AxisValueLabel {
          if let label = value.as(String.self) {
            Text(label)
              .font(.system(size: 9))
              .foregroundStyle(DLColor.textSecondary)
          }
        }
      }
    }
    // Map a tap's horizontal position to the column it landed on and select it.
    // Works reliably even inside a scroll view and for zero-height (empty) bars.
    .chartOverlay { proxy in
      GeometryReader { geo in
        Rectangle()
          .fill(.clear)
          .contentShape(Rectangle())
          .onTapGesture { location in
            guard let selection, let plotFrame = proxy.plotFrame else { return }
            let xInPlot = location.x - geo[plotFrame].origin.x
            if let label: String = proxy.value(atX: xInPlot) {
              selection.wrappedValue = label
            }
          }
      }
    }
    .frame(height: 200)
    .animation(animate ? DLAnim.standard : nil, value: points)
    .animation(animate ? DLAnim.quick : nil, value: selectedLabel)
  }
}

private extension View {
  /// Applies `.chartXSelection` only when a binding is supplied, so the chart can
  /// be used both with and without tap selection.
  @ViewBuilder
  func chartXSelectionOptional(_ binding: Binding<String?>?) -> some View {
    if let binding {
      self.chartXSelection(value: binding)
    } else {
      self
    }
  }
}
