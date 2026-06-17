import SwiftUI
import SwiftData

/// Trash for soft-deleted goals: restore them or delete permanently. Mirrors the
/// notes Trash; goals carry no media, so permanent delete is a plain delete.
struct GoalsTrashView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss

  @Query private var progressList: [UserProgress]
  @Query(sort: \SmartGoal.createdAt, order: .reverse) private var allGoals: [SmartGoal]

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  private var trashed: [SmartGoal] {
    allGoals
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
            Text(L("Deleted goals appear here so you can restore them."))
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
            Button(role: .destructive) { emptyTrash() } label: {
              Text(L("Empty"))
            }
          }
        }
      }
      .tint(theme.accent)
    }
  }

  private var list: some View {
    List {
      Section {
        ForEach(trashed) { goal in
          row(goal)
            .listRowInsets(EdgeInsets(top: DLSpace.xs, leading: DLSpace.md, bottom: DLSpace.xs, trailing: DLSpace.md))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .swipeActions(edge: .leading) {
              Button { restore(goal) } label: {
                Label(L("Restore"), systemImage: "arrow.uturn.backward")
              }
              .tint(DLColor.success)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
              Button(role: .destructive) { permanentlyDelete(goal) } label: {
                Label(L("Delete"), systemImage: "trash")
              }
            }
        }
      } footer: {
        Text(L("Swipe a goal to restore or delete it permanently."))
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
          .padding(.horizontal, DLSpace.xs)
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
  }

  private func row(_ goal: SmartGoal) -> some View {
    GlassCard {
      HStack(spacing: DLSpace.sm) {
        VStack(alignment: .leading, spacing: 2) {
          Text(goal.title)
            .font(.dl(.headline, weight: .semibold))
            .foregroundStyle(DLColor.textPrimary)
            .lineLimit(1)
          if let deletedAt = goal.deletedAt {
            Text(deletedAt, format: .dateTime.month().day().hour().minute())
              .font(.dl(.caption2))
              .foregroundStyle(DLColor.textTertiary)
          }
        }
        Spacer(minLength: DLSpace.sm)
        Button { restore(goal) } label: {
          Label(L("Restore"), systemImage: "arrow.uturn.backward")
            .font(.dl(.subheadline, weight: .semibold))
            .foregroundStyle(DLColor.success)
        }
        .buttonStyle(.plain)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private func restore(_ goal: SmartGoal) {
    goal.deletedAt = nil
    goal.updatedAt = Date()
    try? context.save()
    Haptics.success()
  }

  private func permanentlyDelete(_ goal: SmartGoal) {
    context.delete(goal)
    try? context.save()
    Haptics.warning()
  }

  private func emptyTrash() {
    for goal in trashed { context.delete(goal) }
    try? context.save()
    Haptics.warning()
  }
}
