import SwiftUI
import SwiftData

/// A read-only summary of everything that happened on one day: the reflection
/// (Win · Mistake · Lesson · Adjustment, mood/energy, media), that day's notes,
/// goals completed that day, habits completed, and bed/wake time. Opens for any
/// day that has content — including days with only notes (no reflection).
struct DayDetailView: View {
  let day: Date

  @Environment(\.dismiss) private var dismiss

  @Query(sort: \Entry.day, order: .reverse) private var allEntries: [Entry]
  @Query private var allNotes: [DayNote]
  @Query(sort: \SmartGoal.createdAt, order: .reverse) private var allGoals: [SmartGoal]
  @Query(sort: \Habit.sortIndex) private var habits: [Habit]
  @Query private var sleeps: [SleepLog]
  @Query private var progressList: [UserProgress]

  private let calendar = Calendar.current

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  private var dayStart: Date { calendar.startOfDay(for: day) }
  private func isSameDay(_ date: Date) -> Bool { calendar.isDate(date, inSameDayAs: dayStart) }

  private var entry: Entry? { allEntries.first { isSameDay($0.day) } }

  private var notes: [DayNote] {
    allNotes
      .filter { $0.deletedAt == nil && isSameDay($0.createdAt) }
      .sorted { $0.createdAt < $1.createdAt }
  }

  private var completedGoals: [SmartGoal] {
    allGoals.filter { $0.deletedAt == nil && $0.isCompleted && ($0.completedAt.map(isSameDay) ?? false) }
  }

  private var completedHabits: [Habit] {
    habits.filter { !$0.isArchived && $0.isCompleted(on: dayStart, calendar: calendar) }
  }

  private var sleep: SleepLog? { sleeps.first { isSameDay($0.date) } }

  private var isEmpty: Bool {
    entry == nil && notes.isEmpty && completedGoals.isEmpty && completedHabits.isEmpty && sleep == nil
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: DLSpace.lg) {
          if let entry {
            moodEnergyCard(entry)
            ForEach(ReflectionKind.allCases) { kind in
              let text = entry.text(for: kind).trimmingCharacters(in: .whitespacesAndNewlines)
              if !text.isEmpty { reflectionCard(kind, text: text) }
            }
            if !entry.morningIntention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
              intentionCard(entry)
            }
            if !entry.sortedAttachments.isEmpty {
              mediaCard(L("Reflection media"), attachments: entry.sortedAttachments)
            }
          }

          if !notes.isEmpty { notesCard }
          if !completedGoals.isEmpty { goalsCard }
          if !completedHabits.isEmpty { habitsCard }
          if let sleep { sleepCard(sleep) }
          if let entry, entry.xpAwarded > 0 { xpCard(entry) }

          if isEmpty { emptyState }
        }
        .padding(DLSpace.md)
      }
      .themedBackground(theme)
      .navigationTitle(dayStart.formatted(.dateTime.weekday(.wide).month().day()))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(L("Done")) { dismiss() }.fontWeight(.semibold)
        }
      }
      .tint(theme.accent)
    }
  }

  // MARK: - Reflection

  private func moodEnergyCard(_ entry: Entry) -> some View {
    GlassCard {
      HStack(spacing: DLSpace.lg) {
        VStack(alignment: .leading, spacing: 2) {
          Text(L("Mood"))
            .font(.dl(.caption, weight: .medium))
            .foregroundStyle(DLColor.textTertiary)
          HStack(spacing: DLSpace.sm) {
            Text(entry.moodOption.emoji).font(.system(size: 28))
            Text(entry.moodOption.displayName)
              .font(.dl(.subheadline, weight: .semibold))
              .foregroundStyle(entry.moodOption.color)
          }
        }
        VStack(alignment: .leading, spacing: 4) {
          Text(L("Energy"))
            .font(.dl(.caption, weight: .medium))
            .foregroundStyle(DLColor.textTertiary)
          HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { level in
              Image(systemName: level <= entry.energy ? "bolt.fill" : "bolt")
                .font(.system(size: 13))
                .foregroundStyle(level <= entry.energy ? DLColor.xpGold : DLColor.textTertiary)
            }
          }
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(Lf("Energy %d of 5", entry.energy))
        }
        Spacer(minLength: 0)
      }
    }
  }

  private func reflectionCard(_ kind: ReflectionKind, text: String) -> some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        HStack(spacing: DLSpace.sm) {
          ZStack {
            Circle().fill(kind.accent.opacity(0.18)).frame(width: 34, height: 34)
            Image(systemName: kind.systemIcon)
              .font(.system(size: 15, weight: .semibold))
              .foregroundStyle(kind.accent)
          }
          Text(L(kind.title))
            .font(.dl(.headline, weight: .semibold))
            .foregroundStyle(DLColor.textPrimary)
        }
        Text(text)
          .font(.dl(.body))
          .foregroundStyle(DLColor.textSecondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  private func intentionCard(_ entry: Entry) -> some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        Label(L("Morning intention"), systemImage: "target")
          .font(.dl(.subheadline, weight: .semibold))
          .foregroundStyle(theme.accent)
        Text(entry.morningIntention)
          .font(.dl(.body))
          .foregroundStyle(DLColor.textSecondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  // MARK: - Notes

  private var notesCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Label(Lf("Notes (%d)", notes.count), systemImage: "note.text")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(theme.accent)

        ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
          VStack(alignment: .leading, spacing: DLSpace.xs) {
            HStack(spacing: DLSpace.sm) {
              if let option = note.moodOption { Text(option.emoji) }
              Text(noteTitle(note))
                .font(.dl(.subheadline, weight: .semibold))
                .foregroundStyle(DLColor.textPrimary)
                .lineLimit(1)
              Spacer(minLength: 0)
            }
            let preview = note.preview
            if !preview.isEmpty {
              Text(preview)
                .font(.dl(.caption))
                .foregroundStyle(DLColor.textSecondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !note.sortedAttachments.isEmpty {
              ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DLSpace.sm) {
                  ForEach(note.sortedAttachments) { attachment in
                    MediaViewer(attachment: attachment)
                  }
                }
              }
            }
          }
          if note.id != notes.last?.id {
            Divider().overlay(DLColor.separator.opacity(0.5))
          }
        }
      }
    }
  }

  private func noteTitle(_ note: DayNote) -> String {
    let trimmed = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty { return trimmed }
    return note.preview.isEmpty ? L("New note") : note.preview
  }

  // MARK: - Goals completed that day

  private var goalsCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Label(L("Goals completed"), systemImage: "checkmark.seal.fill")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(DLColor.success)
        ForEach(completedGoals) { goal in
          HStack(spacing: DLSpace.sm) {
            Image(systemName: "checkmark.seal.fill")
              .font(.system(size: 16))
              .foregroundStyle(DLColor.success)
            Text(goal.title)
              .font(.dl(.subheadline, weight: .medium))
              .foregroundStyle(DLColor.textPrimary)
              .lineLimit(2)
            Spacer(minLength: 0)
          }
        }
      }
    }
  }

  // MARK: - Habits completed

  private var habitsCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Label(L("Habits completed"), systemImage: "checklist")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(theme.accent)
        ForEach(completedHabits) { habit in
          HStack(spacing: DLSpace.sm) {
            Text(habit.emoji)
            Text(habit.name)
              .font(.dl(.subheadline, weight: .medium))
              .foregroundStyle(DLColor.textPrimary)
              .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 15))
              .foregroundStyle(DLColor.success)
          }
        }
      }
    }
  }

  // MARK: - Sleep

  private func sleepCard(_ sleep: SleepLog) -> some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Label(L("Sleep"), systemImage: "bed.double.fill")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(theme.accent)
        HStack(spacing: DLSpace.xl) {
          sleepMetric(L("Bedtime"), value: sleep.bedTime.formatted(date: .omitted, time: .shortened), icon: "moon.fill")
          sleepMetric(L("Wake"), value: sleep.wakeTime.formatted(date: .omitted, time: .shortened), icon: "sun.max.fill")
          sleepMetric(L("Duration"), value: String(format: "%.1f", sleep.durationHours), icon: "clock.fill")
        }
        HStack(spacing: 4) {
          ForEach(1...5, id: \.self) { level in
            Image(systemName: level <= sleep.quality ? "star.fill" : "star")
              .font(.system(size: 12))
              .foregroundStyle(level <= sleep.quality ? DLColor.xpGold : DLColor.textTertiary)
          }
          Text(L("quality"))
            .font(.dl(.caption2))
            .foregroundStyle(DLColor.textTertiary)
        }
      }
    }
  }

  private func sleepMetric(_ label: String, value: String, icon: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Label(label, systemImage: icon)
        .font(.dl(.caption2, weight: .medium))
        .foregroundStyle(DLColor.textTertiary)
        .labelStyle(.titleOnly)
      Text(value)
        .font(.dl(.subheadline, weight: .bold))
        .foregroundStyle(DLColor.textPrimary)
        .monospacedDigit()
    }
  }

  // MARK: - Media + XP

  private func mediaCard(_ title: String, attachments: [MediaAttachment]) -> some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        Text(title)
          .font(.dl(.subheadline, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: DLSpace.sm) {
            ForEach(attachments) { attachment in
              MediaViewer(attachment: attachment)
            }
          }
        }
      }
    }
  }

  private func xpCard(_ entry: Entry) -> some View {
    Label(Lf("+%d XP earned", entry.xpAwarded), systemImage: "bolt.fill")
      .font(.dl(.headline, weight: .semibold))
      .foregroundStyle(DLColor.xpGold)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 14)
      .background(DLColor.xpGold.opacity(0.12), in: RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous))
  }

  private var emptyState: some View {
    ContentUnavailableView {
      Label(L("Nothing logged"), systemImage: "calendar")
    } description: {
      Text(L("No reflection, notes, goals, habits, or sleep for this day."))
    }
    .padding(.top, DLSpace.xl)
  }
}
