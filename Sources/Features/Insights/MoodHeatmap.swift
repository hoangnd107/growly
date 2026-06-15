import SwiftUI

// MARK: - Mood heatmap (GitHub-contributions-style)

/// A GitHub-contributions-style grid of the last ~16 weeks of moods.
/// Columns are weeks (oldest → newest, left → right), rows are weekdays
/// (top = the calendar's first weekday). Each populated day is a small
/// rounded square tinted by that day's `Entry.mood.color`; days with no
/// entry render as a faint separator-colored placeholder.
///
/// Pure `Calendar` math, no Charts dependency. Reduce-motion aware.
struct MoodHeatmap: View {
  let entries: [Entry]

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Number of week columns to display.
  private let weekCount = 16
  /// Side length of each day cell.
  private let cell: CGFloat = 14
  /// Gap between cells (and between rows).
  private let gap: CGFloat = 4

  private let calendar = Calendar.current

  var body: some View {
    VStack(alignment: .leading, spacing: DLSpace.sm) {
      grid
      legend
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilitySummary)
  }

  // MARK: Grid

  private var grid: some View {
    HStack(alignment: .top, spacing: gap) {
      ForEach(weeks) { week in
        VStack(spacing: gap) {
          ForEach(week.days) { day in
            dayCell(day)
          }
        }
      }
    }
    // Let very small widths scroll horizontally rather than clip.
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func dayCell(_ day: HeatmapDay) -> some View {
    RoundedRectangle(cornerRadius: 3, style: .continuous)
      .fill(fill(for: day))
      .frame(width: cell, height: cell)
      .overlay(
        RoundedRectangle(cornerRadius: 3, style: .continuous)
          .strokeBorder(DLColor.separator.opacity(0.25), lineWidth: day.isFuture ? 0 : 0.5)
      )
      .opacity(day.isFuture ? 0.0 : 1.0)
      .accessibilityHidden(true)
  }

  /// Empty/un-logged days use a faint separator color; logged days use the
  /// mood's color. Future days inside the trailing week are invisible.
  private func fill(for day: HeatmapDay) -> Color {
    guard !day.isFuture else { return .clear }
    if let raw = day.moodRaw, let option = MoodCatalog.shared.option(forValue: raw) {
      return option.color
    }
    return DLColor.separator.opacity(0.35)
  }

  // MARK: Legend

  private var legend: some View {
    HStack(spacing: DLSpace.sm) {
      Text(L("Less"))
        .font(.dl(.caption2))
        .foregroundStyle(DLColor.textTertiary)

      HStack(spacing: gap) {
        legendSwatch(DLColor.separator.opacity(0.35))
        ForEach(MoodCatalog.shared.options) { mood in
          legendSwatch(mood.color)
        }
      }

      Text(L("More"))
        .font(.dl(.caption2))
        .foregroundStyle(DLColor.textTertiary)
    }
    .accessibilityHidden(true)
  }

  private func legendSwatch(_ color: Color) -> some View {
    RoundedRectangle(cornerRadius: 2, style: .continuous)
      .fill(color)
      .frame(width: 10, height: 10)
  }

  // MARK: - Derived data

  /// Map from start-of-day → stored mood value, built once from all entries.
  private var moodByDay: [Date: Int] {
    var map: [Date: Int] = [:]
    for entry in entries {
      let key = calendar.startOfDay(for: entry.day)
      // Entries are already one-per-day in practice; last write wins.
      map[key] = entry.moodRaw
    }
    return map
  }

  /// The grid's columns, oldest week on the left. The rightmost column is the
  /// week containing today; rows run from the calendar's first weekday.
  private var weeks: [HeatmapWeek] {
    let today = calendar.startOfDay(for: Date())
    let moods = moodByDay

    // Find the start of this week, then walk back `weekCount - 1` weeks.
    let startOfThisWeek = startOfWeek(containing: today)
    guard let firstWeekStart = calendar.date(
      byAdding: .weekOfYear, value: -(weekCount - 1), to: startOfThisWeek
    ) else { return [] }

    var result: [HeatmapWeek] = []
    result.reserveCapacity(weekCount)

    for weekIndex in 0..<weekCount {
      guard let weekStart = calendar.date(
        byAdding: .weekOfYear, value: weekIndex, to: firstWeekStart
      ) else { continue }

      var days: [HeatmapDay] = []
      days.reserveCapacity(7)
      for offset in 0..<7 {
        guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { continue }
        let key = calendar.startOfDay(for: date)
        days.append(
          HeatmapDay(
            date: key,
            moodRaw: moods[key],
            isFuture: key > today
          )
        )
      }
      result.append(HeatmapWeek(weekStart: weekStart, days: days))
    }
    return result
  }

  /// Start of the week containing `date`, honoring the calendar's
  /// `firstWeekday` (e.g. Sunday in the US, Monday elsewhere).
  private func startOfWeek(containing date: Date) -> Date {
    let start = calendar.startOfDay(for: date)
    let weekday = calendar.component(.weekday, from: start)
    // Days to subtract to reach firstWeekday.
    let diff = (weekday - calendar.firstWeekday + 7) % 7
    return calendar.date(byAdding: .day, value: -diff, to: start) ?? start
  }

  /// A spoken summary: how many of the visible days were logged.
  private var accessibilitySummary: String {
    let logged = weeks
      .flatMap { $0.days }
      .filter { !$0.isFuture && $0.moodRaw != nil }
      .count
    return Lf("Mood calendar. %d days logged in the last %d weeks.", logged, weekCount)
  }
}

// MARK: - Heatmap data points

private struct HeatmapWeek: Identifiable {
  let id = UUID()
  let weekStart: Date
  let days: [HeatmapDay]
}

private struct HeatmapDay: Identifiable {
  var id: Date { date }
  let date: Date
  let moodRaw: Int?
  let isFuture: Bool
}
