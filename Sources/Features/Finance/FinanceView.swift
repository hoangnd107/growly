import SwiftUI
import SwiftData
import UIKit
import Charts

/// Personal finance hub: income/expense/balance for a selectable time window, a
/// spending-by-category breakdown, and the transaction log. New transactions can
/// attach photos/videos (camera or library). Categories are user-managed. All
/// amounts are Vietnamese đồng (e.g. 10.000.000đ). Self-contained — pushed as
/// `FinanceView()` from the Insights → Manage hub.
struct FinanceView: View {
  @Environment(\.modelContext) private var context
  @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]
  @Query(sort: \FinanceCategory.sortIndex) private var categories: [FinanceCategory]
  @Query private var progressList: [UserProgress]

  /// The month being viewed (start-of-month). The summary, pie chart, and
  /// transaction list are all scoped to this month — finance is month-based
  /// (round 4): use the chevrons to step months.
  @State private var monthAnchor: Date = FinanceView.currentMonthStart
  @State private var showAdd = false
  @State private var editingTx: FinanceTransaction?
  @State private var showCategories = false
  /// Expense vs income side for the breakdown pie (item 5).
  @State private var pieKind: PieKind = .expense
  /// Transactions list: capped at 5 by default, all when expanded (item 6).
  @State private var transactionsExpanded = false

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  enum PieKind: String, CaseIterable, Identifiable, Hashable {
    case expense, income
    var id: String { rawValue }
    var label: String { self == .expense ? L("Expenses") : L("Income") }
  }

  private static var currentMonthStart: Date {
    Calendar.current.dateInterval(of: .month, for: Date())?.start
      ?? Calendar.current.startOfDay(for: Date())
  }

  private var calendar: Calendar { Calendar.current }

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  private let expenseColor = Color(hex: 0xE5484D)

  /// Default transactions shown before expanding (item 6).
  private let collapsedTransactionLimit = 5

  // MARK: - Derived data

  /// Whether the viewed month is the current one (caps the forward chevron).
  private var isCurrentMonth: Bool {
    calendar.isDate(monthAnchor, equalTo: Date(), toGranularity: .month)
  }

  /// Transactions in the viewed month (already newest-first from the query).
  private var txInMonth: [FinanceTransaction] {
    transactions.filter { calendar.isDate($0.date, equalTo: monthAnchor, toGranularity: .month) }
  }

  private var totalIncome: Double { txInMonth.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount } }
  private var totalExpense: Double { txInMonth.filter { $0.isExpense }.reduce(0) { $0 + $1.amount } }
  private var balance: Double { totalIncome - totalExpense }

  private struct SpendSlice: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let color: Color
    let amount: Double
  }

  /// Category totals for one side (expense/income) within the month, largest first.
  private func slices(expense: Bool) -> [SpendSlice] {
    var byCategory: [UUID: Double] = [:]
    var uncategorized = 0.0
    for tx in txInMonth where tx.isExpense == expense {
      if let cat = tx.category { byCategory[cat.id, default: 0] += tx.amount } else { uncategorized += tx.amount }
    }
    var slices: [SpendSlice] = []
    for cat in categories where cat.isExpense == expense {
      if let amount = byCategory[cat.id], amount > 0 {
        slices.append(SpendSlice(name: L(cat.name), emoji: cat.emoji, color: Color(hexString: cat.colorHex), amount: amount))
      }
    }
    if uncategorized > 0 {
      slices.append(SpendSlice(name: L("Uncategorized"), emoji: "❓", color: DLColor.textTertiary, amount: uncategorized))
    }
    return slices.sorted { $0.amount > $1.amount }
  }

  /// The default date for a brand-new transaction from the toolbar +: today when
  /// viewing the current month, else noon on the 1st of the viewed month.
  private var addDefaultDate: Date? {
    isCurrentMonth ? nil : calendar.date(bySettingHour: 12, minute: 0, second: 0, of: monthAnchor)
  }

  // MARK: - Body

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DLSpace.lg) {
        EditorialHeader(L("FINANCES"), L("Money"))

        monthNavigator

        summaryCard

        pieChartCard

        transactionsSection

        reportLink
      }
      .padding(.horizontal, DLSpace.lg)
      .padding(.vertical, DLSpace.xl)
      .animation(reduceMotion ? nil : DLAnim.standard, value: monthAnchor)
      .animation(reduceMotion ? nil : DLAnim.standard, value: transactionsExpanded)
    }
    .background(ThemedBackground(theme: theme))
    .navigationBarTitleDisplayMode(.inline)
    .tint(theme.accent)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button { showCategories = true } label: {
          Image(systemName: "folder")
        }
        .accessibilityLabel(L("Manage categories"))
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button { showAdd = true } label: {
          Image(systemName: "plus")
        }
        .accessibilityLabel(L("Add transaction"))
      }
    }
    .sheet(isPresented: $showAdd) {
      TransactionEditorSheet(existing: nil, defaultDate: addDefaultDate)
    }
    .sheet(item: $editingTx) { tx in
      TransactionEditorSheet(existing: tx)
    }
    .sheet(isPresented: $showCategories) {
      FinanceCategoryManagerView()
    }
    .onAppear(perform: seedDefaultCategoriesIfNeeded)
  }

  // MARK: - Month navigator

  /// "‹ June 2026 ›" — steps the viewed month; the forward chevron disables on the
  /// current month so you can't page into the future.
  private var monthNavigator: some View {
    HStack(spacing: DLSpace.sm) {
      monthChevron(systemName: "chevron.left", enabled: true, label: L("Previous month")) {
        shiftMonth(by: -1)
      }
      Spacer(minLength: 0)
      Text(monthAnchor, format: .dateTime.month(.wide).year())
        .font(.dl(.headline, weight: .bold))
        .foregroundStyle(DLColor.textPrimary)
        .contentTransition(.numericText())
      Spacer(minLength: 0)
      monthChevron(systemName: "chevron.right", enabled: !isCurrentMonth, label: L("Next month")) {
        shiftMonth(by: 1)
      }
    }
  }

  private func monthChevron(systemName: String, enabled: Bool, label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(enabled ? theme.accent : DLColor.textTertiary)
        .frame(width: 40, height: 40)
        .background(DLColor.surfaceElevated.opacity(0.6), in: Circle())
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
    .accessibilityLabel(label)
  }

  private func shiftMonth(by value: Int) {
    guard let next = calendar.date(byAdding: .month, value: value, to: monthAnchor) else { return }
    let nextStart = calendar.dateInterval(of: .month, for: next)?.start ?? next
    // Never page past the current month.
    if value > 0, nextStart > FinanceView.currentMonthStart { return }
    withAnimation(reduceMotion ? nil : DLAnim.standard) {
      monthAnchor = nextStart
      transactionsExpanded = false
    }
    Haptics.selection()
  }

  // MARK: - Summary

  private var summaryCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Text(L("Balance"))
          .font(.dl(.caption, weight: .medium))
          .foregroundStyle(DLColor.textTertiary)
        Text(CurrencyFormatter.signedVND(balance))
          .font(.system(.largeTitle, design: .rounded).weight(.bold))
          .monospacedDigit()
          .foregroundStyle(balance >= 0 ? DLColor.success : expenseColor)
          .lineLimit(1)
          .minimumScaleFactor(0.5)

        Divider().overlay(DLColor.separator)

        HStack(spacing: DLSpace.lg) {
          summaryMetric(L("Income"), CurrencyFormatter.vnd(totalIncome), icon: "arrow.down.circle.fill", tint: DLColor.success)
          summaryMetric(L("Expense"), CurrencyFormatter.vnd(totalExpense), icon: "arrow.up.circle.fill", tint: expenseColor)
        }
      }
    }
  }

  private func summaryMetric(_ label: String, _ value: String, icon: String, tint: Color) -> some View {
    HStack(spacing: DLSpace.sm) {
      Image(systemName: icon)
        .font(.system(size: 20))
        .foregroundStyle(tint)
      VStack(alignment: .leading, spacing: 0) {
        Text(label)
          .font(.dl(.caption2, weight: .medium))
          .foregroundStyle(DLColor.textTertiary)
        Text(value)
          .font(.dl(.subheadline, weight: .bold))
          .monospacedDigit()
          .foregroundStyle(DLColor.textPrimary)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Breakdown pie (item 5)

  private var pieChartCard: some View {
    let slices = slices(expense: pieKind == .expense)
    return GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Label(L("Breakdown"), systemImage: "chart.pie.fill")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(theme.accent)

        SlidingSegmentedControl(
          items: PieKind.allCases,
          label: { $0.label },
          selection: $pieKind,
          accent: theme.accent
        )
        .accessibilityLabel(L("Breakdown type"))

        if slices.isEmpty {
          Text(pieKind == .expense ? L("No spending this month yet.") : L("No income this month yet."))
            .font(.dl(.subheadline))
            .foregroundStyle(DLColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DLSpace.md)
        } else {
          pie(slices)
          pieLegend(slices)
        }
      }
    }
    .animation(reduceMotion ? nil : DLAnim.standard, value: pieKind)
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
        Text(pieKind.label)
          .font(.dl(.caption2, weight: .medium))
          .foregroundStyle(DLColor.textTertiary)
        Text(CurrencyFormatter.vnd(total))
          .font(.dl(.headline, weight: .bold))
          .monospacedDigit()
          .foregroundStyle(pieKind == .expense ? expenseColor : DLColor.success)
          .lineLimit(1)
          .minimumScaleFactor(0.5)
      }
      .padding(.horizontal, DLSpace.lg)
    }
  }

  private func pieLegend(_ slices: [SpendSlice]) -> some View {
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

  // MARK: - Detailed report link (item 10)

  private var reportLink: some View {
    NavigationLink {
      FinanceReportView()
    } label: {
      GlassCard {
        HStack(spacing: DLSpace.md) {
          ZStack {
            Circle().fill(theme.accent.opacity(0.18)).frame(width: 40, height: 40)
            Image(systemName: "chart.bar.doc.horizontal")
              .font(.system(size: 17, weight: .semibold))
              .foregroundStyle(theme.accent)
          }
          VStack(alignment: .leading, spacing: 2) {
            Text(L("Detailed report"))
              .font(.dl(.body, weight: .semibold))
              .foregroundStyle(DLColor.textPrimary)
            Text(L("Trends, bar chart & year calendar"))
              .font(.dl(.caption))
              .foregroundStyle(DLColor.textSecondary)
              .lineLimit(1)
          }
          Spacer(minLength: 0)
          Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(DLColor.textTertiary)
        }
      }
    }
    .buttonStyle(.plain)
  }

  // MARK: - Transactions

  private var transactionsSection: some View {
    let all = txInMonth
    let shown = transactionsExpanded ? all : Array(all.prefix(collapsedTransactionLimit))
    return VStack(alignment: .leading, spacing: DLSpace.sm) {
      SectionLabel(L("Transactions"))

      if all.isEmpty {
        emptyState
      } else {
        ForEach(shown) { tx in
          Button { editingTx = tx } label: { transactionRow(tx) }
            .buttonStyle(.plain)
        }
        if all.count > collapsedTransactionLimit {
          Button {
            withAnimation(reduceMotion ? nil : DLAnim.standard) { transactionsExpanded.toggle() }
            Haptics.selection()
          } label: {
            Text(transactionsExpanded ? L("Show less") : Lf("Show all %d", all.count))
              .font(.dl(.subheadline, weight: .semibold))
              .foregroundStyle(theme.accent)
              .frame(maxWidth: .infinity)
              .padding(.vertical, DLSpace.sm)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private func transactionRow(_ tx: FinanceTransaction) -> some View {
    let tint = tx.category.map { Color(hexString: $0.colorHex) } ?? theme.accent
    return GlassCard {
      HStack(spacing: DLSpace.md) {
        ZStack {
          Circle().fill(tint.opacity(0.18)).frame(width: 40, height: 40)
          Text(tx.category?.emoji ?? (tx.isExpense ? "💸" : "💰"))
            .font(.system(size: 18))
        }
        VStack(alignment: .leading, spacing: 2) {
          Text(transactionTitle(tx))
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

  private func transactionTitle(_ tx: FinanceTransaction) -> String {
    let note = tx.note.trimmingCharacters(in: .whitespacesAndNewlines)
    if !note.isEmpty { return note }
    if let cat = tx.category { return L(cat.name) }
    return tx.isExpense ? L("Expense") : L("Income")
  }

  private var emptyState: some View {
    VStack(spacing: DLSpace.sm) {
      Image(systemName: "creditcard")
        .font(.system(size: 32, weight: .light))
        .foregroundStyle(DLColor.textTertiary)
      Text(L("No transactions this month yet"))
        .font(.serif(.title3, weight: .semibold))
        .foregroundStyle(DLColor.textPrimary)
      Text(L("Tap + to record income or an expense."))
        .font(.dl(.subheadline))
        .foregroundStyle(DLColor.textSecondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, DLSpace.xl)
  }

  // MARK: - Seed

  private func seedDefaultCategoriesIfNeeded() {
    guard categories.isEmpty else { return }
    for category in FinanceCategory.defaults() {
      context.insert(category)
    }
    try? context.save()
  }
}

// MARK: - Transaction editor

/// Add or edit a transaction: type (expense/income), amount in đồng, category,
/// date, note, and attached media (camera photo/video, or library). For a NEW
/// transaction the model is inserted on appear so media can attach immediately; an
/// empty new transaction is deleted again on cancel.
struct TransactionEditorSheet: View {
  let existing: FinanceTransaction?
  /// For a NEW transaction, the date it should default to (e.g. the day being
  /// edited in Today / Progress). Ignored when editing an existing one.
  var defaultDate: Date? = nil

  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \FinanceCategory.sortIndex) private var categories: [FinanceCategory]
  @Query private var progressList: [UserProgress]

  @State private var tx: FinanceTransaction?
  @State private var amountText = ""
  @State private var isExpense = true
  @State private var date = Date()
  @State private var note = ""
  @State private var selectedCategoryID: UUID?
  @State private var showCamera = false
  @State private var didFinalize = false

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  private enum TxType: String, CaseIterable, Identifiable, Hashable {
    case expense, income
    var id: String { rawValue }
    var label: String { self == .expense ? L("Expense") : L("Income") }
  }

  private var typeBinding: Binding<TxType> {
    Binding(
      get: { isExpense ? .expense : .income },
      set: { newValue in
        isExpense = (newValue == .expense)
        // Keep the selected category valid for the chosen type.
        if let id = selectedCategoryID, let cat = categories.first(where: { $0.id == id }), cat.isExpense != isExpense {
          selectedCategoryID = categoriesForType.first?.id
        } else if selectedCategoryID == nil {
          selectedCategoryID = categoriesForType.first?.id
        }
      }
    )
  }

  private var categoriesForType: [FinanceCategory] {
    categories.filter { $0.isExpense == isExpense }
  }

  private var parsedAmount: Double {
    Double(amountText.filter { $0.isNumber }) ?? 0
  }

  /// Quick amount suggestions (item 9): the typed digits scaled by ×1.000, ×10.000,
  /// ×100.000, so you type a couple of digits and tap to fill (e.g. "15" →
  /// 15.000 / 150.000 / 1.500.000đ). Only shown for short input (1–3 digits).
  private var quickAmounts: [Double] {
    let base = Int(parsedAmount)
    guard base >= 1, base <= 999 else { return [] }
    return [base * 1_000, base * 10_000, base * 100_000].map(Double.init)
  }

  var body: some View {
    Group {
      if let tx {
        editor(tx)
      } else {
        ProgressView()
      }
    }
    .onAppear(perform: setup)
  }

  private func setup() {
    guard tx == nil else { return }
    if let existing {
      tx = existing
      amountText = existing.amount > 0 ? String(Int(existing.amount.rounded())) : ""
      isExpense = existing.isExpense
      date = existing.date
      note = existing.note
      selectedCategoryID = existing.category?.id
    } else {
      let start = defaultDate ?? Date()
      let fresh = FinanceTransaction(amount: 0, isExpense: true, date: start)
      context.insert(fresh)
      tx = fresh
      isExpense = true
      date = start
      selectedCategoryID = categoriesForType.first?.id
    }
  }

  @ViewBuilder
  private func editor(_ tx: FinanceTransaction) -> some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DLSpace.lg) {
          SlidingSegmentedControl(
            items: TxType.allCases,
            label: { $0.label },
            selection: typeBinding,
            accent: theme.accent
          )

          amountCard
          categoryCard
          detailsCard
          GlassCard {
            VStack(alignment: .leading, spacing: DLSpace.sm) {
              HStack {
                Text(L("Attachments"))
                  .font(.dl(.caption, weight: .semibold))
                  .foregroundStyle(DLColor.textSecondary)
                  .textCase(.uppercase)
                Spacer()
                Button {
                  if UIImagePickerController.isSourceTypeAvailable(.camera) { showCamera = true }
                } label: {
                  Image(systemName: "camera.fill").foregroundStyle(theme.accent)
                }
                .accessibilityLabel(L("Camera"))
              }
              MediaPickerField(
                attachments: tx.sortedAttachments,
                onAddImage: { data in addAttachment(data: data, type: .image, ext: "jpg") },
                onAddVideo: { data, ext in addAttachment(data: data, type: .video, ext: ext) },
                onDelete: deleteAttachment
              )
            }
          }

          if existing != nil {
            Button(role: .destructive) { deleteTransaction() } label: {
              Label(L("Delete transaction"), systemImage: "trash")
                .font(.dl(.subheadline, weight: .semibold))
                .frame(maxWidth: .infinity)
            }
            .padding(.top, DLSpace.sm)
          }
        }
        .padding(DLSpace.lg)
      }
      .scrollDismissesKeyboard(.interactively)
      .themedBackground(theme)
      .navigationTitle(existing == nil ? L("New transaction") : L("Edit transaction"))
      .navigationBarTitleDisplayMode(.inline)
      .tint(theme.accent)
      .keyboardDismissButton()
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(L("Cancel")) { cancel() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button(L("Save")) { save() }
            .fontWeight(.semibold)
            .disabled(parsedAmount <= 0)
        }
      }
      .fullScreenCover(isPresented: $showCamera) {
        CameraCaptureView(
          onImage: { image in addCameraImage(image) },
          onVideo: { url in addCameraVideo(url) }
        )
        .ignoresSafeArea()
      }
    }
    .presentationDetents([.large])
  }

  private var amountCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        Text(L("Amount"))
          .font(.dl(.caption, weight: .semibold))
          .foregroundStyle(DLColor.textSecondary)
          .textCase(.uppercase)
        HStack(spacing: DLSpace.sm) {
          TextField("0", text: $amountText)
            .font(.system(.largeTitle, design: .rounded).weight(.bold))
            .monospacedDigit()
            .keyboardType(.numberPad)
            .foregroundStyle(DLColor.textPrimary)
          Text("đ")
            .font(.system(.title, design: .rounded).weight(.semibold))
            .foregroundStyle(DLColor.textSecondary)
        }
        if parsedAmount > 0 {
          Text(CurrencyFormatter.vnd(parsedAmount))
            .font(.dl(.subheadline, weight: .medium))
            .foregroundStyle(DLColor.textTertiary)
            .monospacedDigit()
        }
        if !quickAmounts.isEmpty {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DLSpace.sm) {
              ForEach(quickAmounts, id: \.self) { amount in
                Button {
                  amountText = String(Int(amount))
                  Haptics.selection()
                } label: {
                  Text(CurrencyFormatter.vnd(amount))
                    .font(.dl(.caption, weight: .semibold))
                    .monospacedDigit()
                    .padding(.horizontal, DLSpace.sm)
                    .padding(.vertical, 6)
                    .background(theme.accent.opacity(0.12), in: Capsule())
                    .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
              }
            }
            .padding(.vertical, 2)
          }
        }
      }
    }
  }

  private var categoryCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        Text(L("Category"))
          .font(.dl(.caption, weight: .semibold))
          .foregroundStyle(DLColor.textSecondary)
          .textCase(.uppercase)
        if categoriesForType.isEmpty {
          Text(L("No categories yet. Add some from the folder icon."))
            .font(.dl(.subheadline))
            .foregroundStyle(DLColor.textSecondary)
        } else {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DLSpace.sm) {
              ForEach(categoriesForType) { category in
                categoryChip(category)
              }
            }
            .padding(.vertical, 2)
          }
        }
      }
    }
  }

  private func categoryChip(_ category: FinanceCategory) -> some View {
    let selected = selectedCategoryID == category.id
    let color = Color(hexString: category.colorHex)
    return Button {
      selectedCategoryID = selected ? nil : category.id
      Haptics.selection()
    } label: {
      HStack(spacing: 4) {
        Text(category.emoji)
        Text(L(category.name))
          .font(.dl(.subheadline, weight: .medium))
      }
      .padding(.horizontal, DLSpace.sm)
      .padding(.vertical, 6)
      .background(selected ? color.opacity(0.2) : DLColor.surfaceElevated.opacity(0.6), in: Capsule())
      .overlay(Capsule().strokeBorder(selected ? color : DLColor.separator.opacity(0.5), lineWidth: selected ? 2 : 1))
      .foregroundStyle(selected ? color : DLColor.textPrimary)
    }
    .buttonStyle(.plain)
  }

  private var detailsCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        DatePicker(L("Date"), selection: $date, displayedComponents: [.date, .hourAndMinute])
          .tint(theme.accent)
        Divider().overlay(DLColor.separator)
        TextField(L("Note (optional)"), text: $note, axis: .vertical)
          .lineLimit(1...4)
          .font(.dl(.body))
          .foregroundStyle(DLColor.textPrimary)
          .textInputAutocapitalization(.sentences)
      }
    }
  }

  // MARK: Media

  private func addAttachment(data: Data, type: MediaType, ext: String) {
    guard let tx, let name = MediaStore.save(data, ext: ext) else { return }
    let media = MediaAttachment(fileName: name, type: type, order: tx.attachments.count)
    media.transaction = tx
    context.insert(media)
    try? context.save()
  }

  private func addCameraImage(_ image: UIImage) {
    guard let data = image.jpegData(compressionQuality: 0.9) else { return }
    addAttachment(data: data, type: .image, ext: "jpg")
  }

  private func addCameraVideo(_ url: URL) {
    guard let tx, let name = MediaStore.copyFile(at: url) else { return }
    let media = MediaAttachment(fileName: name, type: .video, order: tx.attachments.count)
    media.transaction = tx
    context.insert(media)
    try? context.save()
  }

  private func deleteAttachment(_ media: MediaAttachment) {
    MediaStore.delete(media.fileName)
    context.delete(media)
    try? context.save()
  }

  // MARK: Save / cancel / delete

  private func save() {
    guard let tx, parsedAmount > 0 else { return }
    didFinalize = true
    tx.amount = parsedAmount
    tx.isExpense = isExpense
    tx.date = date
    tx.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    tx.category = categories.first { $0.id == selectedCategoryID }
    try? context.save()
    Haptics.success()
    dismiss()
  }

  private func cancel() {
    didFinalize = true
    if existing == nil, let tx, parsedAmount <= 0, tx.attachments.isEmpty {
      for media in tx.attachments { MediaStore.delete(media.fileName) }
      context.delete(tx)
      try? context.save()
    }
    dismiss()
  }

  private func deleteTransaction() {
    guard let tx else { return }
    didFinalize = true
    for media in tx.attachments { MediaStore.delete(media.fileName) }
    context.delete(tx)
    try? context.save()
    Haptics.warning()
    dismiss()
  }
}

// MARK: - Category manager

/// Create, rename, recolor, and delete spending/income categories.
private struct FinanceCategoryManagerView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \FinanceCategory.sortIndex) private var categories: [FinanceCategory]
  @Query private var progressList: [UserProgress]

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  private var expenseCategories: [FinanceCategory] { categories.filter { $0.isExpense } }
  private var incomeCategories: [FinanceCategory] { categories.filter { !$0.isExpense } }

  var body: some View {
    NavigationStack {
      List {
        section(L("Expense categories"), items: expenseCategories, isExpense: true)
        section(L("Income categories"), items: incomeCategories, isExpense: false)
      }
      .scrollContentBackground(.hidden)
      .themedBackground(theme)
      .navigationTitle(L("Categories"))
      .navigationBarTitleDisplayMode(.inline)
      .tint(theme.accent)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(L("Done")) { dismiss() }.fontWeight(.semibold)
        }
      }
    }
    .presentationDetents([.large])
  }

  @ViewBuilder
  private func section(_ title: String, items: [FinanceCategory], isExpense: Bool) -> some View {
    Section {
      ForEach(items) { category in
        CategoryRow(category: category)
          .listRowBackground(Color.clear)
      }
      .onDelete { offsets in delete(offsets, in: items) }

      Button {
        addCategory(isExpense: isExpense)
      } label: {
        Label(isExpense ? L("Add expense category") : L("Add income category"), systemImage: "plus.circle.fill")
          .font(.dl(.subheadline, weight: .semibold))
          .foregroundStyle(theme.accent)
      }
      .listRowBackground(Color.clear)
    } header: {
      Text(title)
        .font(.dl(.caption, weight: .semibold))
        .foregroundStyle(DLColor.textSecondary)
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

  private func delete(_ offsets: IndexSet, in items: [FinanceCategory]) {
    for index in offsets where items.indices.contains(index) {
      context.delete(items[index])
    }
    try? context.save()
    Haptics.medium()
  }
}

/// One editable category row: emoji, name, and a color picker.
private struct CategoryRow: View {
  @Environment(\.modelContext) private var context
  @Bindable var category: FinanceCategory

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
        .frame(width: 40)
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
    }
    .padding(.vertical, 2)
  }
}
