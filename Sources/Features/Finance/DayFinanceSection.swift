import SwiftUI
import SwiftData

/// A per-day income/expense capture card, shared by Today and the Progress day
/// detail (item 11). Lists the day's transactions and offers a quick "add" that
/// opens the transaction editor pre-dated to this day — so money can be logged
/// daily, the same way the review and habits are.
struct DayFinanceSection: View {
  let day: Date

  @Environment(\.modelContext) private var context
  @Query(sort: \FinanceTransaction.date, order: .reverse) private var allTransactions: [FinanceTransaction]
  @Query(sort: \FinanceCategory.sortIndex) private var categories: [FinanceCategory]
  @Query private var progressList: [UserProgress]

  @State private var showAdd = false
  @State private var editingTx: FinanceTransaction?
  @State private var showAll = false

  private let calendar = Calendar.current
  private let expenseColor = Color(hex: 0xE5484D)
  /// Show at most this many of the day's transactions inline; the rest open in
  /// the full ledger via "view all" (round 5, item 7).
  private let dayLimit = 3

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  private var dayStart: Date { calendar.startOfDay(for: day) }

  private var dayTransactions: [FinanceTransaction] {
    allTransactions.filter { calendar.isDate($0.date, inSameDayAs: dayStart) }
  }

  private var net: Double { dayTransactions.reduce(0) { $0 + $1.signedAmount } }

  /// New transactions land at the current time when the day is today, else noon.
  private var newDate: Date {
    calendar.isDateInToday(dayStart)
      ? Date()
      : (calendar.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart) ?? dayStart)
  }

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        HStack {
          Label(L("Finances"), systemImage: "creditcard.fill")
            .font(.dl(.headline, weight: .semibold))
            .foregroundStyle(theme.accent)
          Spacer(minLength: 0)
          if !dayTransactions.isEmpty {
            Text(CurrencyFormatter.signedVND(net))
              .font(.dl(.subheadline, weight: .bold))
              .monospacedDigit()
              .foregroundStyle(net >= 0 ? DLColor.success : expenseColor)
          }
        }

        if dayTransactions.isEmpty {
          Text(L("Tap to log income or an expense for this day."))
            .font(.dl(.subheadline))
            .foregroundStyle(DLColor.textSecondary)
        } else {
          ForEach(dayTransactions.prefix(dayLimit)) { tx in
            Button { editingTx = tx } label: { row(tx) }
              .buttonStyle(.plain)
          }
          if dayTransactions.count > dayLimit {
            Button { showAll = true } label: {
              HStack(spacing: 4) {
                Text(Lf("View all %d", dayTransactions.count))
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
              }
              .font(.dl(.subheadline, weight: .semibold))
              .foregroundStyle(theme.accent)
              .frame(maxWidth: .infinity, alignment: .leading)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
          }
        }

        Button {
          showAdd = true
        } label: {
          Label(L("Add income or expense"), systemImage: "plus.circle.fill")
            .font(.dl(.subheadline, weight: .semibold))
            .foregroundStyle(theme.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
    .sheet(isPresented: $showAdd) {
      TransactionEditorSheet(existing: nil, defaultDate: newDate)
    }
    .sheet(item: $editingTx) { tx in
      TransactionEditorSheet(existing: tx)
    }
    .sheet(isPresented: $showAll) {
      AllTransactionsView(initialAnchor: dayStart)
    }
    .onAppear(perform: seedDefaultCategoriesIfNeeded)
  }

  private func row(_ tx: FinanceTransaction) -> some View {
    let tint = tx.category.map { Color(hexString: $0.colorHex) } ?? theme.accent
    return HStack(spacing: DLSpace.sm) {
      ZStack {
        Circle().fill(tint.opacity(0.18)).frame(width: 34, height: 34)
        Text(tx.category?.emoji ?? (tx.isExpense ? "💸" : "💰")).font(.system(size: 16))
      }
      VStack(alignment: .leading, spacing: 1) {
        Text(title(tx))
          .font(.dl(.subheadline, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)
          .lineLimit(1)
        Text(tx.date, format: .dateTime.hour().minute())
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
      }
      Spacer(minLength: DLSpace.sm)
      Text(CurrencyFormatter.signedVND(tx.signedAmount))
        .font(.dl(.subheadline, weight: .bold))
        .monospacedDigit()
        .foregroundStyle(tx.isExpense ? expenseColor : DLColor.success)
    }
    .contentShape(Rectangle())
  }

  private func title(_ tx: FinanceTransaction) -> String {
    let note = tx.note.trimmingCharacters(in: .whitespacesAndNewlines)
    if !note.isEmpty { return note }
    if let cat = tx.category { return L(cat.name) }
    return tx.isExpense ? L("Expense") : L("Income")
  }

  private func seedDefaultCategoriesIfNeeded() {
    guard categories.isEmpty else { return }
    for category in FinanceCategory.defaults() {
      context.insert(category)
    }
    try? context.save()
  }
}
