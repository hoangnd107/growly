import SwiftUI
import SwiftData
import Charts

/// A 30-day bar chart of XP earned per day, sourced from `XPTransaction`.
struct XPHistoryChart: View {
  /// All XP transactions, newest first. The view buckets them by day itself.
  let transactions: [XPTransaction]

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Tap-selected day on the x-axis (bound to `.chartXSelection`).
  @State private var selectedDate: Date?

  private let dayCount = 30

  /// One bucket per day for the last `dayCount` days (oldest -> newest),
  /// each holding the summed XP for that day (0 when nothing was earned).
  private var dailyXP: [DayXP] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    // Pre-sum transactions by day to avoid an O(days * transactions) scan.
    var totals: [Date: Int] = [:]
    for tx in transactions {
      let day = calendar.startOfDay(for: tx.date)
      totals[day, default: 0] += tx.amount
    }

    return (0..<dayCount).reversed().compactMap { offset in
      guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
      return DayXP(day: day, xp: totals[day] ?? 0)
    }
  }

  private var totalXP: Int { dailyXP.reduce(0) { $0 + $1.xp } }
  private var bestDay: Int { dailyXP.map(\.xp).max() ?? 0 }

  /// The day bucket closest to the current selection, if any.
  private var selectedDay: DayXP? {
    guard let selectedDate else { return nil }
    let calendar = Calendar.current
    if let exact = dailyXP.first(where: { calendar.isDate($0.day, inSameDayAs: selectedDate) }) {
      return exact
    }
    return dailyXP.min {
      abs($0.day.timeIntervalSince(selectedDate)) < abs($1.day.timeIntervalSince(selectedDate))
    }
  }

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        HStack {
          Label("XP · last 30 days", systemImage: "chart.bar.fill")
            .font(.dl(.headline, weight: .semibold))
            .foregroundStyle(DLColor.xpGold)
          Spacer()
          Text("\(totalXP) XP")
            .font(.dl(.subheadline, weight: .bold))
            .foregroundStyle(DLColor.textSecondary)
            .monospacedDigit()
        }

        if totalXP == 0 {
          Text("Complete a daily review to start earning XP. Your last 30 days will chart here.")
            .font(.dl(.subheadline))
            .foregroundStyle(DLColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DLSpace.lg)
        } else {
          chart
            .frame(height: 180)
        }
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("XP earned over the last 30 days. Total \(totalXP) experience points, best day \(bestDay).")
  }

  private var chart: some View {
    Chart {
      ForEach(dailyXP) { item in
        BarMark(
          x: .value("Day", item.day, unit: .day),
          y: .value("XP", item.xp)
        )
        .foregroundStyle(
          LinearGradient(
            colors: [DLColor.xpGold, DLColor.streakStart],
            startPoint: .bottom,
            endPoint: .top
          )
        )
        .cornerRadius(3)
      }

      // Tapped marker: a vertical rule plus an annotation bubble with the XP.
      if let selected = selectedDay {
        RuleMark(x: .value("Day", selected.day, unit: .day))
          .foregroundStyle(DLColor.textTertiary.opacity(0.5))
          .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
          .annotation(
            position: .top,
            spacing: 6,
            overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
          ) {
            VStack(alignment: .leading, spacing: 2) {
              Text(selected.day, format: .dateTime.month(.abbreviated).day())
                .font(.dl(.caption2))
                .foregroundStyle(DLColor.textSecondary)
              Text("\(selected.xp) XP")
                .font(.dl(.caption, weight: .semibold))
                .foregroundStyle(DLColor.xpGold)
                .monospacedDigit()
            }
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
    }
    .chartXSelection(value: $selectedDate)
    .chartYAxis {
      AxisMarks(position: .leading) { value in
        AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.4))
        AxisValueLabel {
          if let xp = value.as(Int.self) {
            Text("\(xp)")
              .font(.dl(.caption2))
              .foregroundStyle(DLColor.textTertiary)
          }
        }
      }
    }
    .chartXAxis {
      AxisMarks(values: .stride(by: .day, count: 7)) { value in
        AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.3))
        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
      }
    }
    .animation(reduceMotion ? nil : DLAnim.standard, value: dailyXP)
    .animation(reduceMotion ? nil : DLAnim.quick, value: selectedDate)
  }
}

/// A single day's XP total, plotted as one bar.
private struct DayXP: Identifiable, Equatable {
  let day: Date
  let xp: Int
  var id: Date { day }
}
