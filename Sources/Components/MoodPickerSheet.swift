import SwiftUI

/// A small reusable sheet for picking a mood from the customizable catalog.
/// Calls `onSelect` with the chosen value (or nil when cleared) and dismisses.
struct MoodPickerSheet: View {
  let current: Int?
  /// When true, shows a "No mood" option that passes nil back.
  var allowClear: Bool = false
  let onSelect: (Int?) -> Void

  @Environment(\.dismiss) private var dismiss

  private let columns = Array(repeating: GridItem(.flexible(), spacing: DLSpace.sm), count: 3)

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVGrid(columns: columns, spacing: DLSpace.md) {
          ForEach(MoodCatalog.shared.options) { mood in
            moodCell(mood)
          }
          if allowClear { clearCell }
        }
        .padding(DLSpace.md)
      }
      .navigationTitle(L("Choose mood"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(L("Done")) { dismiss() }.fontWeight(.semibold)
        }
      }
    }
    .presentationDetents([.medium])
    .presentationDragIndicator(.visible)
  }

  private func moodCell(_ mood: MoodOption) -> some View {
    let isSelected = current == mood.value
    return Button {
      onSelect(mood.value)
      Haptics.selection()
      dismiss()
    } label: {
      VStack(spacing: DLSpace.xs) {
        Text(mood.emoji).font(.system(size: 34))
        Text(mood.displayName)
          .font(.dl(.caption, weight: .semibold))
          .foregroundStyle(isSelected ? mood.color : DLColor.textSecondary)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, DLSpace.md)
      .background(
        isSelected ? mood.color.opacity(0.16) : DLColor.surfaceElevated.opacity(0.5),
        in: RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous)
          .strokeBorder(isSelected ? mood.color : DLColor.separator.opacity(0.4), lineWidth: isSelected ? 2 : 1)
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel(mood.displayName)
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }

  private var clearCell: some View {
    Button {
      onSelect(nil)
      Haptics.selection()
      dismiss()
    } label: {
      VStack(spacing: DLSpace.xs) {
        Image(systemName: "slash.circle").font(.system(size: 30)).foregroundStyle(DLColor.textSecondary)
        Text(L("No mood"))
          .font(.dl(.caption, weight: .semibold))
          .foregroundStyle(DLColor.textSecondary)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, DLSpace.md)
      .background(DLColor.surfaceElevated.opacity(0.5), in: RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous))
    }
    .buttonStyle(.plain)
  }
}
