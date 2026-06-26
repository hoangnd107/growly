import SwiftUI
import SwiftData

extension View {
  /// Clear, separator-less list-row chrome for the finance ledger lists, so each
  /// GlassCard floats over the themed background.
  func financeRow() -> some View {
    self
      .listRowInsets(EdgeInsets(top: DLSpace.xs, leading: DLSpace.md, bottom: DLSpace.xs, trailing: DLSpace.md))
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
  }
}

/// Reusable transaction rows for a List (round 5, items 5–6): tap to edit,
/// swipe-left to edit, swipe-right to delete, long-press for a context menu.
/// Used by the Detailed Report and the All-transactions sheet. Deletion (and its
/// media cleanup) is handled here; editing is delegated via `onEdit`.
struct FinanceTransactionRows: View {
  let transactions: [FinanceTransaction]
  let accent: Color
  let onEdit: (FinanceTransaction) -> Void

  @Environment(\.modelContext) private var context
  private let expenseColor = Color(hex: 0xE5484D)

  var body: some View {
    ForEach(transactions) { tx in
      row(tx)
        .contentShape(Rectangle())
        .onTapGesture { onEdit(tx) }
        // swipe-left (trailing) = edit, swipe-right (leading) = delete (item 6).
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
          Button { onEdit(tx) } label: { Label(L("Edit"), systemImage: "pencil") }
            .tint(accent)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
          Button(role: .destructive) { delete(tx) } label: { Label(L("Delete"), systemImage: "trash") }
        }
        .contextMenu {
          Button { onEdit(tx) } label: { Label(L("Edit"), systemImage: "pencil") }
          Button(role: .destructive) { delete(tx) } label: { Label(L("Delete"), systemImage: "trash") }
        }
        .financeRow()
    }
  }

  private func row(_ tx: FinanceTransaction) -> some View {
    let tint = tx.category.map { Color(hexString: $0.colorHex) } ?? accent
    return GlassCard {
      HStack(spacing: DLSpace.md) {
        ZStack {
          Circle().fill(tint.opacity(0.18)).frame(width: 40, height: 40)
          Text(tx.category?.emoji ?? (tx.isExpense ? "💸" : "💰"))
            .font(.system(size: 18))
        }
        VStack(alignment: .leading, spacing: 2) {
          Text(title(tx))
            .font(.dl(.subheadline, weight: .semibold))
            .foregroundStyle(DLColor.textPrimary)
            .lineLimit(1)
          Text(tx.date, format: .dateTime.day().month(.abbreviated).year())
            .font(.dl(.caption2))
            .foregroundStyle(DLColor.textTertiary)
        }
        Spacer(minLength: DLSpace.sm)
        VStack(alignment: .trailing, spacing: 2) {
          Text(CurrencyFormatter.signedVND(tx.signedAmount))
            .font(.dl(.subheadline, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(tx.isExpense ? expenseColor : DLColor.success)
          if !tx.attachments.isEmpty {
            Image(systemName: "paperclip")
              .font(.system(size: 11))
              .foregroundStyle(DLColor.textTertiary)
          }
        }
      }
    }
  }

  private func title(_ tx: FinanceTransaction) -> String {
    let note = tx.note.trimmingCharacters(in: .whitespacesAndNewlines)
    if !note.isEmpty { return note }
    if let cat = tx.category { return L(cat.name) }
    return tx.isExpense ? L("Expense") : L("Income")
  }

  private func delete(_ tx: FinanceTransaction) {
    for media in tx.attachments { MediaStore.delete(media.fileName) }
    context.delete(tx)
    try? context.save()
    Haptics.warning()
  }
}

/// The full transaction ledger, presented as a sheet from Today's "view all"
/// (round 5, item 7): a Month/Year filter, the editable transaction list, and an
/// Add button. Opens scoped to a given day's month when provided.
struct AllTransactionsView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]
  @Query private var progressList: [UserProgress]

  @State private var scope: FinanceTimeScope
  @State private var anchor: Date
  @State private var editingTx: FinanceTransaction?
  @State private var showAdd = false

  init(initialScope: FinanceTimeScope = .month, initialAnchor: Date? = nil) {
    _scope = State(initialValue: initialScope)
    _anchor = State(initialValue: Calendar.current.start(of: initialScope, for: initialAnchor ?? Date()))
  }

  private let calendar = Calendar.current

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  private var txInWindow: [FinanceTransaction] {
    transactions.filter { calendar.isSame(scope, $0.date, anchor) }
  }

  private var isCurrentPeriod: Bool { calendar.isSame(scope, anchor, Date()) }

  private var addDefaultDate: Date? {
    isCurrentPeriod ? nil : calendar.date(bySettingHour: 12, minute: 0, second: 0, of: anchor)
  }

  var body: some View {
    NavigationStack {
      List {
        Section {
          FinancePeriodBar(scope: $scope, anchor: $anchor, accent: theme.accent)
            .financeRow()
        }
        Section {
          if txInWindow.isEmpty {
            Text(L("No transactions in this period yet."))
              .font(.dl(.subheadline))
              .foregroundStyle(DLColor.textSecondary)
              .financeRow()
          } else {
            FinanceTransactionRows(transactions: txInWindow, accent: theme.accent) { editingTx = $0 }
          }
        } header: {
          Text(L("Transactions"))
            .font(.dl(.caption, weight: .semibold))
            .foregroundStyle(DLColor.textSecondary)
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .themedBackground(theme)
      .navigationTitle(L("All transactions"))
      .navigationBarTitleDisplayMode(.inline)
      .tint(theme.accent)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(L("Done")) { dismiss() }.fontWeight(.semibold)
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button { showAdd = true } label: { Image(systemName: "plus") }
            .accessibilityLabel(L("Add transaction"))
        }
      }
      .sheet(isPresented: $showAdd) {
        TransactionEditorSheet(existing: nil, defaultDate: addDefaultDate)
      }
      .sheet(item: $editingTx) { tx in
        TransactionEditorSheet(existing: tx)
      }
      .animation(reduceMotion ? nil : DLAnim.standard, value: scope)
      .animation(reduceMotion ? nil : DLAnim.standard, value: anchor)
    }
  }
}
