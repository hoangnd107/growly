import SwiftUI
import SwiftData
import Charts

/// A sleep tracker: a report header (average hours + quality), a 14-log bar
/// chart of duration, and a swipe-to-delete list of nightly logs. Pushed via a
/// `NavigationLink`, so it relies on an ambient `NavigationStack` and only sets
/// a `.navigationTitle`. Reads the per-user gradient theme so the backdrop
/// matches the rest of the app, and persists every change immediately.
struct SleepTrackerView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @Query(sort: \SleepLog.date, order: .reverse) private var sleeps: [SleepLog]
  @Query private var progressList: [UserProgress]

  @State private var showAddSheet = false
  @State private var editingSleep: SleepLog?
  @State private var pendingDelete: SleepLog?
  /// Active filter for BOTH the report summary and the log list (round 7, items
  /// 2–3): a specific month (chosen with the stepper) or one of the relative
  /// windows. Defaults to the current month.
  @State private var scope: SleepScope = .month
  @State private var monthAnchor: Date = SleepTrackerView.startOfMonth(Date())
  @State private var showMonthPicker = false
  @State private var showAllLogs = false

  /// Show only the most recent few logs inline; the rest open in a filtered sheet
  /// (round 7, item 2).
  private let logLimit = 5

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  private var calendar: Calendar { Calendar.current }

  private static func startOfMonth(_ date: Date) -> Date {
    let cal = Calendar.current
    return cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? cal.startOfDay(for: date)
  }

  /// Animate chart entrances only when Reduce Motion is off.
  private var animate: Bool { !reduceMotion }

  // MARK: Body

  var body: some View {
    ZStack {
      ThemedBackground(theme: theme)

      if sleeps.isEmpty {
        emptyState
      } else {
        content
      }
    }
    .navigationTitle(L("Sleep"))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          showAddSheet = true
        } label: {
          Image(systemName: "plus")
        }
        .tint(theme.accent)
        .accessibilityLabel(L("Add sleep"))
      }
    }
    .sheet(isPresented: $showAddSheet) {
      AddSleepSheet(theme: theme) { date, bedTime, wakeTime in
        addSleep(date: date, bedTime: bedTime, wakeTime: wakeTime)
      }
    }
    .sheet(item: $editingSleep) { sleep in
      SleepLogEditorSheet(sleep: sleep)
    }
    .sheet(isPresented: $showMonthPicker) {
      monthPickerSheet
        .presentationDetents([.height(320), .medium])
        .presentationDragIndicator(.visible)
    }
    .sheet(isPresented: $showAllLogs) {
      AllSleepLogsView(windowStart: windowStart, windowEndExclusive: windowEndExclusive, navTitle: scopeTitle)
    }
    .alert(L("Delete this sleep log?"), isPresented: deleteBinding) {
      Button(L("Cancel"), role: .cancel) { pendingDelete = nil }
      Button(L("Delete"), role: .destructive) { confirmDelete() }
    } message: {
      Text(L("This can't be undone."))
    }
  }

  private var deleteBinding: Binding<Bool> {
    Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
  }

  // MARK: Empty state

  private var emptyState: some View {
    ScrollView {
      VStack(spacing: DLSpace.md) {
        EmptyGlyph(systemImage: "bed.double.fill", size: 96, tint: theme.accent)
        Text(L("No sleep logged yet"))
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)
        Text(L("Tap + to log a night's sleep and start seeing your rest trends here."))
          .font(.dl(.subheadline))
          .foregroundStyle(DLColor.textSecondary)
          .multilineTextAlignment(.center)
        PrimaryButton(L("Add sleep"), systemImage: "moon.zzz.fill") {
          showAddSheet = true
        }
        .padding(.top, DLSpace.sm)
      }
      .frame(maxWidth: .infinity)
      .padding(DLSpace.lg)
      .padding(.top, DLSpace.xl)
    }
  }

  // MARK: Content

  private var content: some View {
    ScrollView {
      VStack(spacing: DLSpace.lg) {
        reportCard
        logsCard

        PrimaryButton(L("Add sleep"), systemImage: "moon.zzz.fill") {
          showAddSheet = true
        }
      }
      .padding(DLSpace.md)
    }
  }

  // MARK: Report header

  private var reportCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Label(L("Sleep report"), systemImage: "bed.double.fill")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(theme.accent)

        SlidingSegmentedControl(
          items: SleepScope.allCases,
          label: { $0.label },
          systemImage: { $0.icon },
          selection: $scope,
          accent: theme.accent
        )
        .accessibilityLabel(L("Time range"))

        if scope == .month {
          monthStepper
        }

        if rangedSleeps.isEmpty {
          Text(L("No sleep logged in this range."))
            .font(.dl(.subheadline))
            .foregroundStyle(DLColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DLSpace.sm)
        } else {
          HStack(spacing: DLSpace.lg) {
            averageHoursStat
            Divider()
              .frame(height: 44)
              .overlay(DLColor.separator)
            averageQualityStat
          }

          if !chartPoints.isEmpty {
            Divider().overlay(DLColor.separator)
            Text(L("Sleep duration over time"))
              .font(.dl(.caption, weight: .medium))
              .foregroundStyle(DLColor.textTertiary)
            SleepDurationChart(points: chartPoints, accent: theme.accent, animate: animate)
              .accessibilityLabel(L("Sleep duration over time"))
          }
        }
      }
    }
    .animation(reduceMotion ? nil : DLAnim.standard, value: scope)
    .animation(reduceMotion ? nil : DLAnim.standard, value: monthAnchor)
  }

  // MARK: - Month stepper (specific-month filter, round 7 item 3)

  private var monthStepper: some View {
    HStack(spacing: DLSpace.sm) {
      monthChevron("chevron.left", enabled: true, label: L("Previous month")) { shiftMonth(-1) }
      Spacer(minLength: 0)
      Button {
        Haptics.selection()
        showMonthPicker = true
      } label: {
        HStack(spacing: DLSpace.xs) {
          Text(monthAnchor, format: .dateTime.month(.wide).year())
            .font(.dl(.subheadline, weight: .bold))
            .foregroundStyle(DLColor.textPrimary)
          Image(systemName: "chevron.down")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(theme.accent)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(L("Choose month and year"))
      Spacer(minLength: 0)
      monthChevron("chevron.right", enabled: !isViewingCurrentMonth, label: L("Next month")) { shiftMonth(1) }
    }
  }

  private func monthChevron(_ systemName: String, enabled: Bool, label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(enabled ? theme.accent : DLColor.textTertiary)
        .frame(width: 36, height: 36)
        .background(DLColor.surfaceElevated.opacity(0.6), in: Circle())
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
    .accessibilityLabel(label)
  }

  private var isViewingCurrentMonth: Bool {
    calendar.isDate(monthAnchor, equalTo: Date(), toGranularity: .month)
  }

  private func shiftMonth(_ delta: Int) {
    guard let next = calendar.date(byAdding: .month, value: delta, to: monthAnchor) else { return }
    if delta > 0, calendar.compare(next, to: Date(), toGranularity: .month) == .orderedDescending { return }
    withAnimation(reduceMotion ? nil : DLAnim.standard) {
      monthAnchor = SleepTrackerView.startOfMonth(next)
    }
    Haptics.selection()
  }

  // MARK: - Month / year picker sheet

  private var pickerYearRange: ClosedRange<Int> {
    let currentYear = calendar.component(.year, from: Date())
    return (currentYear - 5)...currentYear
  }

  private var monthPickerSheet: some View {
    let selMonth = Binding<Int>(
      get: { calendar.component(.month, from: monthAnchor) },
      set: { setMonthYear(month: $0, year: nil) }
    )
    let selYear = Binding<Int>(
      get: { calendar.component(.year, from: monthAnchor) },
      set: { setMonthYear(month: nil, year: $0) }
    )
    return NavigationStack {
      HStack(spacing: 0) {
        Picker(L("Month"), selection: selMonth) {
          ForEach(1...12, id: \.self) { m in
            Text(calendar.standaloneMonthSymbols[m - 1]).tag(m)
          }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
        Picker(L("Year"), selection: selYear) {
          ForEach(Array(pickerYearRange), id: \.self) { y in
            Text(verbatim: String(y)).tag(y)
          }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
      }
      .padding(.horizontal, DLSpace.md)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .themedBackground(theme)
      .navigationTitle(L("Jump to month"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(L("This month")) {
            withAnimation(reduceMotion ? nil : DLAnim.standard) {
              monthAnchor = SleepTrackerView.startOfMonth(Date())
            }
            Haptics.light()
          }
          .tint(theme.accent)
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button(L("Done")) { showMonthPicker = false }
            .font(.dl(.body, weight: .semibold))
            .tint(theme.accent)
        }
      }
    }
  }

  /// Rebuilds `monthAnchor` from the picker, clamped to never land in a future month.
  private func setMonthYear(month: Int?, year: Int?) {
    var comps = calendar.dateComponents([.year, .month], from: monthAnchor)
    if let month { comps.month = month }
    if let year { comps.year = year }
    comps.day = 1
    guard let date = calendar.date(from: comps) else { return }
    let capped = min(date, SleepTrackerView.startOfMonth(Date()))
    withAnimation(reduceMotion ? nil : DLAnim.standard) {
      monthAnchor = SleepTrackerView.startOfMonth(capped)
    }
  }

  private var averageHoursStat: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(L("Avg sleep"))
        .font(.dl(.caption, weight: .medium))
        .foregroundStyle(DLColor.textSecondary)
      Text(formattedDuration(averageHours))
        .font(.system(.title2, design: .rounded).weight(.bold))
        .monospacedDigit()
        .foregroundStyle(DLColor.textPrimary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Lf("Average sleep %@", formattedDuration(averageHours)))
  }

  private var averageQualityStat: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(L("Avg quality"))
        .font(.dl(.caption, weight: .medium))
        .foregroundStyle(DLColor.textSecondary)
      StarRating(value: averageQuality)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Lf("Average quality %@ out of 5", String(format: "%.1f", averageQuality)))
  }

  // MARK: Logs list

  private var logsCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        Label(L("Sleep log"), systemImage: "list.bullet")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(theme.accent)

        // The log list now follows the same filter as the report and shows only
        // the most recent few; the rest open in a filtered sheet (round 7, item 2).
        if rangedSleeps.isEmpty {
          Text(L("No sleep logged in this range."))
            .font(.dl(.subheadline))
            .foregroundStyle(DLColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DLSpace.xs)
        } else {
          let shown = Array(rangedSleeps.prefix(logLimit))
          ForEach(shown) { sleep in
            // This list lives in a GlassCard (not a List), so edit/delete are exposed
            // as explicit controls + a context menu rather than swipe actions.
            HStack(spacing: DLSpace.sm) {
              SleepRow(sleep: sleep)
                .contentShape(Rectangle())
                .onTapGesture { editingSleep = sleep }
              Button { pendingDelete = sleep } label: {
                Image(systemName: RowAction.delete.icon)
                  .font(.system(size: 15))
                  .foregroundStyle(RowAction.delete.color)
                  .frame(width: 36, height: 36)
                  .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .accessibilityLabel(L("Delete sleep"))
            }
            .contextMenu {
              Button { editingSleep = sleep } label: { Label(L("Edit"), systemImage: RowAction.edit.icon) }
              Button(role: .destructive) { pendingDelete = sleep } label: { Label(L("Delete"), systemImage: RowAction.delete.icon) }
            }
            if sleep.id != shown.last?.id {
              Divider().overlay(DLColor.separator)
            }
          }

          if rangedSleeps.count > logLimit {
            Divider().overlay(DLColor.separator)
            Button {
              Haptics.light()
              showAllLogs = true
            } label: {
              HStack(spacing: 4) {
                Text(Lf("View all %d", rangedSleeps.count))
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
      }
    }
  }

  // MARK: Derived data

  /// Earliest day included for the active scope (nil = no lower bound).
  private var windowStart: Date? {
    switch scope {
    case .month: return monthAnchor
    case .week: return calendar.date(byAdding: .day, value: -7, to: Date())
    case .days30: return calendar.date(byAdding: .day, value: -30, to: Date())
    case .days90: return calendar.date(byAdding: .day, value: -90, to: Date())
    case .year: return calendar.date(byAdding: .day, value: -365, to: Date())
    case .all: return nil
    }
  }

  /// Exclusive upper bound (only the specific-month scope caps the top end).
  private var windowEndExclusive: Date? {
    scope == .month ? calendar.date(byAdding: .month, value: 1, to: monthAnchor) : nil
  }

  /// A human label for the active scope, used as the All-logs sheet title.
  private var scopeTitle: String {
    switch scope {
    case .month: return monthAnchor.formatted(.dateTime.month(.wide).year())
    case .week: return L("Last 7 days")
    case .days30: return L("Last 30 days")
    case .days90: return L("Last 90 days")
    case .year: return L("Last year")
    case .all: return L("All sleep")
    }
  }

  /// Logs within the active scope (newest-first, like the query).
  private var rangedSleeps: [SleepLog] {
    SleepScope.filter(sleeps, start: windowStart, endExclusive: windowEndExclusive, calendar: calendar)
  }

  private var averageHours: Double {
    guard !rangedSleeps.isEmpty else { return 0 }
    return rangedSleeps.map(\.durationHours).reduce(0, +) / Double(rangedSleeps.count)
  }

  private var averageQuality: Double {
    guard !rangedSleeps.isEmpty else { return 0 }
    return Double(rangedSleeps.map(\.computedQuality).reduce(0, +)) / Double(rangedSleeps.count)
  }

  /// Up to the most recent 60 logs in the range, chronological (oldest → newest)
  /// for the bar chart so longer windows stay readable.
  private var chartPoints: [SleepDurationPoint] {
    rangedSleeps
      .prefix(60)              // sleeps are newest-first
      .reversed()              // → oldest-first for left-to-right plotting
      .map { SleepDurationPoint(date: $0.date, hours: $0.durationHours) }
  }

  // MARK: Formatting

  /// Formats a duration in hours as e.g. "7h 30m".
  private func formattedDuration(_ hours: Double) -> String {
    let totalMinutes = Int((hours * 60).rounded())
    let h = totalMinutes / 60
    let m = totalMinutes % 60
    return Lf("%dh %dm", h, m)
  }

  // MARK: Actions

  private func addSleep(date: Date, bedTime: Date, wakeTime: Date) {
    let log = SleepLog(date: date, bedTime: bedTime, wakeTime: wakeTime)
    context.insert(log)
    try? context.save()
    Haptics.success()
  }

  private func confirmDelete() {
    guard let sleep = pendingDelete else { return }
    context.delete(sleep)
    try? context.save()
    pendingDelete = nil
    Haptics.warning()
  }
}

// MARK: - Star rating

/// A static 1...5 star display for an average quality value (supports halves).
private struct StarRating: View {
  /// The 1...5 value to show; fractional values fill a partial last star.
  let value: Double

  var body: some View {
    HStack(spacing: 3) {
      ForEach(1...5, id: \.self) { index in
        Image(systemName: symbol(for: index))
          .font(.system(size: 15))
          .foregroundStyle(DLColor.xpGold)
      }
    }
  }

  private func symbol(for index: Int) -> String {
    let threshold = Double(index)
    if value >= threshold { return "star.fill" }
    if value >= threshold - 0.5 { return "star.leadinghalf.filled" }
    return "star"
  }
}

// MARK: - Sleep row

/// One night's log: date, bed→wake times, hours, and quality stars.
private struct SleepRow: View {
  let sleep: SleepLog

  private static let timeFormat: Date.FormatStyle = .dateTime.hour().minute()
  private static let dayFormat: Date.FormatStyle = .dateTime.weekday(.abbreviated).month(.abbreviated).day()

  var body: some View {
    HStack(alignment: .center, spacing: DLSpace.sm) {
      VStack(alignment: .leading, spacing: 2) {
        Text(sleep.date, format: Self.dayFormat)
          .font(.dl(.subheadline, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)
        HStack(spacing: 4) {
          Image(systemName: "bed.double.fill")
            .font(.system(size: 11))
            .foregroundStyle(DLColor.textTertiary)
          Text(sleep.bedTime, format: Self.timeFormat)
          Image(systemName: "arrow.right")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(DLColor.textTertiary)
          Image(systemName: "sun.max.fill")
            .font(.system(size: 11))
            .foregroundStyle(DLColor.textTertiary)
          Text(sleep.wakeTime, format: Self.timeFormat)
        }
        .font(.dl(.caption))
        .foregroundStyle(DLColor.textSecondary)
        .monospacedDigit()
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 4) {
        Text(formattedDuration(sleep.durationHours))
          .font(.dl(.subheadline, weight: .bold))
          .monospacedDigit()
          .foregroundStyle(DLColor.textPrimary)
        StarRating(value: Double(sleep.computedQuality))
        Text(sleep.qualityLabel)
          .font(.dl(.caption2, weight: .medium))
          .foregroundStyle(DLColor.textTertiary)
      }
    }
    .padding(.vertical, DLSpace.xs)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }

  private func formattedDuration(_ hours: Double) -> String {
    let totalMinutes = Int((hours * 60).rounded())
    return Lf("%dh %dm", totalMinutes / 60, totalMinutes % 60)
  }
}

// MARK: - Duration chart

/// One bar in the sleep-duration chart.
struct SleepDurationPoint: Identifiable {
  let id = UUID()
  let date: Date
  let hours: Double
}

/// A bar chart of sleep duration (hours) over the most recent logs.
private struct SleepDurationChart: View {
  let points: [SleepDurationPoint]
  let accent: Color
  let animate: Bool

  var body: some View {
    Chart(points) { point in
      BarMark(
        x: .value("Date", point.date, unit: .day),
        y: .value("Hours", point.hours)
      )
      .cornerRadius(4)
      .foregroundStyle(
        LinearGradient(
          colors: [accent, accent.opacity(0.55)],
          startPoint: .top,
          endPoint: .bottom
        )
      )
    }
    .chartYAxis {
      AxisMarks(position: .leading) { value in
        AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.5))
        AxisValueLabel {
          if let hours = value.as(Double.self) {
            Text(Lf("%dh", Int(hours)))
              .font(.dl(.caption2))
              .foregroundStyle(DLColor.textSecondary)
          }
        }
      }
    }
    .chartXAxis {
      AxisMarks(values: .automatic(desiredCount: 4)) { _ in
        AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.4))
        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textSecondary)
      }
    }
    .frame(height: 170)
    .animation(animate ? DLAnim.standard : nil, value: points.map(\.hours))
  }
}

// MARK: - Add sleep sheet

/// Form to log a night's sleep: date, bed/wake times, and a 1...5 quality
/// picker. Calls `onSave` with the chosen values, then dismisses.
private struct AddSleepSheet: View {
  let theme: GradientTheme
  let onSave: (_ date: Date, _ bedTime: Date, _ wakeTime: Date) -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var date = Date()
  @State private var bedTime: Date = AddSleepSheet.defaultBedTime
  @State private var wakeTime: Date = AddSleepSheet.defaultWakeTime

  /// Live duration/quality preview from the chosen times (feature 6).
  private var previewHours: Double { SleepLog.hours(bedTime: bedTime, wakeTime: wakeTime) }
  private var previewQuality: Int { SleepLog.quality(forHours: previewHours, bedTime: bedTime) }

  /// Default bedtime: 11pm today.
  private static var defaultBedTime: Date {
    Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date()) ?? Date()
  }

  /// Default wake time: 7am today.
  private static var defaultWakeTime: Date {
    Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          DatePicker(L("Night of"), selection: $date, displayedComponents: .date)
            .font(.dl(.body))
            .tint(theme.accent)
        } header: {
          Text(L("Date"))
        }

        Section {
          DatePicker(L("Bedtime"), selection: $bedTime, displayedComponents: .hourAndMinute)
            .font(.dl(.body))
            .tint(theme.accent)
          DatePicker(L("Wake time"), selection: $wakeTime, displayedComponents: .hourAndMinute)
            .font(.dl(.body))
            .tint(theme.accent)
        } header: {
          Text(L("Times"))
        } footer: {
          Text(L("If you woke up the next morning, that's handled automatically."))
            .font(.dl(.caption2))
        }

        Section {
          HStack {
            Text(L("Duration"))
              .font(.dl(.body))
              .foregroundStyle(DLColor.textPrimary)
            Spacer()
            Text(formattedDuration(previewHours))
              .font(.dl(.subheadline, weight: .bold))
              .monospacedDigit()
              .foregroundStyle(DLColor.textSecondary)
          }
          HStack {
            Text(L("Quality"))
              .font(.dl(.body))
              .foregroundStyle(DLColor.textPrimary)
            Spacer()
            HStack(spacing: 3) {
              ForEach(1...5, id: \.self) { level in
                Image(systemName: level <= previewQuality ? "star.fill" : "star")
                  .font(.system(size: 13))
                  .foregroundStyle(DLColor.xpGold)
              }
            }
            Text(SleepLog.qualityLabel(for: previewQuality))
              .font(.dl(.subheadline, weight: .semibold))
              .foregroundStyle(DLColor.textSecondary)
          }
        } header: {
          Text(L("Computed quality"))
        } footer: {
          Text(L("Quality is calculated from how long you slept."))
            .font(.dl(.caption2))
        }
      }
      .scrollContentBackground(.hidden)
      .themedBackground(theme)
      .navigationTitle(L("Log sleep"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(L("Cancel")) {
            Haptics.light()
            dismiss()
          }
          .tint(theme.accent)
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button(L("Save")) {
            onSave(date, bedTime, wakeTime)
            dismiss()
          }
          .font(.dl(.body, weight: .semibold))
          .tint(theme.accent)
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  private func formattedDuration(_ hours: Double) -> String {
    let totalMinutes = Int((hours * 60).rounded())
    return Lf("%dh %dm", totalMinutes / 60, totalMinutes % 60)
  }
}

// MARK: - Sleep filter scope

/// The sleep report/log filter (round 7, items 2–3): a specific calendar month
/// (shown as a calendar icon, paired with a month stepper) or one of the relative
/// windows. Both the report summary and the log list scope to it.
enum SleepScope: String, CaseIterable, Identifiable {
  case month, week, days30, days90, year, all
  var id: String { rawValue }

  /// Icon-only for the specific-month scope; the relative windows use text.
  var icon: String? { self == .month ? "calendar" : nil }

  var label: String {
    switch self {
    case .month: return ""
    case .week: return L("7d")
    case .days30: return L("30d")
    case .days90: return L("90d")
    case .year: return L("Year")
    case .all: return L("All")
    }
  }

  /// Filters newest-first logs to `[start, endExclusive)`, treating nil bounds as
  /// open. `start` is normalized to the start of its day.
  static func filter(_ logs: [SleepLog], start: Date?, endExclusive: Date?, calendar: Calendar) -> [SleepLog] {
    let lower = start.map { calendar.startOfDay(for: $0) }
    return logs.filter { log in
      if let lower, log.date < lower { return false }
      if let endExclusive, log.date >= endExclusive { return false }
      return true
    }
  }
}

// MARK: - All sleep logs (filtered sheet)

/// The full sleep log scoped to the active filter, opened from "View all" (round
/// 7, item 2). Tap a row to edit, swipe-right to edit, swipe-left to delete.
struct AllSleepLogsView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context
  @Query(sort: \SleepLog.date, order: .reverse) private var sleeps: [SleepLog]
  @Query private var progressList: [UserProgress]

  let windowStart: Date?
  let windowEndExclusive: Date?
  let navTitle: String

  @State private var editingSleep: SleepLog?
  @State private var pendingDelete: SleepLog?

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  private var ranged: [SleepLog] {
    SleepScope.filter(sleeps, start: windowStart, endExclusive: windowEndExclusive, calendar: .current)
  }

  private var deleteBinding: Binding<Bool> {
    Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
  }

  var body: some View {
    NavigationStack {
      List {
        if ranged.isEmpty {
          Text(L("No sleep logged in this range."))
            .font(.dl(.subheadline))
            .foregroundStyle(DLColor.textSecondary)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } else {
          ForEach(ranged) { sleep in
            SleepRow(sleep: sleep)
              .contentShape(Rectangle())
              .onTapGesture { editingSleep = sleep }
              .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button { editingSleep = sleep } label: { Label(L("Edit"), systemImage: RowAction.edit.icon) }
                  .tint(RowAction.edit.color)
              }
              .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) { pendingDelete = sleep } label: { Label(L("Delete"), systemImage: RowAction.delete.icon) }
                  .tint(RowAction.delete.color)
              }
              .contextMenu {
                Button { editingSleep = sleep } label: { Label(L("Edit"), systemImage: RowAction.edit.icon) }
                Button(role: .destructive) { pendingDelete = sleep } label: { Label(L("Delete"), systemImage: RowAction.delete.icon) }
              }
              .listRowBackground(Color.clear)
              .listRowSeparator(.hidden)
          }
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .themedBackground(theme)
      .navigationTitle(navTitle)
      .navigationBarTitleDisplayMode(.inline)
      .tint(theme.accent)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(L("Done")) { dismiss() }.fontWeight(.semibold)
        }
      }
      .sheet(item: $editingSleep) { sleep in
        SleepLogEditorSheet(sleep: sleep)
      }
      .alert(L("Delete this sleep log?"), isPresented: deleteBinding) {
        Button(L("Cancel"), role: .cancel) { pendingDelete = nil }
        Button(L("Delete"), role: .destructive) { confirmDelete() }
      } message: {
        Text(L("This can't be undone."))
      }
    }
  }

  private func confirmDelete() {
    guard let sleep = pendingDelete else { return }
    context.delete(sleep)
    try? context.save()
    pendingDelete = nil
    Haptics.warning()
  }
}

#Preview {
  NavigationStack {
    SleepTrackerView()
  }
  .modelContainer(for: [SleepLog.self, UserProgress.self], inMemory: true)
}
