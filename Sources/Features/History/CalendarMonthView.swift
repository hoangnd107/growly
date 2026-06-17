import SwiftUI

/// What a calendar day contains: a reflection (entry) dot and/or a note dot,
/// each tinted by its mood color. Either may be nil.
struct CalendarDayMark: Equatable {
  var entryColor: Color?
  var noteColor: Color?

  var hasContent: Bool { entryColor != nil || noteColor != nil }
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
    let hasContent = mark?.hasContent ?? false
    let dayNumber = calendar.component(.day, from: day)

    Button {
      guard hasContent else { return }
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
        // Up to two dots: reflection (entry) and note.
        HStack(spacing: 2) {
          if let entryColor = mark?.entryColor {
            Circle().fill(entryColor).frame(width: 6, height: 6)
          }
          if let noteColor = mark?.noteColor {
            Circle().fill(noteColor).frame(width: 6, height: 6)
          }
        }
        .frame(height: 6)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!hasContent)
    .accessibilityLabel(Text(day, format: .dateTime.month().day()))
    .accessibilityValue(Text(accessibilityValue(for: mark)))
    .accessibilityAddTraits(hasContent ? .isButton : [])
  }

  private func accessibilityValue(for mark: CalendarDayMark?) -> String {
    let hasEntry = mark?.entryColor != nil
    let hasNote = mark?.noteColor != nil
    switch (hasEntry, hasNote) {
    case (true, true): return L("Reflection and notes")
    case (true, false): return L("Has reflection")
    case (false, true): return L("Has notes")
    case (false, false): return L("No reflection")
    }
  }
}
