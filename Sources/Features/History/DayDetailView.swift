import SwiftUI
import SwiftData

/// An editable summary of one day. Every section is always shown — mood, energy,
/// review (Win · Mistake · Lesson · Adjustment + intention), notes, habits, and
/// sleep — so any day (today or past) can be filled in or edited. Sections with no
/// data yet show a "Tap to set/add" placeholder, mirroring the unset-mood state.
/// Habits show only what's completed; tapping opens the full per-day toggle list.
struct DayDetailView: View {
  let day: Date

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context

  @Query(sort: \Entry.day, order: .reverse) private var allEntries: [Entry]
  @Query private var allNotes: [DayNote]
  @Query(sort: \SmartGoal.createdAt, order: .reverse) private var allGoals: [SmartGoal]
  @Query(sort: \Habit.sortIndex) private var habits: [Habit]
  @Query private var sleeps: [SleepLog]
  @Query private var progressList: [UserProgress]

  // Edit sheets / confirmations (A2, A3, C2).
  @State private var editingEntry: Entry?
  @State private var editorNote: DayNote?
  @State private var editingSleep: SleepLog?
  @State private var showMoodPicker = false
  @State private var showHabitSheet = false
  @State private var pendingSleepDelete: SleepLog?

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

  /// All active (non-archived, non-trashed) habits, so a forgotten one can be
  /// ticked for this day — not just the ones already completed.
  private var activeHabits: [Habit] {
    habits.filter { !$0.isArchived && $0.deletedAt == nil }
  }

  /// Active habits that are completed on this day (shown by default in the card).
  private var completedHabits: [Habit] {
    activeHabits.filter { $0.isCompleted(on: dayStart, calendar: calendar) }
  }

  /// Habits are only editable up to today — no back-filling the future.
  private var canEditHabits: Bool {
    dayStart <= calendar.startOfDay(for: Date())
  }

  private var sleep: SleepLog? { sleeps.first { isSameDay($0.date) } }

  /// Whether this day already has a reflection with any text in the WMLA fields.
  private var hasReviewText: Bool {
    guard let entry else { return false }
    return entry.filledCount > 0
      || !entry.morningIntention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    NavigationStack {
      // A List (not a ScrollView) so each row gets native swipe-to-edit/delete;
      // the themed background shows through via `.scrollContentBackground(.hidden)`.
      List {
        // 1) Mood & Energy — always shown, inline-editable (tap mood / a bolt).
        moodEnergyCard
          .dayDetailRow()

        // 2) Review (Win · Mistake · Lesson · Adjustment + intention).
        reviewSection

        // 3) Notes — always shown with an add affordance.
        notesSection

        // 4) Goals completed that day (only when present).
        if !completedGoals.isEmpty { goalsCard.dayDetailRow() }

        // 5) Habits — completed ones shown; tap to open the full toggle list.
        habitsCard
          .contentShape(Rectangle())
          .onTapGesture { if canEditHabits { showHabitSheet = true } }
          .dayDetailRow()

        // 6) Finances — log income/expense for this day (item 11).
        DayFinanceSection(day: dayStart)
          .dayDetailRow()

        // 7) Sleep — always shown; tap to add or edit.
        sleepSection

        if let entry, entry.xpAwarded > 0 { xpCard(entry).dayDetailRow() }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .themedBackground(theme)
      .navigationTitle(dayStart.formatted(.dateTime.weekday(.wide).month().day()))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(L("Done")) { dismiss() }.fontWeight(.semibold)
        }
      }
      .tint(theme.accent)
      .sheet(item: $editingEntry) { entry in
        EntryEditorSheet(entry: entry)
      }
      .sheet(item: $editorNote) { note in
        NavigationStack { NoteEditorView(note: note) }
      }
      .sheet(item: $editingSleep) { sleep in
        SleepLogEditorSheet(sleep: sleep)
      }
      .sheet(isPresented: $showMoodPicker) {
        MoodPickerSheet(current: currentMoodValue, allowClear: entry == nil) { value in
          applyMood(value)
        }
      }
      .sheet(isPresented: $showHabitSheet) {
        habitToggleSheet
      }
      .alert(L("Delete this sleep log?"), isPresented: deleteSleepBinding) {
        Button(L("Cancel"), role: .cancel) { pendingSleepDelete = nil }
        Button(L("Delete"), role: .destructive) { confirmDeleteSleep() }
      } message: {
        Text(L("This can't be undone."))
      }
    }
  }

  /// Drives the sleep-delete confirmation alert from the optional pending log.
  private var deleteSleepBinding: Binding<Bool> {
    Binding(
      get: { pendingSleepDelete != nil },
      set: { if !$0 { pendingSleepDelete = nil } }
    )
  }

  // MARK: - Entry helpers

  /// Returns this day's Entry, creating + inserting one if it doesn't exist yet,
  /// so mood/energy/review can be set on a day that had no reflection.
  @discardableResult
  private func ensureEntry() -> Entry {
    if let entry { return entry }
    let new = Entry(day: dayStart)
    context.insert(new)
    try? context.save()
    return new
  }

  // MARK: - Mood / energy editing (A2)

  /// The day's current mood value: the entry's if present, else the first note's.
  private var currentMoodValue: Int? {
    if let entry { return entry.moodRaw }
    return notes.first?.moodRaw
  }

  /// Applies a chosen mood — to the day's Entry (creating it if needed), or to the
  /// first note when there's no entry but a note carries the mood.
  private func applyMood(_ value: Int?) {
    if entry == nil, let note = notes.first {
      note.moodRaw = value
      note.updatedAt = Date()
    } else if let value {
      let e = ensureEntry()
      e.moodRaw = value
      e.updatedAt = Date()
    }
    try? context.save()
    Haptics.success()
  }

  /// Sets the day's energy (1...5), creating the Entry if needed.
  private func setEnergy(_ level: Int) {
    let e = ensureEntry()
    e.energy = level
    e.updatedAt = Date()
    try? context.save()
    Haptics.selection()
  }

  private func confirmDeleteSleep() {
    guard let sleep = pendingSleepDelete else { return }
    context.delete(sleep)
    try? context.save()
    pendingSleepDelete = nil
    Haptics.warning()
  }

  // MARK: - Mood & Energy (always shown)

  /// Combined mood + energy card. Tap the mood to pick one; tap a bolt to set
  /// energy. Both create the day's Entry on demand. Unset states read "Tap to set".
  private var moodEnergyCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        // Mood row (tap to open the picker).
        Button { showMoodPicker = true } label: {
          HStack(spacing: DLSpace.md) {
            VStack(alignment: .leading, spacing: 2) {
              Text(L("Mood"))
                .font(.dl(.caption, weight: .medium))
                .foregroundStyle(DLColor.textTertiary)
              if let value = currentMoodValue, let option = MoodCatalog.shared.option(forValue: value) {
                HStack(spacing: DLSpace.sm) {
                  Text(option.emoji).font(.system(size: 28))
                  Text(option.displayName)
                    .font(.dl(.subheadline, weight: .semibold))
                    .foregroundStyle(option.color)
                }
              } else {
                Text(L("Tap to set a mood"))
                  .font(.dl(.subheadline))
                  .foregroundStyle(DLColor.textSecondary)
              }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(DLColor.textTertiary)
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        Divider().overlay(DLColor.separator)

        // Energy row (tap a bolt to set 1...5).
        VStack(alignment: .leading, spacing: 4) {
          Text(L("Energy"))
            .font(.dl(.caption, weight: .medium))
            .foregroundStyle(DLColor.textTertiary)
          HStack(spacing: DLSpace.sm) {
            let current = entry?.energy ?? 0
            ForEach(1...5, id: \.self) { level in
              Button { setEnergy(level) } label: {
                Image(systemName: level <= current ? "bolt.fill" : "bolt")
                  .font(.system(size: 20))
                  .foregroundStyle(level <= current ? DLColor.xpGold : DLColor.textTertiary)
                  .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
            }
            if entry == nil {
              Text(L("Tap to set"))
                .font(.dl(.caption))
                .foregroundStyle(DLColor.textSecondary)
                .padding(.leading, DLSpace.xs)
            }
          }
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(Lf("Energy %d of 5", entry?.energy ?? 0))
        }
      }
    }
  }

  // MARK: - Review section (always shown)

  @ViewBuilder
  private var reviewSection: some View {
    if let entry, hasReviewText {
      ForEach(ReflectionKind.allCases) { kind in
        let text = entry.text(for: kind).trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
          reflectionCard(kind, text: text)
            .contentShape(Rectangle())
            .onTapGesture { editingEntry = entry }
            .dayDetailRow()
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
              Button { editingEntry = entry } label: { Label(L("Edit"), systemImage: "pencil") }
                .tint(theme.accent)
            }
        }
      }

      if !entry.morningIntention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        intentionCard(entry)
          .contentShape(Rectangle())
          .onTapGesture { editingEntry = entry }
          .dayDetailRow()
          .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { editingEntry = entry } label: { Label(L("Edit"), systemImage: "pencil") }
              .tint(theme.accent)
          }
      }

      if !entry.sortedAttachments.isEmpty {
        mediaCard(L("Reflection media"), attachments: entry.sortedAttachments)
          .dayDetailRow()
      }
    } else {
      reviewPlaceholderCard
        .contentShape(Rectangle())
        .onTapGesture { editingEntry = ensureEntry() }
        .dayDetailRow()
    }
  }

  private var reviewPlaceholderCard: some View {
    GlassCard {
      HStack(spacing: DLSpace.md) {
        ZStack {
          Circle().fill(theme.accent.opacity(0.18)).frame(width: 34, height: 34)
          Image(systemName: "square.and.pencil")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(theme.accent)
        }
        VStack(alignment: .leading, spacing: 2) {
          Text(L("Review"))
            .font(.dl(.headline, weight: .semibold))
            .foregroundStyle(DLColor.textPrimary)
          Text(L("Tap to write your daily review"))
            .font(.dl(.subheadline))
            .foregroundStyle(DLColor.textSecondary)
        }
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(DLColor.textTertiary)
      }
    }
  }

  // MARK: - Notes section (always shown)

  @ViewBuilder
  private var notesSection: some View {
    notesHeader.dayDetailRow()
    ForEach(notes) { note in
      noteRow(note)
        .contentShape(Rectangle())
        .onTapGesture { editorNote = note }
        .dayDetailRow()
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
          Button { editorNote = note } label: { Label(L("Edit"), systemImage: "pencil") }
            .tint(theme.accent)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
          Button(role: .destructive) { deleteNote(note) } label: { Label(L("Delete"), systemImage: "trash") }
        }
    }
    addNoteRow.dayDetailRow()
  }

  private var addNoteRow: some View {
    Button { addNote() } label: {
      Label(L("Add note"), systemImage: "plus.circle.fill")
        .font(.dl(.subheadline, weight: .semibold))
        .foregroundStyle(theme.accent)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  /// Creates a note dated to this day and opens the editor on it.
  private func addNote() {
    let note = DayNote()
    note.createdAt = calendar.isDateInToday(dayStart)
      ? Date()
      : (calendar.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart) ?? dayStart)
    context.insert(note)
    try? context.save()
    Haptics.light()
    editorNote = note
  }

  // MARK: - Sleep section (always shown)

  @ViewBuilder
  private var sleepSection: some View {
    if let sleep {
      sleepCard(sleep)
        .contentShape(Rectangle())
        .onTapGesture { editingSleep = sleep }
        .dayDetailRow()
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
          Button { editingSleep = sleep } label: { Label(L("Edit"), systemImage: "pencil") }
            .tint(theme.accent)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
          Button(role: .destructive) { pendingSleepDelete = sleep } label: { Label(L("Delete"), systemImage: "trash") }
        }
    } else {
      sleepPlaceholderCard
        .contentShape(Rectangle())
        .onTapGesture { addSleep() }
        .dayDetailRow()
    }
  }

  private var sleepPlaceholderCard: some View {
    GlassCard {
      HStack(spacing: DLSpace.md) {
        ZStack {
          Circle().fill(theme.accent.opacity(0.18)).frame(width: 34, height: 34)
          Image(systemName: "bed.double.fill")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(theme.accent)
        }
        VStack(alignment: .leading, spacing: 2) {
          Text(L("Sleep"))
            .font(.dl(.headline, weight: .semibold))
            .foregroundStyle(DLColor.textPrimary)
          Text(L("Tap to add sleep"))
            .font(.dl(.subheadline))
            .foregroundStyle(DLColor.textSecondary)
        }
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(DLColor.textTertiary)
      }
    }
  }

  /// Creates a sleep log for this day with sensible defaults and opens the editor.
  private func addSleep() {
    let bed = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: dayStart) ?? dayStart
    let wakeBase = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
    let wake = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: wakeBase) ?? wakeBase
    let log = SleepLog(date: dayStart, bedTime: bed, wakeTime: wake)
    context.insert(log)
    try? context.save()
    Haptics.light()
    editingSleep = log
  }

  // MARK: - Reflection cards

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

  private var notesHeader: some View {
    Label(Lf("Notes (%d)", notes.count), systemImage: "note.text")
      .font(.dl(.headline, weight: .semibold))
      .foregroundStyle(theme.accent)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// One note rendered as its own card so each gets native swipe-to-edit/delete.
  private func noteRow(_ note: DayNote) -> some View {
    GlassCard {
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
    }
  }

  /// Soft-delete (moves to Trash), mirroring NotesView — never a hard delete.
  private func deleteNote(_ note: DayNote) {
    let now = Date()
    note.deletedAt = now
    note.updatedAt = now
    try? context.save()
    Haptics.warning()
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

  /// Card shown in the day summary: only the habits COMPLETED that day, plus a
  /// chevron — tapping the card opens the full toggle list (`habitToggleSheet`).
  private var habitsCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        HStack {
          Label(L("Habits"), systemImage: "checklist")
            .font(.dl(.headline, weight: .semibold))
            .foregroundStyle(theme.accent)
          Spacer(minLength: 0)
          if canEditHabits {
            Image(systemName: "chevron.right")
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(DLColor.textTertiary)
          }
        }
        if completedHabits.isEmpty {
          Text(canEditHabits ? L("Tap to log your habits") : L("No habits completed"))
            .font(.dl(.subheadline))
            .foregroundStyle(DLColor.textSecondary)
        } else {
          ForEach(completedHabits) { habit in
            HStack(spacing: DLSpace.sm) {
              Text(habit.emoji.isEmpty ? "✅" : habit.emoji)
              Text(habit.name)
                .font(.dl(.subheadline, weight: .medium))
                .foregroundStyle(DLColor.textPrimary)
                .lineLimit(1)
              Spacer(minLength: 0)
              Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(DLColor.success)
            }
          }
        }
      }
    }
  }

  /// Full habit list with per-day toggles, presented when the habits card is tapped.
  private var habitToggleSheet: some View {
    NavigationStack {
      List {
        if activeHabits.isEmpty {
          Text(L("No habits yet. Add habits from Insights → Manage."))
            .font(.dl(.subheadline))
            .foregroundStyle(DLColor.textSecondary)
            .listRowBackground(Color.clear)
        } else {
          Section {
            ForEach(activeHabits) { habit in
              HabitDayToggleRow(habit: habit, day: dayStart)
                .listRowBackground(Color.clear)
            }
          } header: {
            Text(dayStart.formatted(.dateTime.weekday(.wide).month().day()))
              .font(.dl(.caption, weight: .semibold))
              .foregroundStyle(DLColor.textSecondary)
          }
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .themedBackground(theme)
      .navigationTitle(L("Habits"))
      .navigationBarTitleDisplayMode(.inline)
      .tint(theme.accent)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(L("Done")) { showHabitSheet = false }.fontWeight(.semibold)
        }
      }
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }

  // MARK: - Sleep

  private func sleepCard(_ sleep: SleepLog) -> some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Label(L("Sleep"), systemImage: "bed.double.fill")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(theme.accent)
          .frame(maxWidth: .infinity, alignment: .leading)
        HStack(spacing: DLSpace.xl) {
          sleepMetric(L("Bedtime"), value: sleep.bedTime.formatted(date: .omitted, time: .shortened), icon: "moon.fill")
          sleepMetric(L("Wake"), value: sleep.wakeTime.formatted(date: .omitted, time: .shortened), icon: "sun.max.fill")
          sleepMetric(L("Duration"), value: String(format: "%.1f", sleep.durationHours), icon: "clock.fill")
        }
        HStack(spacing: 4) {
          ForEach(1...5, id: \.self) { level in
            Image(systemName: level <= sleep.computedQuality ? "star.fill" : "star")
              .font(.system(size: 12))
              .foregroundStyle(level <= sleep.computedQuality ? DLColor.xpGold : DLColor.textTertiary)
          }
          Text(sleep.qualityLabel)
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

}

private extension View {
  /// List-row chrome for DayDetailView: a clear, separator-less row with
  /// card-style insets so each GlassCard floats over the themed background.
  func dayDetailRow() -> some View {
    self
      .listRowInsets(EdgeInsets(top: DLSpace.sm, leading: DLSpace.md, bottom: DLSpace.sm, trailing: DLSpace.md))
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
  }
}
