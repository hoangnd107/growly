import SwiftUI
import SwiftData
import Charts

/// A bar chart of XP earned over a selectable time range, sourced from
/// `XPTransaction`. Buckets by day for short ranges and by week/month for longer
/// ones so the chart stays readable (redesign v2: every stats view filters by
/// time, using the shared `StatsRange` + `SlidingSegmentedControl`).
struct XPHistoryChart: View {
  /// All XP transactions, newest first. The view buckets them itself.
  let transactions: [XPTransaction]

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var range: StatsRange = .month
  /// Tap-selected bucket on the x-axis (bound to `.chartXSelection`).
  @State private var selectedDate: Date?

  private let calendar = Calendar.current

  private func dayStart(_ date: Date) -> Date { calendar.startOfDay(for: date) }

  /// Contiguous daily buckets (oldest → newest) with summed XP, zero-filled.
  /// Daily granularity keeps the Charts `unit:` a literal `.day`; longer ranges
  /// simply render as a denser run of thin bars.
  private var bars: [DayXP] {
    let now = Date()
    let today = dayStart(now)

    // Window start: the range start, or the earliest transaction for "all".
    let start: Date
    if let rangeStart = range.startDate(now: now, calendar: calendar) {
      start = dayStart(rangeStart)
    } else if let earliest = transactions.map(\.date).min() {
      start = dayStart(earliest)
    } else {
      start = today
    }

    var totals: [Date: Int] = [:]
    for tx in transactions where tx.date >= start {
      totals[dayStart(tx.date), default: 0] += tx.amount
    }

    var out: [DayXP] = []
    var cursor = start
    var safety = 0
    while cursor <= today && safety < 1500 {
      out.append(DayXP(day: cursor, xp: totals[cursor] ?? 0))
      guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
      cursor = next
      safety += 1
    }
    return out
  }

  private var totalXP: Int { bars.reduce(0) { $0 + $1.xp } }
  private var bestDay: Int { bars.map(\.xp).max() ?? 0 }

  /// The bucket closest to the current selection, if any.
  private var selectedBar: DayXP? {
    guard let selectedDate else { return nil }
    return bars.min {
      abs($0.day.timeIntervalSince(selectedDate)) < abs($1.day.timeIntervalSince(selectedDate))
    }
  }

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        HStack {
          Label(L("XP earned"), systemImage: "chart.bar.fill")
            .font(.dl(.headline, weight: .semibold))
            .foregroundStyle(DLColor.xpGold)
          Spacer()
          Text(Lf("%d XP", totalXP))
            .font(.dl(.subheadline, weight: .bold))
            .foregroundStyle(DLColor.textSecondary)
            .monospacedDigit()
            .contentTransition(.numericText())
        }

        SlidingSegmentedControl(
          items: StatsRange.allCases,
          label: { $0.label },
          selection: $range,
          accent: DLColor.xpGold
        )

        if totalXP == 0 {
          Text(L("Complete a daily review to start earning XP. It will chart here."))
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
    .animation(reduceMotion ? nil : DLAnim.standard, value: range)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Lf("XP earned. Total %d points, best %d.", totalXP, bestDay))
  }

  private var chart: some View {
    Chart {
      ForEach(bars) { item in
        BarMark(
          x: .value("Date", item.day, unit: .day),
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
      if let selected = selectedBar {
        RuleMark(x: .value("Date", selected.day, unit: .day))
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
              Text(Lf("%d XP", selected.xp))
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
      AxisMarks(values: .automatic(desiredCount: 5)) { _ in
        AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.3))
        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
      }
    }
    .animation(reduceMotion ? nil : DLAnim.standard, value: bars)
    .animation(reduceMotion ? nil : DLAnim.quick, value: selectedDate)
  }
}

/// A single bucket's XP total, plotted as one bar.
private struct DayXP: Identifiable, Equatable {
  let day: Date
  let xp: Int
  var id: Date { day }
}
