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

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
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
      AddSleepSheet(theme: theme) { date, bedTime, wakeTime, quality in
        addSleep(date: date, bedTime: bedTime, wakeTime: wakeTime, quality: quality)
      }
    }
  }

  // MARK: Empty state

  private var emptyState: some View {
    ScrollView {
      VStack(spacing: DLSpace.md) {
        MiraView(size: 96, quote: L("Let's track your rest!"))
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

        HStack(spacing: DLSpace.lg) {
          averageHoursStat
          Divider()
            .frame(height: 44)
            .overlay(DLColor.separator)
          averageQualityStat
        }

        if !chartPoints.isEmpty {
          Divider().overlay(DLColor.separator)
          Text(L("Duration over the last 14 logs"))
            .font(.dl(.caption, weight: .medium))
            .foregroundStyle(DLColor.textTertiary)
          SleepDurationChart(points: chartPoints, accent: theme.accent, animate: animate)
            .accessibilityLabel(L("Sleep duration over the last 14 logs"))
        }
      }
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

        ForEach(sleeps) { sleep in
          SleepRow(sleep: sleep)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
              Button(role: .destructive) {
                delete(sleep)
              } label: {
                Label(L("Delete"), systemImage: "trash")
              }
            }
          if sleep.id != sleeps.last?.id {
            Divider().overlay(DLColor.separator)
          }
        }
      }
    }
  }

  // MARK: Derived data

  private var averageHours: Double {
    guard !sleeps.isEmpty else { return 0 }
    return sleeps.map(\.durationHours).reduce(0, +) / Double(sleeps.count)
  }

  private var averageQuality: Double {
    guard !sleeps.isEmpty else { return 0 }
    return Double(sleeps.map(\.quality).reduce(0, +)) / Double(sleeps.count)
  }

  /// The most recent 14 logs in chronological order (oldest → newest) for the bar chart.
  private var chartPoints: [SleepDurationPoint] {
    sleeps
      .prefix(14)              // sleeps are newest-first
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

  private func addSleep(date: Date, bedTime: Date, wakeTime: Date, quality: Int) {
    let log = SleepLog(date: date, bedTime: bedTime, wakeTime: wakeTime, quality: quality)
    context.insert(log)
    try? context.save()
    Haptics.success()
  }

  private func delete(_ sleep: SleepLog) {
    context.delete(sleep)
    try? context.save()
    Haptics.medium()
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
        StarRating(value: Double(sleep.quality))
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
  let onSave: (_ date: Date, _ bedTime: Date, _ wakeTime: Date, _ quality: Int) -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var date = Date()
  @State private var bedTime: Date = AddSleepSheet.defaultBedTime
  @State private var wakeTime: Date = AddSleepSheet.defaultWakeTime
  @State private var quality = 3

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
          Picker(L("Quality"), selection: $quality) {
            ForEach(1...5, id: \.self) { rating in
              Text(qualityLabel(rating)).tag(rating)
            }
          }
          .pickerStyle(.menu)
          .tint(theme.accent)
        } header: {
          Text(L("Quality"))
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
            onSave(date, bedTime, wakeTime, quality)
            dismiss()
          }
          .font(.dl(.body, weight: .semibold))
          .tint(theme.accent)
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  private func qualityLabel(_ rating: Int) -> String {
    let stars = String(repeating: "★", count: rating) + String(repeating: "☆", count: 5 - rating)
    return "\(stars)"
  }
}

#Preview {
  NavigationStack {
    SleepTrackerView()
  }
  .modelContainer(for: [SleepLog.self, UserProgress.self], inMemory: true)
}
