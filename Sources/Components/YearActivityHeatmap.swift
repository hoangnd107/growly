import SwiftUI

/// A GitHub-contributions-style heatmap for a single calendar year: 7 day-rows ×
/// however many week-columns span Jan 1 → Dec 31 of `year`. Each in-year,
/// non-future day is colored by the `fill` closure; days that spill in from the
/// neighbouring year (in the first/last week column) and future days render
/// empty so the grid stays aligned.
///
/// Shared so the "year" view looks identical everywhere it appears (items 4 & 6):
/// Consistency, per-habit analytics, and the Insights mood calendar. Scrolls
/// horizontally if the columns overflow.
struct YearActivityHeatmap: View {
  let year: Int
  var reduceMotion: Bool = false
  /// Returns the fill color for an in-year, non-future day (start-of-day).
  let fill: (Date) -> Color

  private let cell: CGFloat = 11
  private let gap: CGFloat = 3
  private let calendar = Calendar.current

  var body: some View {
    let weeks = buildWeeks()

    ScrollView(.horizontal, showsIndicators: false) {
      VStack(alignment: .leading, spacing: gap) {
        monthLabels(for: weeks)
        HStack(alignment: .top, spacing: gap) {
          ForEach(weeks) { week in
            VStack(spacing: gap) {
              ForEach(week.days) { day in
                cellView(day)
              }
            }
          }
        }
      }
      .padding(.vertical, DLSpace.xs)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Lf("Activity heatmap for %d", year))
  }

  // MARK: Cells

  private func cellView(_ day: YearDay) -> some View {
    let visible = day.inYear && !day.isFuture
    return RoundedRectangle(cornerRadius: 2.5, style: .continuous)
      .fill(visible ? fill(day.date) : Color.clear)
      .frame(width: cell, height: cell)
      .overlay(
        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
          .strokeBorder(DLColor.separator.opacity(0.25), lineWidth: visible ? 0.5 : 0)
      )
      .opacity(visible ? 1 : 0)
  }

  // MARK: Month tick labels

  /// One slot per column; shows the abbreviated month name at the first column
  /// whose week-start lands in a new month within the year. The label is drawn
  /// un-clamped so it overflows rightward instead of wrapping (matching the
  /// Consistency heatmap), while a clear spacer keeps the columns registered.
  private func monthLabels(for weeks: [YearWeek]) -> some View {
    let symbols = calendar.shortStandaloneMonthSymbols
    var lastMonth = -1
    var labels: [String] = []
    for week in weeks {
      let month = calendar.component(.month, from: week.weekStart)
      let weekYear = calendar.component(.year, from: week.weekStart)
      if weekYear == year, month != lastMonth {
        lastMonth = month
        labels.append(symbols.indices.contains(month - 1) ? symbols[month - 1] : "")
      } else {
        labels.append("")
      }
    }
    return HStack(spacing: gap) {
      ForEach(Array(labels.enumerated()), id: \.offset) { _, text in
        Color.clear
          .frame(width: cell, height: 12)
          .overlay(alignment: .topLeading) {
            Text(text)
              .font(.dl(.caption2))
              .foregroundStyle(DLColor.textTertiary)
              .lineLimit(1)
              .fixedSize()
          }
      }
    }
  }

  // MARK: Grid construction

  private func buildWeeks() -> [YearWeek] {
    let today = calendar.startOfDay(for: Date())
    guard
      let jan1 = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
      let dec31 = calendar.date(from: DateComponents(year: year, month: 12, day: 31))
    else { return [] }

    let firstWeekStart = startOfWeek(containing: jan1)
    let lastWeekStart = startOfWeek(containing: dec31)
    let spanDays = calendar.dateComponents([.day], from: firstWeekStart, to: lastWeekStart).day ?? 364
    let weekCount = max(1, spanDays / 7 + 1)

    var result: [YearWeek] = []
    result.reserveCapacity(weekCount)
    for weekIndex in 0..<weekCount {
      guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekIndex, to: firstWeekStart) else { continue }
      var dayCells: [YearDay] = []
      dayCells.reserveCapacity(7)
      for offset in 0..<7 {
        guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { continue }
        let key = calendar.startOfDay(for: date)
        dayCells.append(
          YearDay(
            date: key,
            inYear: calendar.component(.year, from: key) == year,
            isFuture: key > today
          )
        )
      }
      result.append(YearWeek(weekStart: weekStart, days: dayCells))
    }
    return result
  }

  /// Start of the week containing `date`, honoring the calendar's `firstWeekday`.
  private func startOfWeek(containing date: Date) -> Date {
    let start = calendar.startOfDay(for: date)
    let weekday = calendar.component(.weekday, from: start)
    let diff = (weekday - calendar.firstWeekday + 7) % 7
    return calendar.date(byAdding: .day, value: -diff, to: start) ?? start
  }
}

// MARK: - Data points

private struct YearWeek: Identifiable {
  let id = UUID()
  let weekStart: Date
  let days: [YearDay]
}

private struct YearDay: Identifiable {
  var id: Date { date }
  let date: Date
  let inYear: Bool
  let isFuture: Bool
}
