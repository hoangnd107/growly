import SwiftUI
import SwiftData
import Charts

/// The detailed finance report, pushed from `FinanceView`. Keeps the heavier
/// analytics out of the main Finances screen (item 10): a full-year view with
/// income-vs-expense bars per month (item 7), a year calendar heatmap of daily
/// net flow (item 8), and per-category totals for the year.
struct FinanceReportView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]
  @Query(sort: \FinanceCategory.sortIndex) private var categories: [FinanceCategory]
  @Query private var progressList: [UserProgress]

  @State private var year: Int = Calendar.current.component(.year, from: Date())

  private let calendar = Calendar.current
  private let expenseColor = Color(hex: 0xE5484D)

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  // MARK: - Derived data

  private var availableYears: [Int] {
    let years = Set(transactions.map { calendar.component(.year, from: $0.date) })
    let current = calendar.component(.year, from: Date())
    return Array(years.union([current])).sorted()
  }

  private var txInYear: [FinanceTransaction] {
    transactions.filter { calendar.component(.year, from: $0.date) == year }
  }

  private var yearIncome: Double { txInYear.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount } }
  private var yearExpense: Double { txInYear.filter { $0.isExpense }.reduce(0) { $0 + $1.amount } }

  private struct MonthBar: Identifiable {
    let id = UUID()
    let month: Int
    let label: String
    let income: Double
    let expense: Double
  }

  /// Income and expense totals per month (Jan…Dec) of the selected year.
  private var monthBars: [MonthBar] {
    let symbols = calendar.shortStandaloneMonthSymbols
    var income = Array(repeating: 0.0, count: 12)
    var expense = Array(repeating: 0.0, count: 12)
    for tx in txInYear {
      let m = calendar.component(.month, from: tx.date) - 1
      guard (0..<12).contains(m) else { continue }
      if tx.isExpense { expense[m] += tx.amount } else { income[m] += tx.amount }
    }
    return (0..<12).map { m in
      MonthBar(month: m + 1, label: symbols.indices.contains(m) ? symbols[m] : "\(m + 1)",
               income: income[m], expense: expense[m])
    }
  }

  /// Net signed flow per day (income − expense) for the year calendar fill.
  private var dailyNet: [Date: Double] {
    var map: [Date: Double] = [:]
    for tx in txInYear {
      map[calendar.startOfDay(for: tx.date), default: 0] += tx.signedAmount
    }
    return map
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
    for tx in txInYear where tx.isExpense == expense {
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
    ScrollView {
      VStack(alignment: .leading, spacing: DLSpace.lg) {
        yearHeader
        yearSummaryCard
        monthlyBarCard
        yearCalendarCard
        categoryTotalsCard
      }
      .padding(.horizontal, DLSpace.lg)
      .padding(.vertical, DLSpace.xl)
      .animation(reduceMotion ? nil : DLAnim.standard, value: year)
    }
    .background(ThemedBackground(theme: theme))
    .navigationTitle(L("Finance report"))
    .navigationBarTitleDisplayMode(.inline)
    .tint(theme.accent)
  }

  private var yearHeader: some View {
    HStack {
      Text(L("Year"))
        .font(.dl(.headline, weight: .semibold))
        .foregroundStyle(DLColor.textPrimary)
      Spacer()
      YearStepper(
        year: $year,
        minYear: availableYears.first ?? year,
        maxYear: availableYears.last ?? year,
        accent: theme.accent,
        years: availableYears
      )
    }
  }

  private var yearSummaryCard: some View {
    GlassCard {
      HStack(spacing: DLSpace.lg) {
        summaryMetric(L("Income"), CurrencyFormatter.vnd(yearIncome), tint: DLColor.success)
        summaryMetric(L("Expense"), CurrencyFormatter.vnd(yearExpense), tint: expenseColor)
        summaryMetric(L("Net"), CurrencyFormatter.signedVND(yearIncome - yearExpense),
                      tint: yearIncome - yearExpense >= 0 ? DLColor.success : expenseColor)
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

  // MARK: - Monthly bar chart (item 7)

  private var monthlyBarCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Label(L("Income vs expense"), systemImage: "chart.bar.fill")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(theme.accent)

        if txInYear.isEmpty {
          emptyHint(L("No transactions in this year yet."))
        } else {
          Chart {
            ForEach(monthBars) { bar in
              BarMark(
                x: .value("Month", bar.label),
                y: .value("Amount", bar.income)
              )
              .position(by: .value("Type", L("Income")))
              .foregroundStyle(by: .value("Type", L("Income")))
              .cornerRadius(3)

              BarMark(
                x: .value("Month", bar.label),
                y: .value("Amount", bar.expense)
              )
              .position(by: .value("Type", L("Expense")))
              .foregroundStyle(by: .value("Type", L("Expense")))
              .cornerRadius(3)
            }
          }
          .chartForegroundStyleScale([
            L("Income"): DLColor.success,
            L("Expense"): expenseColor,
          ])
          .chartXScale(domain: monthBars.map(\.label))
          .chartLegend(position: .bottom, spacing: DLSpace.sm)
          .chartYAxis {
            AxisMarks(position: .leading) { value in
              AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.4))
              AxisValueLabel {
                if let amount = value.as(Double.self) {
                  Text(compactAmount(amount))
                    .font(.dl(.caption2))
                    .foregroundStyle(DLColor.textSecondary)
                }
              }
            }
          }
          .chartXAxis {
            AxisMarks { value in
              AxisValueLabel {
                if let label = value.as(String.self) {
                  Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(DLColor.textSecondary)
                }
              }
            }
          }
          .frame(height: 220)
          .animation(reduceMotion ? nil : DLAnim.standard, value: year)
        }
      }
    }
  }

  // MARK: - Year calendar (item 8)

  private var yearCalendarCard: some View {
    let net = dailyNet
    let maxAbs = max(1, net.values.map { abs($0) }.max() ?? 1)
    return GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Label(L("Daily flow"), systemImage: "calendar")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(theme.accent)

        YearActivityHeatmap(year: year, reduceMotion: reduceMotion) { day in
          guard let value = net[calendar.startOfDay(for: day)], value != 0 else {
            return DLColor.track.opacity(0.5)
          }
          let frac = min(1.0, abs(value) / maxAbs)
          let base = value < 0 ? expenseColor : DLColor.success
          return base.opacity(0.25 + 0.65 * frac)
        }

        HStack(spacing: DLSpace.md) {
          legendDot(DLColor.success, L("Income day"))
          legendDot(expenseColor, L("Expense day"))
          Spacer(minLength: 0)
        }
      }
    }
  }

  private func legendDot(_ color: Color, _ label: String) -> some View {
    HStack(spacing: 4) {
      RoundedRectangle(cornerRadius: 2.5, style: .continuous).fill(color).frame(width: 10, height: 10)
      Text(label)
        .font(.dl(.caption2, weight: .medium))
        .foregroundStyle(DLColor.textTertiary)
    }
  }

  // MARK: - Category totals (year)

  private var categoryTotalsCard: some View {
    let expenses = categoryTotals(expense: true)
    let incomes = categoryTotals(expense: false)
    return GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Label(L("By category"), systemImage: "list.bullet")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(theme.accent)

        if expenses.isEmpty && incomes.isEmpty {
          emptyHint(L("No transactions in this year yet."))
        } else {
          if !expenses.isEmpty {
            categoryGroup(L("Expenses"), totals: expenses)
          }
          if !incomes.isEmpty {
            if !expenses.isEmpty { Divider().overlay(DLColor.separator) }
            categoryGroup(L("Income"), totals: incomes)
          }
        }
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

  // MARK: - Helpers

  private func emptyHint(_ text: String) -> some View {
    Text(text)
      .font(.dl(.subheadline))
      .foregroundStyle(DLColor.textSecondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, DLSpace.md)
  }

  /// Shortens đồng amounts for chart axes — "1M", "150k", "0".
  private func compactAmount(_ value: Double) -> String {
    let v = abs(value)
    if v >= 1_000_000 { return String(format: "%.0fM", value / 1_000_000) }
    if v >= 1_000 { return String(format: "%.0fk", value / 1_000) }
    return String(format: "%.0f", value)
  }
}
