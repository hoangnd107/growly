import SwiftUI
import SwiftData

/// Trash for soft-deleted habits: restore them (with their full log history) or
/// delete permanently. Mirrors the notes/goals Trash. Permanent deletion asks for
/// confirmation first (feature 5).
struct HabitTrashView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss

  @Query private var progressList: [UserProgress]
  @Query(sort: \Habit.sortIndex) private var allHabits: [Habit]

  @State private var pendingDelete: Habit?
  @State private var showEmptyConfirm = false

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  private var trashed: [Habit] {
    allHabits
      .filter { $0.deletedAt != nil }
      .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
  }

  var body: some View {
    NavigationStack {
      ZStack {
        ThemedBackground(theme: theme)
        if trashed.isEmpty {
          ContentUnavailableView {
            VStack(spacing: DLSpace.md) {
              EmptyGlyph(systemImage: "trash", size: 100, tint: theme.accent)
              Text(L("Trash is empty"))
                .font(.dl(.title3, weight: .semibold))
                .foregroundStyle(DLColor.textPrimary)
            }
          } description: {
            Text(L("Deleted habits appear here so you can restore them."))
          }
        } else {
          list
        }
      }
      .navigationTitle(L("Recently deleted"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(L("Done")) { dismiss() }
        }
        if !trashed.isEmpty {
          ToolbarItem(placement: .topBarTrailing) {
            Button(role: .destructive) { showEmptyConfirm = true } label: {
              Text(L("Empty"))
            }
          }
        }
      }
      .tint(theme.accent)
      .alert(L("Delete this habit forever?"), isPresented: deleteBinding) {
        Button(L("Cancel"), role: .cancel) { pendingDelete = nil }
        Button(L("Delete"), role: .destructive) { confirmDelete() }
      } message: {
        Text(L("This permanently removes the habit and its history. This can't be undone."))
      }
      .alert(L("Empty the trash?"), isPresented: $showEmptyConfirm) {
        Button(L("Cancel"), role: .cancel) {}
        Button(L("Delete All"), role: .destructive) { emptyTrash() }
      } message: {
        Text(L("This permanently removes all deleted habits and their history. This can't be undone."))
      }
    }
  }

  private var deleteBinding: Binding<Bool> {
    Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
  }

  private var list: some View {
    List {
      Section {
        ForEach(trashed) { habit in
          row(habit)
            .listRowInsets(EdgeInsets(top: DLSpace.xs, leading: DLSpace.md, bottom: DLSpace.xs, trailing: DLSpace.md))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .swipeActions(edge: .leading) {
              Button { restore(habit) } label: {
                Label(L("Restore"), systemImage: "arrow.uturn.backward")
              }
              .tint(DLColor.success)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
              Button(role: .destructive) { pendingDelete = habit } label: {
                Label(L("Delete"), systemImage: "trash")
              }
            }
        }
      } footer: {
        Text(L("Swipe a habit to restore it, or delete it permanently."))
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
          .padding(.horizontal, DLSpace.xs)
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
  }

  private func row(_ habit: Habit) -> some View {
    GlassCard {
      HStack(spacing: DLSpace.sm) {
        Text(habit.emoji.isEmpty ? "✅" : habit.emoji).font(.system(size: 22))
        VStack(alignment: .leading, spacing: 2) {
          Text(habit.name)
            .font(.dl(.headline, weight: .semibold))
            .foregroundStyle(DLColor.textPrimary)
            .lineLimit(1)
          if let deletedAt = habit.deletedAt {
            Text(deletedAt, format: .dateTime.month().day().hour().minute())
              .font(.dl(.caption2))
              .foregroundStyle(DLColor.textTertiary)
          }
        }
        Spacer(minLength: DLSpace.sm)
        Button { restore(habit) } label: {
          Label(L("Restore"), systemImage: "arrow.uturn.backward")
            .font(.dl(.subheadline, weight: .semibold))
            .foregroundStyle(DLColor.success)
        }
        .buttonStyle(.plain)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private func restore(_ habit: Habit) {
    habit.deletedAt = nil
    try? context.save()
    Haptics.success()
  }

  private func confirmDelete() {
    guard let habit = pendingDelete else { return }
    context.delete(habit)
    try? context.save()
    pendingDelete = nil
    Haptics.warning()
  }

  private func emptyTrash() {
    for habit in trashed { context.delete(habit) }
    try? context.save()
    Haptics.warning()
  }
}
