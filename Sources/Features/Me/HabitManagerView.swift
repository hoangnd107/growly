import SwiftUI
import SwiftData

/// Manage the user's habits: add, rename inline, delete, reorder, and archive.
/// Presented as a sheet from the Me tab. Reads the per-user gradient theme so the
/// backdrop matches the rest of the app, and persists every change immediately.
struct HabitManagerView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss

  @Query(sort: \Habit.sortIndex) private var habits: [Habit]
  @Query private var progressList: [UserProgress]

  // New-habit draft fields.
  @State private var newName: String = ""
  @State private var newEmoji: String = "✅"
  @State private var newXP: Int = 12
  @State private var showAddSheet = false

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  var body: some View {
    NavigationStack {
      List {
        if habits.isEmpty {
          emptyState
        } else {
          Section {
            ForEach(habits) { habit in
              HabitRow(habit: habit, accent: theme.accent, onArchiveToggle: { toggleArchive(habit) })
            }
            .onDelete(perform: deleteHabits)
            .onMove(perform: moveHabits)
          } header: {
            Text(L("Your habits"))
              .font(.dl(.caption, weight: .semibold))
              .foregroundStyle(DLColor.textSecondary)
          } footer: {
            Text(L("Drag to reorder, swipe to delete, or archive to hide a habit without losing its history."))
              .font(.dl(.caption2))
              .foregroundStyle(DLColor.textTertiary)
          }
          .listRowBackground(Color.clear)
        }
      }
      .scrollContentBackground(.hidden)
      .themedBackground(theme)
      .navigationTitle(L("Habits"))
      .navigationBarTitleDisplayMode(.inline)
      .scrollDismissesKeyboard(.interactively)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(L("Done")) {
            Haptics.light()
            dismiss()
          }
          .font(.dl(.body, weight: .semibold))
          .tint(theme.accent)
        }
        ToolbarItem(placement: .topBarTrailing) {
          EditButton()
            .tint(theme.accent)
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            resetDraft()
            showAddSheet = true
          } label: {
            Image(systemName: "plus")
          }
          .tint(theme.accent)
          .accessibilityLabel(L("Add habit"))
        }
      }
      .sheet(isPresented: $showAddSheet) {
        addSheet
      }
    }
  }

  // MARK: Empty state

  private var emptyState: some View {
    VStack(spacing: DLSpace.md) {
      FlameMascot(size: 96, quote: L("Let's build a habit together!"))
      Text(L("No habits yet"))
        .font(.dl(.headline, weight: .semibold))
        .foregroundStyle(DLColor.textPrimary)
      Text(L("Tap + to add your first habit and start a streak."))
        .font(.dl(.subheadline))
        .foregroundStyle(DLColor.textSecondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, DLSpace.xl)
    .listRowBackground(Color.clear)
    .listRowSeparator(.hidden)
  }

  // MARK: Add sheet

  private var addSheet: some View {
    NavigationStack {
      Form {
        Section {
          TextField(L("Habit name"), text: $newName)
            .font(.dl(.body))
            .textInputAutocapitalization(.sentences)
          TextField(L("Emoji"), text: $newEmoji)
            .font(.dl(.body))
            .onChange(of: newEmoji) { _, value in
              // Keep a single visible character so the row stays tidy.
              if let first = value.first {
                let trimmed = String(first)
                if trimmed != value { newEmoji = trimmed }
              }
            }
        } header: {
          Text(L("Habit"))
        }

        Section {
          Stepper(value: $newXP, in: 10...20) {
            HStack {
              Text(L("XP per completion"))
                .font(.dl(.body))
                .foregroundStyle(DLColor.textPrimary)
              Spacer()
              Text("+\(newXP)")
                .font(.dl(.subheadline, weight: .bold))
                .foregroundStyle(DLColor.xpGold)
                .monospacedDigit()
            }
          }
          .tint(theme.accent)
        } header: {
          Text(L("Reward"))
        } footer: {
          Text(L("Completing this habit awards this much XP each day."))
            .font(.dl(.caption2))
        }
      }
      .scrollContentBackground(.hidden)
      .themedBackground(theme)
      .navigationTitle(L("New habit"))
      .navigationBarTitleDisplayMode(.inline)
      .keyboardDismissButton()
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(L("Cancel")) {
            Haptics.light()
            showAddSheet = false
          }
          .tint(theme.accent)
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button(L("Add")) {
            addHabit()
          }
          .font(.dl(.body, weight: .semibold))
          .tint(theme.accent)
          .disabled(trimmedName.isEmpty)
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  private var trimmedName: String {
    newName.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  // MARK: Actions

  private func resetDraft() {
    newName = ""
    newEmoji = "✅"
    newXP = 12
  }

  private func addHabit() {
    let name = trimmedName
    guard !name.isEmpty else { return }
    let emoji = newEmoji.isEmpty ? "✅" : newEmoji
    let nextIndex = (habits.map { $0.sortIndex }.max() ?? -1) + 1
    let habit = Habit(
      name: name,
      emoji: emoji,
      colorHex: progressList.first?.accentColorHex ?? "7E5BEF",
      xpValue: newXP,
      sortIndex: nextIndex
    )
    context.insert(habit)
    try? context.save()
    Haptics.success()
    resetDraft()
    showAddSheet = false
  }

  private func deleteHabits(at offsets: IndexSet) {
    for index in offsets {
      context.delete(habits[index])
    }
    try? context.save()
    normalizeSortIndices()
    Haptics.medium()
  }

  private func moveHabits(from source: IndexSet, to destination: Int) {
    var ordered = habits
    ordered.move(fromOffsets: source, toOffset: destination)
    for (index, habit) in ordered.enumerated() {
      habit.sortIndex = index
    }
    try? context.save()
    Haptics.selection()
  }

  private func toggleArchive(_ habit: Habit) {
    habit.isArchived.toggle()
    try? context.save()
    Haptics.selection()
  }

  /// Re-pack sort indices to a contiguous 0..<n range after a deletion so future
  /// inserts and reorders stay stable.
  private func normalizeSortIndices() {
    for (index, habit) in habits.enumerated() where habit.sortIndex != index {
      habit.sortIndex = index
    }
    try? context.save()
  }
}

/// A single editable habit row: emoji, inline-renamable name, XP value, and an
/// archive toggle. Binds directly to the `@Bindable` habit and saves on commit.
private struct HabitRow: View {
  @Environment(\.modelContext) private var context
  @Bindable var habit: Habit
  let accent: Color
  let onArchiveToggle: () -> Void

  var body: some View {
    HStack(spacing: DLSpace.sm) {
      Text(habit.emoji.isEmpty ? "✅" : habit.emoji)
        .font(.system(size: 24))
        .frame(width: 32)

      VStack(alignment: .leading, spacing: 2) {
        TextField(L("Habit name"), text: $habit.name)
          .font(.dl(.body, weight: .medium))
          .foregroundStyle(habit.isArchived ? DLColor.textTertiary : DLColor.textPrimary)
          .textInputAutocapitalization(.sentences)
          .onSubmit { try? context.save() }

        HStack(spacing: DLSpace.xs) {
          Text("+\(habit.xpValue) XP")
            .font(.dl(.caption2, weight: .semibold))
            .foregroundStyle(DLColor.xpGold)
          if habit.isArchived {
            Text(L("Archived"))
              .font(.dl(.caption2, weight: .medium))
              .foregroundStyle(DLColor.textTertiary)
          }
        }
      }

      Spacer()

      Button(action: onArchiveToggle) {
        Image(systemName: habit.isArchived ? "tray.and.arrow.up.fill" : "archivebox")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(habit.isArchived ? accent : DLColor.textSecondary)
          .frame(width: 44, height: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(habit.isArchived ? L("Unarchive") : L("Archive"))
    }
    .padding(.vertical, 4)
    .opacity(habit.isArchived ? 0.6 : 1)
    .accessibilityElement(children: .contain)
  }
}

#Preview {
  HabitManagerView()
    .modelContainer(for: [Habit.self, HabitLog.self, UserProgress.self], inMemory: true)
}
