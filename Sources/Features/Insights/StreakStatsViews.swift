import SwiftUI
import SwiftData

// MARK: - Streak card (current / longest daily + longest weekly)

/// Self-contained streak summary used by both Insights (as a card) and History
/// (as a mode). Counts every day with a reflection OR a note, so imported and
/// app notes both contribute (feature 3).
struct StreakCard: View {
  @Query(sort: \Entry.day, order: .reverse) private var entries: [Entry]
  @Query private var notes: [DayNote]
  @Query private var progressList: [UserProgress]

  private var progress: UserProgress? { progressList.first }
  private var theme: GradientTheme { progress?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal") }

  private var stats: StreakStats {
    StreakStats.compute(
      entries: entries,
      notes: notes,
      frozenDays: progress?.streakFreezeDates ?? [],
      weekStartsMonday: progress?.weekStartsMonday ?? true
    )
  }

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Label(L("Streak"), systemImage: "flame.fill")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(DLColor.streakStart)

        HStack(spacing: 0) {
          metric(value: stats.currentDaily, label: L("Current streak"), unit: L("days"), tint: DLColor.streakStart, icon: "flame.fill")
          divider
          metric(value: stats.longestDaily, label: L("Longest streak"), unit: L("days"), tint: DLColor.streakEnd, icon: "trophy.fill")
          divider
          metric(value: stats.longestWeekly, label: L("Longest weekly streak"), unit: L("weeks"), tint: theme.accent, icon: "calendar")
        }

        Text(L("Counts every day you wrote a reflection or a note."))
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
      }
    }
  }

  private func metric(value: Int, label: String, unit: String, tint: Color, icon: String) -> some View {
    VStack(spacing: DLSpace.xs) {
      Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
      Text("\(value)")
        .font(.system(.title, design: .rounded).weight(.bold))
        .monospacedDigit()
        .foregroundStyle(DLColor.textPrimary)
        .contentTransition(.numericText())
        .lineLimit(1)
        .minimumScaleFactor(0.5)
      Text(unit)
        .font(.dl(.caption2, weight: .medium))
        .foregroundStyle(DLColor.textTertiary)
      Text(label)
        .font(.dl(.caption2, weight: .medium))
        .foregroundStyle(DLColor.textSecondary)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(label): \(value) \(unit)")
  }

  private var divider: some View {
    Rectangle().fill(DLColor.separator.opacity(0.6)).frame(width: 1, height: 64)
  }
}

// MARK: - Stats card (per-month bar chart + totals)

/// Self-contained Stats summary used by both Insights and History: a monthly
/// entries/notes bar chart for a chosen year plus all-time totals (entries,
/// notes, and total words written in notes).
struct StatsCard: View {
  @Query(sort: \Entry.day, order: .reverse) private var entries: [Entry]
  @Query private var notes: [DayNote]
  @Query private var progressList: [UserProgress]
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var year: Int = Calendar.current.component(.year, from: Date())

  private var theme: GradientTheme { progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal") }
  private var animate: Bool { !reduceMotion }
  private var years: [Int] { StatsSummary.availableYears(entries: entries, notes: notes) }
  private var summary: StatsSummary { StatsSummary.compute(entries: entries, notes: notes, year: year) }

  private var minYear: Int { years.min() ?? year }
  private var maxYear: Int { years.max() ?? year }

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        header

        MonthlyCountChart(
          points: summary.monthly,
          entriesLabel: L("Entries"),
          notesLabel: L("Notes"),
          entriesColor: theme.accent,
          notesColor: DLColor.xpGold,
          animate: animate
        )

        HStack(spacing: 0) {
          totalMetric(value: summary.totalEntries, label: L("Total entries"), tint: theme.accent)
          divider
          totalMetric(value: summary.totalNotes, label: L("Total notes"), tint: DLColor.xpGold)
          divider
          totalMetric(value: summary.totalNoteWords, label: L("Words in notes"), tint: DLColor.success)
        }

        Text(Lf("%d entries · %d notes in %d", summary.yearEntries, summary.yearNotes, year))
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
          .monospacedDigit()
      }
    }
    .onAppear {
      if !years.contains(year), let first = years.first { year = first }
    }
  }

  private var header: some View {
    HStack {
      Label(L("Stats"), systemImage: "chart.bar.fill")
        .font(.dl(.headline, weight: .semibold))
        .foregroundStyle(theme.accent)
      Spacer()
      HStack(spacing: DLSpace.sm) {
        yearButton(systemName: "chevron.left", enabled: year > minYear) { stepYear(-1) }
        Text(verbatim: String(year))
          .font(.dl(.subheadline, weight: .bold))
          .foregroundStyle(DLColor.textPrimary)
          .monospacedDigit()
          .frame(minWidth: 44)
        yearButton(systemName: "chevron.right", enabled: year < maxYear) { stepYear(1) }
      }
    }
  }

  private func stepYear(_ delta: Int) {
    let next = year + delta
    guard next >= minYear, next <= maxYear else { return }
    withAnimation(animate ? DLAnim.standard : nil) { year = next }
    Haptics.selection()
  }

  private func yearButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(enabled ? theme.accent : DLColor.textTertiary)
        .frame(width: 32, height: 32)
        .background(DLColor.surfaceElevated.opacity(0.6), in: Circle())
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
    .accessibilityLabel(systemName == "chevron.left" ? L("Previous year") : L("Next year"))
  }

  private func totalMetric(value: Int, label: String, tint: Color) -> some View {
    VStack(spacing: 2) {
      Text("\(value)")
        .font(.system(.title2, design: .rounded).weight(.bold))
        .monospacedDigit()
        .foregroundStyle(tint)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
      Text(label)
        .font(.dl(.caption2, weight: .medium))
        .foregroundStyle(DLColor.textSecondary)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(label): \(value)")
  }

  private var divider: some View {
    Rectangle().fill(DLColor.separator.opacity(0.6)).frame(width: 1, height: 40)
  }
}
