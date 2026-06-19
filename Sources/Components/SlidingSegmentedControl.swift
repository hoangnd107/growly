import SwiftUI

/// A segmented selector with a sliding `matchedGeometryEffect` pill — the same
/// animation style used by the Today / Notes / Insights selectors (feature 12).
/// Items can show a text label, an SF Symbol, or both.
struct SlidingSegmentedControl<T: Hashable>: View {
  let items: [T]
  /// Text label for an item (use "" to show icon only).
  var label: (T) -> String = { _ in "" }
  /// Optional SF Symbol for an item.
  var systemImage: (T) -> String? = { _ in nil }
  @Binding var selection: T
  var accent: Color = .accentColor

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Namespace private var ns

  var body: some View {
    HStack(spacing: 4) {
      ForEach(items, id: \.self) { item in
        let isSelected = selection == item
        Button {
          withAnimation(reduceMotion ? nil : DLAnim.standard) { selection = item }
          Haptics.selection()
        } label: {
          HStack(spacing: 4) {
            if let icon = systemImage(item) {
              Image(systemName: icon)
            }
            let text = label(item)
            if !text.isEmpty {
              Text(text).font(.dl(.subheadline, weight: .semibold))
            }
          }
          .foregroundStyle(isSelected ? Color.white : DLColor.textSecondary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
          .background {
            if isSelected {
              Capsule().fill(accent)
                .matchedGeometryEffect(id: "slidingSegmentPill", in: ns)
            }
          }
          .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(item))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
      }
    }
    .padding(4)
    .background(DLColor.surfaceElevated, in: Capsule())
    .overlay(Capsule().strokeBorder(DLColor.separator.opacity(0.6), lineWidth: 1))
  }

  private func accessibilityLabel(_ item: T) -> String {
    let text = label(item)
    return text.isEmpty ? (systemImage(item) ?? "") : text
  }
}
