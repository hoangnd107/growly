import SwiftUI

/// What a calendar day contains, as up to three distinct dots (feature 7):
/// a note dot (blue), a mood dot (orange), and a "complete the day" dot (green,
/// for a full WMLA reflection). Each shows only when its condition is met.
struct CalendarDayMark: Equatable {
  var hasNote = false       // blue
  var hasMood = false       // orange
  var hasComplete = false   // green (full Win/Mistake/Lesson/Adjustment)

  var hasContent: Bool { hasNote || hasMood || hasComplete }

  static let noteColor = Color(hex: 0x0A84FF)      // systemBlue
  static let moodColor = Color(hex: 0xFF9F0A)      // systemOrange
  static let completeColor = Color(hex: 0x34C759)  // systemGreen
}

/// A 7-column month grid. Each day cell shows the day number and up to two dots:
/// a reflection dot (entry mood color) and a note dot. Today is highlighted.
/// Tapping a day that has any content fires `onSelect`.
struct CalendarMonthView: View {
  /// The month to display (any date within the month works; the view
  /// normalizes to the first day internally).
  let month: Date
  /// Map of day-start dates -> what that day contains (entry and/or note dots).
  let marks: [Date: CalendarDayMark]
  /// Called with the day-start `Date` when a day that has content is tapped.
  let onSelect: (Date) -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var calendar: Calendar {
    var cal = Calendar.current
    cal.firstWeekday = 2 // Monday-first (the weekday header rotates to match).
    return cal
  }

  private var today: Date { Calendar.current.startOfDay(for: Date()) }

  /// Localized very-short weekday symbols rotated to start at `firstWeekday`.
  private var weekdaySymbols: [String] {
    let symbols = calendar.veryShortStandaloneWeekdaySymbols
    let shift = calendar.firstWeekday - 1
    guard shift > 0, shift < symbols.count else { return symbols }
    return Array(symbols[shift...] + symbols[..<shift])
  }

  /// The grid slots: leading `nil`s pad the first week to the correct weekday,
  /// followed by each day of the month as a `Date`.
  private var slots: [Date?] {
    guard
      let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
      let range = calendar.range(of: .day, in: .month, for: monthStart)
    else { return [] }

    let firstWeekday = calendar.component(.weekday, from: monthStart)
    let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

    var result: [Date?] = Array(repeating: nil, count: leadingBlanks)
    for offset in 0..<range.count {
      if let day = calendar.date(byAdding: .day, value: offset, to: monthStart) {
        result.append(calendar.startOfDay(for: day))
      }
    }
    return result
  }

  private let columns = Array(repeating: GridItem(.flexible(), spacing: DLSpace.xs), count: 7)

  var body: some View {
    VStack(spacing: DLSpace.sm) {
      LazyVGrid(columns: columns, spacing: 0) {
        ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
          Text(symbol)
            .font(.dl(.caption2, weight: .semibold))
            .foregroundStyle(DLColor.textTertiary)
            .frame(maxWidth: .infinity)
        }
      }

      LazyVGrid(columns: columns, spacing: DLSpace.xs) {
        ForEach(Array(slots.enumerated()), id: \.offset) { _, day in
          if let day {
            dayCell(day)
          } else {
            Color.clear.frame(height: 44)
          }
        }
      }
    }
  }

  @ViewBuilder
  private func dayCell(_ day: Date) -> some View {
    let isToday = calendar.isDate(day, inSameDayAs: today)
    let mark = marks[day]
    let dayNumber = calendar.component(.day, from: day)
    // Any past/today day is tappable so you can add or edit that day; future days
    // stay disabled (no back-filling tomorrow).
    let isFuture = day > today
    let tappable = !isFuture

    Button {
      guard tappable else { return }
      onSelect(day)
      Haptics.selection()
    } label: {
      VStack(spacing: 4) {
        Text("\(dayNumber)")
          .font(.dl(.subheadline, weight: isToday ? .bold : .regular))
          .foregroundStyle(isToday ? DLColor.background : DLColor.textPrimary)
          .monospacedDigit()
          .frame(width: 30, height: 30)
          .background {
            if isToday {
              Circle().fill(Color.accentColor)
            }
          }
        // Up to three dots: note (blue), mood (orange), complete-the-day (green).
        HStack(spacing: 2) {
          if mark?.hasNote == true {
            Circle().fill(CalendarDayMark.noteColor).frame(width: 6, height: 6)
          }
          if mark?.hasMood == true {
            Circle().fill(CalendarDayMark.moodColor).frame(width: 6, height: 6)
          }
          if mark?.hasComplete == true {
            Circle().fill(CalendarDayMark.completeColor).frame(width: 6, height: 6)
          }
        }
        .frame(height: 6)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 44)
      .contentShape(Rectangle())
      .opacity(isFuture ? 0.35 : 1)
    }
    .buttonStyle(.plain)
    .disabled(!tappable)
    .accessibilityLabel(Text(day, format: .dateTime.month().day()))
    .accessibilityValue(Text(accessibilityValue(for: mark)))
    .accessibilityAddTraits(tappable ? .isButton : [])
  }

  private func accessibilityValue(for mark: CalendarDayMark?) -> String {
    guard let mark, mark.hasContent else { return L("Nothing logged") }
    var parts: [String] = []
    if mark.hasNote { parts.append(L("note")) }
    if mark.hasMood { parts.append(L("mood")) }
    if mark.hasComplete { parts.append(L("day reviewed")) }
    return parts.joined(separator: ", ")
  }
}
