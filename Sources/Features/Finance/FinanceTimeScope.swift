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
  private var calendar: Calendar { Calendar.current }

  /// Switching scope re-normalizes the anchor to the new unit, clamped so it
  /// never lands in the future.
  private var scopeBinding: Binding<FinanceTimeScope> {
    Binding(
      get: { scope },
      set: { newScope in
        let normalized = calendar.start(of: newScope, for: anchor)
        let capped = min(normalized, calendar.start(of: newScope, for: Date()))
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
  }

  private var navigator: some View {
    HStack(spacing: DLSpace.sm) {
      chevron("chevron.left", enabled: true, label: L("Previous")) { shift(-1) }
      Spacer(minLength: 0)
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
