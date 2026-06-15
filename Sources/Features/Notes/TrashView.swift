import SwiftUI
import SwiftData

/// Recently-deleted notes. Soft-deleted notes land here so an accidental delete
/// can be undone — restore them, or remove them permanently (which also deletes
/// their media from disk). Presented as a sheet from Notes.
struct TrashView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss

  @Query private var progressList: [UserProgress]
  @Query(sort: \DayNote.createdAt, order: .reverse) private var allNotes: [DayNote]

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  /// Trashed notes, most-recently-deleted first.
  private var trashed: [DayNote] {
    allNotes
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
              EmptyGlyph(systemImage: "trash", size: 96, tint: theme.accent)
              Text(L("Trash is empty"))
                .font(.dl(.title3, weight: .semibold))
                .foregroundStyle(DLColor.textPrimary)
            }
          } description: {
            Text(L("Deleted notes appear here so you can restore them."))
              .foregroundStyle(DLColor.textSecondary)
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
              Text(L("Empty")).font(.dl(.subheadline, weight: .semibold))
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
        ForEach(trashed) { note in
          row(note)
            .listRowInsets(EdgeInsets(top: DLSpace.xs, leading: DLSpace.md, bottom: DLSpace.xs, trailing: DLSpace.md))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
              Button { restore(note) } label: {
                Label(L("Restore"), systemImage: "arrow.uturn.backward")
              }
              .tint(DLColor.success)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
              Button(role: .destructive) { permanentlyDelete(note) } label: {
                Label(L("Delete"), systemImage: "trash")
              }
            }
        }
      } footer: {
        Text(L("Swipe a note to restore or delete it permanently."))
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
          .padding(.horizontal, DLSpace.xs)
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
  }

  private func row(_ note: DayNote) -> some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.xs) {
        HStack(spacing: DLSpace.sm) {
          Text(title(note))
            .font(.dl(.headline, weight: .semibold))
            .foregroundStyle(DLColor.textPrimary)
            .lineLimit(1)
          Spacer(minLength: DLSpace.sm)
          Button { restore(note) } label: {
            Label(L("Restore"), systemImage: "arrow.uturn.backward")
              .font(.dl(.caption, weight: .semibold))
              .foregroundStyle(theme.accent)
          }
          .buttonStyle(.plain)
        }
        if let deletedAt = note.deletedAt {
          Label(deletedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "trash")
            .font(.dl(.caption))
            .foregroundStyle(DLColor.textTertiary)
            .labelStyle(.titleAndIcon)
        }
      }
    }
  }

  private func title(_ note: DayNote) -> String {
    let trimmed = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty { return trimmed }
    let preview = MarkdownFormatter.plain(note.text)
    return preview.isEmpty ? L("New note") : preview
  }

  // MARK: Actions

  private func restore(_ note: DayNote) {
    withAnimation(DLAnim.standard) {
      note.deletedAt = nil
      note.updatedAt = Date()
    }
    try? context.save()
    Haptics.success()
  }

  private func permanentlyDelete(_ note: DayNote) {
    withAnimation(DLAnim.standard) {
      for attachment in note.attachments { MediaStore.delete(attachment.fileName) }
      context.delete(note)
    }
    try? context.save()
    Haptics.warning()
  }

  private func emptyTrash() {
    withAnimation(DLAnim.standard) {
      for note in trashed {
        for attachment in note.attachments { MediaStore.delete(attachment.fileName) }
        context.delete(note)
      }
    }
    try? context.save()
    Haptics.warning()
  }
}
