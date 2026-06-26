import SwiftUI
import SwiftData
import Charts

/// Shared finance visualizations (round 6, item 5): a category breakdown pie, a
/// per-month income-vs-expense bar chart, and a year calendar of daily net flow.
/// Each derives its data from the already-windowed transactions it's handed, so
/// the Money overview and the Detailed Report can show the very same charts.

private let financeExpenseColor = Color(hex: 0xE5484D)

// MARK: - Breakdown pie

/// Spending/income breakdown pie with an Expense|Income toggle.
struct FinanceBreakdownCard: View {
  let transactions: [FinanceTransaction]
  let categories: [FinanceCategory]
  let accent: Color

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var kind: Kind = .expense

  enum Kind: String, CaseIterable, Identifiable, Hashable {
    case expense, income
    var id: String { rawValue }
    var label: String { self == .expense ? L("Expenses") : L("Income") }
  }

  private struct SpendSlice: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let color: Color
    let amount: Double
  }

  /// Category totals for one side (expense/income), largest first.
  private func slices(expense: Bool) -> [SpendSlice] {
    var byCategory: [UUID: Double] = [:]
    var uncategorized = 0.0
    for tx in transactions where tx.isExpense == expense {
      if let cat = tx.category { byCategory[cat.id, default: 0] += tx.amount } else { uncategorized += tx.amount }
    }
    var result: [SpendSlice] = []
    for cat in categories where cat.isExpense == expense {
      if let amount = byCategory[cat.id], amount > 0 {
        result.append(SpendSlice(name: L(cat.name), emoji: cat.emoji, color: Color(hexString: cat.colorHex), amount: amount))
      }
    }
    if uncategorized > 0 {
      result.append(SpendSlice(name: L("Uncategorized"), emoji: "❓", color: DLColor.textTertiary, amount: uncategorized))
    }
    return result.sorted { $0.amount > $1.amount }
  }

  var body: some View {
    let data = slices(expense: kind == .expense)
    return GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Label(L("Breakdown"), systemImage: "chart.pie.fill")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(accent)

        SlidingSegmentedControl(
          items: Kind.allCases,
          label: { $0.label },
          selection: $kind,
          accent: accent
        )
        .accessibilityLabel(L("Breakdown type"))

        if data.isEmpty {
          Text(kind == .expense ? L("No spending in this period yet.") : L("No income in this period yet."))
            .font(.dl(.subheadline))
            .foregroundStyle(DLColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DLSpace.md)
        } else {
          pie(data)
          legend(data)
        }
      }
    }
    .animation(reduceMotion ? nil : DLAnim.standard, value: kind)
  }

  private func pie(_ slices: [SpendSlice]) -> some View {
    let total = slices.reduce(0) { $0 + $1.amount }
    return Chart(slices) { slice in
      SectorMark(
        angle: .value("Amount", slice.amount),
        innerRadius: .ratio(0.62),
        angularInset: 1.5
      )
      .cornerRadius(4)
      .foregroundStyle(slice.color)
    }
    .chartLegend(.hidden)
    .frame(height: 200)
    .overlay {
      VStack(spacing: 2) {
        Text(kind.label)
          .font(.dl(.caption2, weight: .medium))
          .foregroundStyle(DLColor.textTertiary)
        Text(CurrencyFormatter.vnd(total))
          .font(.dl(.headline, weight: .bold))
          .monospacedDigit()
          .foregroundStyle(kind == .expense ? financeExpenseColor : DLColor.success)
          .lineLimit(1)
          .minimumScaleFactor(0.5)
      }
      .padding(.horizontal, DLSpace.lg)
    }
  }

  private func legend(_ slices: [SpendSlice]) -> some View {
    let total = max(1, slices.reduce(0) { $0 + $1.amount })
    return VStack(spacing: DLSpace.xs) {
      ForEach(slices) { slice in
        HStack(spacing: DLSpace.sm) {
          Circle().fill(slice.color).frame(width: 10, height: 10)
          Text(slice.emoji)
          Text(slice.name)
            .font(.dl(.subheadline, weight: .medium))
            .foregroundStyle(DLColor.textPrimary)
            .lineLimit(1)
          Spacer(minLength: DLSpace.sm)
          Text("\(Int((slice.amount / total * 100).rounded()))%")
            .font(.dl(.caption2, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(DLColor.textTertiary)
          Text(CurrencyFormatter.vnd(slice.amount))
            .font(.dl(.subheadline, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(DLColor.textSecondary)
        }
      }
    }
  }
}

// MARK: - Monthly bar chart (year view)

/// Income vs expense per month (Jan…Dec) for the anchored year.
struct FinanceMonthlyBarCard: View {
  let transactions: [FinanceTransaction]
  let year: Int
  let accent: Color

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private var calendar: Calendar { Calendar.current }

  private struct MonthBar: Identifiable {
    let id = UUID()
    let month: Int
    let label: String
    let income: Double
    let expense: Double
  }

  private var monthBars: [MonthBar] {
    let symbols = calendar.shortStandaloneMonthSymbols
    var income = Array(repeating: 0.0, count: 12)
    var expense = Array(repeating: 0.0, count: 12)
    for tx in transactions {
      let m = calendar.component(.month, from: tx.date) - 1
      guard (0..<12).contains(m) else { continue }
      if tx.isExpense { expense[m] += tx.amount } else { income[m] += tx.amount }
    }
    return (0..<12).map { m in
      MonthBar(month: m + 1, label: symbols.indices.contains(m) ? symbols[m] : "\(m + 1)",
               income: income[m], expense: expense[m])
    }
  }

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Label(L("Income vs expense"), systemImage: "chart.bar.fill")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(accent)

        if transactions.isEmpty {
          Text(L("No transactions in this period yet."))
            .font(.dl(.subheadline))
            .foregroundStyle(DLColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DLSpace.md)
        } else {
          Chart {
            ForEach(monthBars) { bar in
              BarMark(x: .value("Month", bar.label), y: .value("Amount", bar.income))
                .position(by: .value("Type", L("Income")))
                .foregroundStyle(by: .value("Type", L("Income")))
                .cornerRadius(3)

              BarMark(x: .value("Month", bar.label), y: .value("Amount", bar.expense))
                .position(by: .value("Type", L("Expense")))
                .foregroundStyle(by: .value("Type", L("Expense")))
                .cornerRadius(3)
            }
          }
          .chartForegroundStyleScale([
            L("Income"): DLColor.success,
            L("Expense"): financeExpenseColor,
          ])
          .chartXScale(domain: monthBars.map(\.label))
          .chartLegend(position: .bottom, spacing: DLSpace.sm)
          .chartYAxis {
            AxisMarks(position: .leading) { value in
              AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.4))
              AxisValueLabel {
                if let amount = value.as(Double.self) {
                  Text(Self.compactAmount(amount))
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

  /// Shortens đồng amounts for chart axes — "1M", "150k", "0".
  static func compactAmount(_ value: Double) -> String {
    let v = abs(value)
    if v >= 1_000_000 { return String(format: "%.0fM", value / 1_000_000) }
    if v >= 1_000 { return String(format: "%.0fk", value / 1_000) }
    return String(format: "%.0f", value)
  }
}

// MARK: - Year calendar (year view)

/// A year calendar shaded by daily net flow (green = net income, red = net spend).
struct FinanceYearCalendarCard: View {
  let transactions: [FinanceTransaction]
  let year: Int
  let accent: Color

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private var calendar: Calendar { Calendar.current }

  private var dailyNet: [Date: Double] {
    var map: [Date: Double] = [:]
    for tx in transactions {
      map[calendar.startOfDay(for: tx.date), default: 0] += tx.signedAmount
    }
    return map
  }

  var body: some View {
    let net = dailyNet
    let maxAbs = max(1, net.values.map { abs($0) }.max() ?? 1)
    return GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Label(L("Daily flow"), systemImage: "calendar")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(accent)

        YearActivityHeatmap(year: year, reduceMotion: reduceMotion) { day in
          guard let value = net[calendar.startOfDay(for: day)], value != 0 else {
            return DLColor.track.opacity(0.5)
          }
          let frac = min(1.0, abs(value) / maxAbs)
          let base = value < 0 ? financeExpenseColor : DLColor.success
          return base.opacity(0.25 + 0.65 * frac)
        }

        HStack(spacing: DLSpace.md) {
          legendDot(DLColor.success, L("Income day"))
          legendDot(financeExpenseColor, L("Expense day"))
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
}
