import SwiftUI
import SwiftData

/// The detailed finance report. Opened from Insights → Detailed reports. A
/// Month/Year filter scopes a compact summary, the same visual charts as the Money
/// screen (breakdown pie always; income-vs-expense bars and a year calendar in the
/// Year view — round 6, item 5), the most recent transactions with a link to the
/// full filtered ledger (tap / swipe / long-press to edit or delete), and
/// per-category totals.
struct FinanceReportView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.modelContext) private var context
  @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]
  @Query(sort: \FinanceCategory.sortIndex) private var categories: [FinanceCategory]
  @Query private var progressList: [UserProgress]

  @State private var scope: FinanceTimeScope = .year
  @State private var anchor: Date = Calendar.current.start(of: .year, for: Date())
  @State private var editingTx: FinanceTransaction?
  @State private var showAdd = false
  @State private var showAll = false

  private let calendar = Calendar.current
  private let expenseColor = Color(hex: 0xE5484D)
  /// Show only the most recent few transactions inline; the rest open in the full
  /// ledger scoped to the current filter (round 6, item 7).
  private let transactionLimit = 5

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  // MARK: - Derived data

  private var txInWindow: [FinanceTransaction] {
    transactions.filter { calendar.isSame(scope, $0.date, anchor) }
  }

  private var totalIncome: Double { txInWindow.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount } }
  private var totalExpense: Double { txInWindow.filter { $0.isExpense }.reduce(0) { $0 + $1.amount } }
  private var net: Double { totalIncome - totalExpense }

  /// The anchored year, for the year-only charts.
  private var year: Int { calendar.component(.year, from: anchor) }

  private var isCurrentPeriod: Bool { calendar.isSame(scope, anchor, Date()) }
  private var addDefaultDate: Date? {
    isCurrentPeriod ? nil : calendar.date(bySettingHour: 12, minute: 0, second: 0, of: anchor)
  }

  private struct CategoryTotal: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let color: Color
    let total: Double
  }

  private func categoryTotals(expense: Bool) -> [CategoryTotal] {
    var byCategory: [UUID: Double] = [:]
    var uncategorized = 0.0
    for tx in txInWindow where tx.isExpense == expense {
      if let cat = tx.category { byCategory[cat.id, default: 0] += tx.amount } else { uncategorized += tx.amount }
    }
    var result: [CategoryTotal] = []
    for cat in categories where cat.isExpense == expense {
      if let amount = byCategory[cat.id], amount > 0 {
        result.append(CategoryTotal(name: L(cat.name), emoji: cat.emoji, color: Color(hexString: cat.colorHex), total: amount))
      }
    }
    if uncategorized > 0 {
      result.append(CategoryTotal(name: L("Uncategorized"), emoji: "❓", color: DLColor.textTertiary, total: uncategorized))
    }
    return result.sorted { $0.total > $1.total }
  }

  // MARK: - Body

  var body: some View {
    List {
      Section {
        FinancePeriodBar(scope: $scope, anchor: $anchor, accent: theme.accent)
          .financeRow()
        summaryCard
          .financeRow()
      }

      chartsSection

      transactionsSection

      categoryTotalsSection
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .themedBackground(theme)
    .navigationTitle(L("Finance report"))
    .navigationBarTitleDisplayMode(.inline)
    .tint(theme.accent)
    .toolbar {
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
    .sheet(isPresented: $showAll) {
      AllTransactionsView(initialScope: scope, initialAnchor: anchor)
    }
    .animation(reduceMotion ? nil : DLAnim.standard, value: scope)
    .animation(reduceMotion ? nil : DLAnim.standard, value: anchor)
  }

  // MARK: - Charts (round 6, item 5)

  @ViewBuilder
  private var chartsSection: some View {
    Section {
      FinanceBreakdownCard(transactions: txInWindow, categories: categories, accent: theme.accent)
        .financeRow()
      if scope == .year {
        FinanceMonthlyBarCard(transactions: txInWindow, year: year, accent: theme.accent)
          .financeRow()
        FinanceYearCalendarCard(transactions: txInWindow, year: year, accent: theme.accent)
          .financeRow()
      }
    }
  }

  // MARK: - Summary

  private var summaryCard: some View {
    GlassCard {
      HStack(spacing: DLSpace.lg) {
        summaryMetric(L("Income"), CurrencyFormatter.vnd(totalIncome), tint: DLColor.success)
        summaryMetric(L("Expense"), CurrencyFormatter.vnd(totalExpense), tint: expenseColor)
        summaryMetric(L("Net"), CurrencyFormatter.signedVND(net), tint: net >= 0 ? DLColor.success : expenseColor)
      }
    }
  }

  private func summaryMetric(_ label: String, _ value: String, tint: Color) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label)
        .font(.dl(.caption2, weight: .medium))
        .foregroundStyle(DLColor.textTertiary)
      Text(value)
        .font(.dl(.subheadline, weight: .bold))
        .monospacedDigit()
        .foregroundStyle(tint)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Transactions (items 5–6)

  @ViewBuilder
  private var transactionsSection: some View {
    Section {
      if txInWindow.isEmpty {
        Text(L("No transactions in this period yet."))
          .font(.dl(.subheadline))
          .foregroundStyle(DLColor.textSecondary)
          .financeRow()
      } else {
        FinanceTransactionRows(transactions: Array(txInWindow.prefix(transactionLimit)),
                               accent: theme.accent) { editingTx = $0 }
        if txInWindow.count > transactionLimit {
          Button { showAll = true } label: {
            HStack(spacing: 4) {
              Text(Lf("View all %d", txInWindow.count))
              Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
            }
            .font(.dl(.subheadline, weight: .semibold))
            .foregroundStyle(theme.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .financeRow()
        }
      }
    } header: {
      Text(L("Transactions"))
        .font(.dl(.caption, weight: .semibold))
        .foregroundStyle(DLColor.textSecondary)
    } footer: {
      if !txInWindow.isEmpty {
        Text(L("Tap to edit · swipe left to delete, right to edit."))
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
      }
    }
  }

  // MARK: - Category totals

  @ViewBuilder
  private var categoryTotalsSection: some View {
    let expenses = categoryTotals(expense: true)
    let incomes = categoryTotals(expense: false)
    if !expenses.isEmpty || !incomes.isEmpty {
      Section {
        GlassCard {
          VStack(alignment: .leading, spacing: DLSpace.md) {
            if !expenses.isEmpty {
              categoryGroup(L("Expenses"), totals: expenses)
            }
            if !incomes.isEmpty {
              if !expenses.isEmpty { Divider().overlay(DLColor.separator) }
              categoryGroup(L("Income"), totals: incomes)
            }
          }
        }
        .financeRow()
      } header: {
        Text(L("By category"))
          .font(.dl(.caption, weight: .semibold))
          .foregroundStyle(DLColor.textSecondary)
      }
    }
  }

  private func categoryGroup(_ title: String, totals: [CategoryTotal]) -> some View {
    VStack(alignment: .leading, spacing: DLSpace.xs) {
      Text(title)
        .font(.dl(.caption, weight: .semibold))
        .foregroundStyle(DLColor.textTertiary)
        .textCase(.uppercase)
      ForEach(totals) { item in
        HStack(spacing: DLSpace.sm) {
          Circle().fill(item.color).frame(width: 10, height: 10)
          Text(item.emoji)
          Text(item.name)
            .font(.dl(.subheadline, weight: .medium))
            .foregroundStyle(DLColor.textPrimary)
            .lineLimit(1)
          Spacer(minLength: DLSpace.sm)
          Text(CurrencyFormatter.vnd(item.total))
            .font(.dl(.subheadline, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(DLColor.textSecondary)
        }
      }
    }
  }
}
