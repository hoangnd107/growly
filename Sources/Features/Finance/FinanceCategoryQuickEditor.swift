import SwiftUI
import SwiftData

/// Inline finance-category editor for the Customize screen (round 6, item 6):
/// rename, recolor, re-emoji, add, and delete spending/income categories — the
/// same catalog the Finances screen manages, surfaced alongside moods and habits.
struct FinanceCategoryQuickEditor: View {
  var accent: Color

  @Environment(\.modelContext) private var context
  @Query(sort: \FinanceCategory.sortIndex) private var categories: [FinanceCategory]

  private var expenseCategories: [FinanceCategory] { categories.filter { $0.isExpense } }
  private var incomeCategories: [FinanceCategory] { categories.filter { !$0.isExpense } }

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Label(L("Finance categories"), systemImage: "tag.fill")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(accent)

        Text(L("Rename, recolor, or add the categories used across your finances."))
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)

        group(L("Expense categories"), items: expenseCategories, isExpense: true)
        Divider().overlay(DLColor.separator.opacity(0.5))
        group(L("Income categories"), items: incomeCategories, isExpense: false)
      }
    }
    .onAppear(perform: seedIfNeeded)
  }

  @ViewBuilder
  private func group(_ title: String, items: [FinanceCategory], isExpense: Bool) -> some View {
    VStack(alignment: .leading, spacing: DLSpace.sm) {
      Text(title)
        .font(.dl(.caption, weight: .semibold))
        .foregroundStyle(DLColor.textTertiary)
        .textCase(.uppercase)

      ForEach(items) { category in
        FinanceCategoryEditorRow(category: category) { delete(category) }
      }

      Button {
        addCategory(isExpense: isExpense)
      } label: {
        Label(isExpense ? L("Add expense category") : L("Add income category"), systemImage: "plus.circle.fill")
          .font(.dl(.subheadline, weight: .semibold))
          .foregroundStyle(accent)
      }
      .buttonStyle(.plain)
    }
  }

  private func addCategory(isExpense: Bool) {
    let nextIndex = (categories.filter { $0.isExpense == isExpense }.map { $0.sortIndex }.max() ?? -1) + 1
    let category = FinanceCategory(
      name: isExpense ? L("New category") : L("New source"),
      emoji: isExpense ? "🏷️" : "💵",
      colorHex: ColorPaletteOption.presets.first ?? "7E5BEF",
      isExpense: isExpense,
      sortIndex: nextIndex
    )
    context.insert(category)
    try? context.save()
    Haptics.success()
  }

  private func delete(_ category: FinanceCategory) {
    context.delete(category)
    try? context.save()
    Haptics.medium()
  }

  private func seedIfNeeded() {
    guard categories.isEmpty else { return }
    for category in FinanceCategory.defaults() { context.insert(category) }
    try? context.save()
  }
}

/// One editable finance-category row: color, emoji, name, and a remove button.
private struct FinanceCategoryEditorRow: View {
  @Environment(\.modelContext) private var context
  @Bindable var category: FinanceCategory
  let onDelete: () -> Void

  var body: some View {
    HStack(spacing: DLSpace.sm) {
      ColorSwatchPicker(hex: $category.colorHex) {
        try? context.save()
        Haptics.selection()
      }
      .accessibilityLabel(L("Category color"))

      TextField("🏷️", text: $category.emoji)
        .multilineTextAlignment(.center)
        .font(.system(size: 20))
        .frame(width: 38)
        .onChange(of: category.emoji) { _, value in
          if let first = value.first {
            let single = String(first)
            if single != value { category.emoji = single }
          }
          try? context.save()
        }

      TextField(L("Category name"), text: $category.name)
        .font(.dl(.body))
        .foregroundStyle(DLColor.textPrimary)
        .textInputAutocapitalization(.words)
        .onSubmit { try? context.save() }

      Button(action: onDelete) {
        Image(systemName: "minus.circle.fill")
          .font(.system(size: 20))
          .foregroundStyle(DLColor.streakEnd)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(L("Delete"))
    }
    .padding(.vertical, 2)
  }
}
