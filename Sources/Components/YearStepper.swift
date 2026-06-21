import SwiftUI

/// A compact "‹ 2026 ›" year picker shared by every full-year analytics page so
/// the year filter looks and behaves identically across Consistency and Habit
/// analytics (item 4: consistent year filter across pages). Chevrons disable at
/// the data bounds and carry "Previous year" / "Next year" accessibility labels.
struct YearStepper: View {
  @Binding var year: Int
  let minYear: Int
  let maxYear: Int
  var accent: Color = DLColor.accent
  var onChange: (() -> Void)? = nil

  var body: some View {
    HStack(spacing: DLSpace.sm) {
      button(systemName: "chevron.left", enabled: year > minYear) { step(-1) }
      Text(verbatim: String(year))
        .font(.dl(.subheadline, weight: .bold))
        .foregroundStyle(DLColor.textPrimary)
        .monospacedDigit()
        .frame(minWidth: 52)
        .contentTransition(.numericText())
      button(systemName: "chevron.right", enabled: year < maxYear) { step(1) }
    }
  }

  private func step(_ delta: Int) {
    let next = year + delta
    guard next >= minYear, next <= maxYear else { return }
    year = next
    Haptics.selection()
    onChange?()
  }

  private func button(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(enabled ? accent : DLColor.textTertiary)
        .frame(width: 32, height: 32)
        .background(DLColor.surfaceElevated.opacity(0.6), in: Circle())
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
    .accessibilityLabel(systemName == "chevron.left" ? L("Previous year") : L("Next year"))
  }
}
