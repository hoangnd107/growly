import SwiftUI
import SwiftData

/// Edit an existing sleep log's bed/wake times. Quality is derived from duration
/// (feature 6), so it is shown read-only and updates live as the times change.
struct SleepLogEditorSheet: View {
  @Bindable var sleep: SleepLog

  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @Query private var progressList: [UserProgress]

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  /// Live duration/quality from the in-progress edits.
  private var previewHours: Double { SleepLog.hours(bedTime: sleep.bedTime, wakeTime: sleep.wakeTime) }
  private var previewQuality: Int { SleepLog.quality(forHours: previewHours) }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          DatePicker(L("Night of"), selection: $sleep.date, displayedComponents: .date)
            .tint(theme.accent)
        } header: {
          Text(L("Date"))
        }

        Section {
          DatePicker(L("Bedtime"), selection: $sleep.bedTime, displayedComponents: .hourAndMinute)
            .tint(theme.accent)
          DatePicker(L("Wake time"), selection: $sleep.wakeTime, displayedComponents: .hourAndMinute)
            .tint(theme.accent)
        } header: {
          Text(L("Times"))
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
      .navigationTitle(L("Edit sleep"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(L("Cancel")) { dismiss() }.tint(theme.accent)
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button(L("Save")) { save() }
            .font(.dl(.body, weight: .semibold))
            .tint(theme.accent)
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  private func save() {
    sleep.date = Calendar.current.startOfDay(for: sleep.date)
    sleep.refreshQuality()
    try? context.save()
    Haptics.success()
    dismiss()
  }

  private func formattedDuration(_ hours: Double) -> String {
    let totalMinutes = Int((hours * 60).rounded())
    return Lf("%dh %dm", totalMinutes / 60, totalMinutes % 60)
  }
}
