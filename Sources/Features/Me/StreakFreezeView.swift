import SwiftUI
import SwiftData

/// The full streak-freeze editor, pushed from the Me tab (so the controls stay
/// hidden until the user opens this page). Adjust the current streak, choose how
/// many days to protect, set the XP cost, then freeze — or clear upcoming frozen
/// days. Bound directly to `UserProgress`.
struct StreakFreezeView: View {
  @Bindable var progress: UserProgress
  @Environment(\.modelContext) private var context

  @State private var freezeDays: Int = 3
  @State private var costPerDay: Int = 50

  private var startOfToday: Date { Calendar.current.startOfDay(for: Date()) }

  /// Frozen days that are today or in the future (the ones still "active").
  private var upcomingFrozenCount: Int {
    let cal = Calendar.current
    let today = startOfToday
    return progress.streakFreezeDates.filter { cal.startOfDay(for: $0) >= today }.count
  }

  var body: some View {
    ScrollView {
      VStack(spacing: DLSpace.lg) {
        editorCard
      }
      .padding(DLSpace.md)
      .frame(maxWidth: 640)
      .frame(maxWidth: .infinity)
    }
    .scrollDismissesKeyboard(.interactively)
    .keyboardDismissButton()
    .themedBackground(progress.gradientTheme)
    .navigationTitle(L("Streak Freeze"))
    .navigationBarTitleDisplayMode(.inline)
  }

  private var editorCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        HStack(spacing: DLSpace.sm) {
          ZStack {
            Circle().fill(DLColor.streakStart.opacity(0.16)).frame(width: 40, height: 40)
            Image(systemName: "snowflake")
              .font(.system(size: 18, weight: .semibold))
              .foregroundStyle(Color(hex: 0x5AC8FA))
          }
          VStack(alignment: .leading, spacing: 1) {
            Text(L("Streak Freeze"))
              .font(.dl(.headline, weight: .semibold))
              .foregroundStyle(DLColor.textPrimary)
            Text(Lf("%d day streak · %d frozen days ahead", progress.currentStreak, upcomingFrozenCount))
              .font(.dl(.caption))
              .foregroundStyle(DLColor.textSecondary)
              .lineLimit(2)
          }
          Spacer(minLength: 0)
        }

        Divider().overlay(DLColor.separator.opacity(0.5))

        // Adjust streak — type a value or nudge with the stepper.
        HStack {
          Text(L("Adjust streak"))
            .font(.dl(.subheadline, weight: .medium))
            .foregroundStyle(DLColor.textPrimary)
          Spacer()
          numberField($progress.currentStreak, tint: DLColor.streakStart, placeholder: L("Streak"))
          Stepper("", value: $progress.currentStreak, in: 0...3650)
            .labelsHidden()
        }
        .onChange(of: progress.currentStreak) { _, newValue in
          if newValue < 0 { progress.currentStreak = 0 }
          if newValue > progress.longestStreak { progress.longestStreak = newValue }
          save()
        }

        // Days to freeze — type a value or nudge with the stepper.
        HStack {
          Text(L("Freeze days"))
            .font(.dl(.subheadline, weight: .medium))
            .foregroundStyle(DLColor.textPrimary)
          Spacer()
          numberField($freezeDays, tint: DLColor.textPrimary, placeholder: L("Days"))
          Stepper("", value: $freezeDays, in: 1...365)
            .labelsHidden()
        }
        .onChange(of: freezeDays) { _, newValue in
          if newValue < 1 { freezeDays = 1 }
        }

        // Cost per day — freely settable, can be 0 (free), no upper limit.
        VStack(alignment: .leading, spacing: DLSpace.xs) {
          HStack {
            Text(L("XP cost per day"))
              .font(.dl(.subheadline, weight: .medium))
              .foregroundStyle(DLColor.textPrimary)
            Spacer()
            TextField(L("Cost"), value: $costPerDay, format: .number)
              .keyboardType(.numberPad)
              .multilineTextAlignment(.trailing)
              .font(.dl(.subheadline, weight: .bold))
              .foregroundStyle(DLColor.xpGold)
              .frame(width: 72)
              .padding(.vertical, 6)
              .padding(.horizontal, DLSpace.sm)
              .background(
                RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous)
                  .fill(DLColor.separator.opacity(0.35))
              )
              .onChange(of: costPerDay) { _, newValue in
                if newValue < 0 { costPerDay = 0 }
              }
          }
          Stepper(value: $costPerDay, in: 0...100_000, step: 10) {
            Text(Lf("Total: %d XP", max(0, freezeDays * costPerDay)))
              .font(.dl(.caption, weight: .medium))
              .foregroundStyle(DLColor.textSecondary)
              .monospacedDigit()
          }
        }

        PrimaryButton(
          Lf("Freeze %d days", freezeDays),
          systemImage: "snowflake"
        ) {
          freeze()
        }

        Button {
          clearFrozen()
        } label: {
          HStack(spacing: DLSpace.xs) {
            Image(systemName: "trash")
            Text(L("Clear frozen days"))
          }
          .font(.dl(.subheadline, weight: .semibold))
          .foregroundStyle(upcomingFrozenCount > 0 ? DLColor.warning : DLColor.textTertiary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .disabled(upcomingFrozenCount == 0)
      }
    }
  }

  /// A compact, typeable number field (matches the XP-cost input style).
  private func numberField(_ value: Binding<Int>, tint: Color, placeholder: String) -> some View {
    TextField(placeholder, value: value, format: .number)
      .keyboardType(.numberPad)
      .multilineTextAlignment(.trailing)
      .font(.dl(.subheadline, weight: .bold))
      .foregroundStyle(tint)
      .frame(width: 64)
      .padding(.vertical, 6)
      .padding(.horizontal, DLSpace.sm)
      .background(
        RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous)
          .fill(DLColor.separator.opacity(0.35))
      )
  }

  /// Adds the next `freezeDays` calendar days (starting today) to the frozen set,
  /// avoiding duplicates, then deducts `days * costPerDay` from totalXP (clamped >= 0).
  private func freeze() {
    let cal = Calendar.current
    var existing = Set(progress.streakFreezeDates.map { cal.startOfDay(for: $0) })
    var additions: [Date] = []
    for offset in 0..<max(1, freezeDays) {
      guard let day = cal.date(byAdding: .day, value: offset, to: startOfToday) else { continue }
      let normalized = cal.startOfDay(for: day)
      if !existing.contains(normalized) {
        existing.insert(normalized)
        additions.append(normalized)
      }
    }
    progress.streakFreezeDates.append(contentsOf: additions)

    let cost = max(0, freezeDays * max(0, costPerDay))
    progress.totalXP = max(0, progress.totalXP - cost)

    save()
    Haptics.success()
  }

  /// Removes all frozen dates that are today or in the future.
  private func clearFrozen() {
    let cal = Calendar.current
    let today = startOfToday
    progress.streakFreezeDates.removeAll { cal.startOfDay(for: $0) >= today }
    save()
    Haptics.medium()
  }

  private func save() {
    try? context.save()
  }
}
