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
  @State private var showTrash = false

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  /// Active (non-trashed) habits — the only ones shown and reordered here.
  private var activeHabits: [Habit] {
    habits.filter { $0.deletedAt == nil }
  }

  private var trashedCount: Int {
    habits.filter { $0.deletedAt != nil }.count
  }

  var body: some View {
    NavigationStack {
      List {
        if activeHabits.isEmpty {
          emptyState
        } else {
          Section {
            ForEach(activeHabits) { habit in
              HabitRow(habit: habit, accent: theme.accent, onArchiveToggle: { toggleArchive(habit) })
            }
            .onDelete(perform: deleteHabits)
            .onMove(perform: moveHabits)
          } header: {
            Text(L("Your habits"))
              .font(.dl(.caption, weight: .semibold))
              .foregroundStyle(DLColor.textSecondary)
          } footer: {
            Text(L("Drag to reorder, swipe to move to Trash, or archive to hide a habit without losing its history."))
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
          HStack(spacing: DLSpace.md) {
            Button(L("Done")) {
              Haptics.light()
              dismiss()
            }
            .font(.dl(.body, weight: .semibold))
            if trashedCount > 0 {
              Button { showTrash = true } label: {
                Image(systemName: "trash")
              }
              .accessibilityLabel(L("Recently deleted"))
            }
          }
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
      .sheet(isPresented: $showTrash) {
        HabitTrashView()
      }
    }
  }

  // MARK: Empty state

  private var emptyState: some View {
    VStack(spacing: DLSpace.md) {
      EmptyGlyph(systemImage: "checklist", size: 96, tint: theme.accent)
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

  /// Swipe-delete moves the habit to the Trash (soft delete) rather than removing
  /// it immediately, so its history is preserved and it can be restored (feature 5).
  private func deleteHabits(at offsets: IndexSet) {
    let visible = activeHabits
    let now = Date()
    for index in offsets where visible.indices.contains(index) {
      visible[index].deletedAt = now
    }
    try? context.save()
    normalizeSortIndices()
    Haptics.medium()
  }

  private func moveHabits(from source: IndexSet, to destination: Int) {
    var ordered = activeHabits
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

  /// Re-pack sort indices to a contiguous 0..<n range over active habits so future
  /// inserts and reorders stay stable.
  private func normalizeSortIndices() {
    for (index, habit) in activeHabits.enumerated() where habit.sortIndex != index {
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
      // Editable icon (one grapheme) — change a habit's emoji any time after it's
      // created. Commits on every change so it persists immediately.
      TextField("✅", text: $habit.emoji)
        .font(.system(size: 24))
        .multilineTextAlignment(.center)
        .frame(width: 40)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .onChange(of: habit.emoji) { _, value in
          if let first = value.first {
            let single = String(first)
            if single != value { habit.emoji = single }
          }
          try? context.save()
        }
        .accessibilityLabel(L("Habit icon"))

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
