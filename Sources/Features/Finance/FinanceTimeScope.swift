import SwiftUI

/// Month-vs-year time scope for the finance screens (round 5, items 2–3). Both
/// the Money overview and the Detailed Report scope their data to the selected
/// window so the two stay consistent.
enum FinanceTimeScope: String, CaseIterable, Identifiable, Hashable {
  case month, year
  var id: String { rawValue }
  var label: String { self == .month ? L("Month") : L("Year") }
}

extension Calendar {
  /// Start of the month or year containing `date`, per the scope.
  func start(of scope: FinanceTimeScope, for date: Date) -> Date {
    let comps: Set<Calendar.Component> = scope == .month ? [.year, .month] : [.year]
    return self.date(from: dateComponents(comps, from: date)) ?? startOfDay(for: date)
  }

  /// Whether `date` falls in the same scope-unit (month or year) as `reference`.
  func isSame(_ scope: FinanceTimeScope, _ date: Date, _ reference: Date) -> Bool {
    isDate(date, equalTo: reference, toGranularity: scope == .month ? .month : .year)
  }
}

/// A Month|Year segmented control plus a "‹ period ›" stepper. Steps by month or
/// year depending on `scope`, and never pages past the current period. Shared by
/// the Money overview, the Detailed Report, and the All-transactions sheet so all
/// three filter to the same window (round 5, items 2–3).
struct FinancePeriodBar: View {
  @Binding var scope: FinanceTimeScope
  @Binding var anchor: Date
  var accent: Color = .accentColor

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var showPicker = false
  private var calendar: Calendar { Calendar.current }

  /// Switching to Month jumps to the current month; switching to Year keeps the
  /// year currently in view. Always clamped so the anchor never lands in the
  /// future (round 6, item 4).
  private var scopeBinding: Binding<FinanceTimeScope> {
    Binding(
      get: { scope },
      set: { newScope in
        let target = newScope == .month
          ? calendar.start(of: .month, for: Date())
          : calendar.start(of: .year, for: anchor)
        let capped = min(target, calendar.start(of: newScope, for: Date()))
        withAnimation(reduceMotion ? nil : DLAnim.standard) {
          scope = newScope
          anchor = capped
        }
        Haptics.selection()
      }
    )
  }

  private var isCurrentPeriod: Bool { calendar.isSame(scope, anchor, Date()) }

  var body: some View {
    VStack(spacing: DLSpace.sm) {
      SlidingSegmentedControl(
        items: FinanceTimeScope.allCases,
        label: { $0.label },
        selection: scopeBinding,
        accent: accent
      )
      .accessibilityLabel(L("Time range"))

      navigator
    }
    .sheet(isPresented: $showPicker) {
      PeriodPicker(scope: scope, anchor: $anchor, accent: accent) { showPicker = false }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }
  }

  private var navigator: some View {
    HStack(spacing: DLSpace.sm) {
      chevron("chevron.left", enabled: true, label: L("Previous")) { shift(-1) }
      Spacer(minLength: 0)
      // Tap the period to jump straight to a month/year (round 6, item 3).
      Button {
        Haptics.light()
        showPicker = true
      } label: {
        HStack(spacing: DLSpace.xs) {
          Group {
            if scope == .month {
              Text(anchor, format: .dateTime.month(.wide).year())
            } else {
              Text(verbatim: String(calendar.component(.year, from: anchor)))
            }
          }
          .font(.dl(.headline, weight: .bold))
          .foregroundStyle(DLColor.textPrimary)
          .contentTransition(.numericText())
          Image(systemName: "chevron.down")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(accent)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(L("Choose period"))
      Spacer(minLength: 0)
      chevron("chevron.right", enabled: !isCurrentPeriod, label: L("Next")) { shift(1) }
    }
  }

  private func chevron(_ systemName: String, enabled: Bool, label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(enabled ? accent : DLColor.textTertiary)
        .frame(width: 40, height: 40)
        .background(DLColor.surfaceElevated.opacity(0.6), in: Circle())
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
    .accessibilityLabel(label)
  }

  private func shift(_ delta: Int) {
    let component: Calendar.Component = scope == .month ? .month : .year
    guard let next = calendar.date(byAdding: component, value: delta, to: anchor) else { return }
    let start = calendar.start(of: scope, for: next)
    // Never page past the current period.
    if delta > 0, start > calendar.start(of: scope, for: Date()) { return }
    withAnimation(reduceMotion ? nil : DLAnim.standard) { anchor = start }
    Haptics.selection()
  }
}

/// A wheel picker for jumping straight to a month or year instead of stepping with
/// the chevrons (round 6, item 3). Shows month + year wheels for the Month scope,
/// just a year wheel for Year. The chosen period is clamped to never be in the
/// future.
private struct PeriodPicker: View {
  let scope: FinanceTimeScope
  @Binding var anchor: Date
  let accent: Color
  var onDone: () -> Void

  @State private var month: Int
  @State private var year: Int

  private var calendar: Calendar { Calendar.current }

  init(scope: FinanceTimeScope, anchor: Binding<Date>, accent: Color, onDone: @escaping () -> Void) {
    self.scope = scope
    self._anchor = anchor
    self.accent = accent
    self.onDone = onDone
    let cal = Calendar.current
    _month = State(initialValue: cal.component(.month, from: anchor.wrappedValue))
    _year = State(initialValue: cal.component(.year, from: anchor.wrappedValue))
  }

  private var currentYear: Int { calendar.component(.year, from: Date()) }
  private var years: [Int] { Array((currentYear - 10)...currentYear) }
  private var monthSymbols: [String] { calendar.standaloneMonthSymbols }

  var body: some View {
    VStack(spacing: DLSpace.md) {
      Text(scope == .month ? L("Choose month") : L("Choose year"))
        .font(.dl(.headline, weight: .semibold))
        .foregroundStyle(DLColor.textPrimary)
        .padding(.top, DLSpace.lg)

      HStack(spacing: 0) {
        if scope == .month {
          Picker(L("Month"), selection: $month) {
            ForEach(1...12, id: \.self) { m in
              Text(monthSymbols.indices.contains(m - 1) ? monthSymbols[m - 1] : "\(m)").tag(m)
            }
          }
          .pickerStyle(.wheel)
          .frame(maxWidth: .infinity)
        }
        Picker(L("Year"), selection: $year) {
          ForEach(years, id: \.self) { y in
            Text(verbatim: String(y)).tag(y)
          }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: scope == .month ? 120 : .infinity)
      }
      .frame(maxHeight: 150)

      Button {
        commit()
      } label: {
        Text(L("Done"))
          .font(.dl(.body, weight: .semibold))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, DLSpace.sm)
          .background(accent, in: RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous))
      }
      .buttonStyle(.plain)
      .padding(.horizontal, DLSpace.lg)
      .padding(.bottom, DLSpace.lg)
    }
  }

  private func commit() {
    var comps = DateComponents()
    comps.year = year
    if scope == .month { comps.month = month }
    let chosen = calendar.date(from: comps) ?? anchor
    let start = calendar.start(of: scope, for: chosen)
    let capped = min(start, calendar.start(of: scope, for: Date()))
    anchor = capped
    Haptics.selection()
    onDone()
  }
}
