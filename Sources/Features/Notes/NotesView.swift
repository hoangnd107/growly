import SwiftUI
import SwiftData

/// The Notes tab: a searchable, filterable list of free-form notes. Pinned
/// notes float to the top. Tapping a row opens the editor; the toolbar "+"
/// creates a new note. Swipe to pin/unpin or delete (which also removes the
/// note's media files from disk).
struct NotesView: View {
  @Environment(\.modelContext) private var context
  @Query(sort: \DayNote.createdAt, order: .reverse) private var notes: [DayNote]

  @State private var query = ""
  @State private var filter: NoteFilter = .all
  @State private var tagFilter: String?
  @State private var editorNote: DayNote?
  @State private var creatingNote = false

  private let calendar = Calendar.current

  // MARK: - Filtering

  private enum NoteFilter: String, CaseIterable, Identifiable {
    case all, today, week, pinned
    var id: String { rawValue }

    var label: String {
      switch self {
      case .all: return L("All")
      case .today: return L("Today")
      case .week: return L("This week")
      case .pinned: return L("Pinned")
      }
    }
  }

  /// All distinct tags across notes, for the optional tag filter row.
  private var allTags: [String] {
    var seen = Set<String>()
    var ordered: [String] = []
    for note in notes {
      for tag in note.tags where !seen.contains(tag) {
        seen.insert(tag)
        ordered.append(tag)
      }
    }
    return ordered.sorted()
  }

  /// Notes after applying the segmented filter, tag filter, and search; pinned
  /// notes are floated to the top while preserving the createdAt ordering.
  private var filtered: [DayNote] {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let now = Date()

    let matched = notes.filter { note in
      switch filter {
      case .all: break
      case .today:
        if !calendar.isDate(note.createdAt, inSameDayAs: now) { return false }
      case .week:
        guard calendar.isDate(note.createdAt, equalTo: now, toGranularity: .weekOfYear) else { return false }
      case .pinned:
        if !note.pinned { return false }
      }

      if let tagFilter, !note.tags.contains(tagFilter) { return false }

      guard !q.isEmpty else { return true }
      return note.title.lowercased().contains(q)
        || note.text.lowercased().contains(q)
        || note.tags.contains { $0.lowercased().contains(q) }
    }

    return matched.sorted { lhs, rhs in
      if lhs.pinned != rhs.pinned { return lhs.pinned && !rhs.pinned }
      return lhs.createdAt > rhs.createdAt
    }
  }

  // MARK: - Body

  var body: some View {
    NavigationStack {
      ZStack {
        DLColor.background.ignoresSafeArea()

        if notes.isEmpty {
          ContentUnavailableView {
            Label(L("No notes yet"), systemImage: "note.text")
          } description: {
            Text(L("Tap + to capture a thought, idea, or memory."))
          }
        } else {
          content
        }
      }
      .navigationTitle(L("Notes"))
      .searchable(text: $query, prompt: L("Search notes"))
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            creatingNote = true
          } label: {
            Image(systemName: "plus")
          }
          .accessibilityLabel(L("New note"))
        }
      }
      .sheet(item: $editorNote) { note in
        NavigationStack {
          NoteEditorView(note: note)
        }
      }
      .sheet(isPresented: $creatingNote) {
        NavigationStack {
          NoteEditorView(note: nil)
        }
      }
    }
  }

  private var content: some View {
    List {
      Section {
        filterChips
          .listRowInsets(EdgeInsets(top: DLSpace.sm, leading: DLSpace.md, bottom: 0, trailing: DLSpace.md))
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)

        if !allTags.isEmpty {
          tagChips
            .listRowInsets(EdgeInsets(top: DLSpace.sm, leading: DLSpace.md, bottom: 0, trailing: DLSpace.md))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
      }

      if filtered.isEmpty {
        ContentUnavailableView {
          Label(L("No matches"), systemImage: "magnifyingglass")
        } description: {
          Text(L("Try a different search or filter."))
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
      } else {
        ForEach(filtered) { note in
          Button {
            editorNote = note
          } label: {
            row(note)
          }
          .buttonStyle(.plain)
          .listRowInsets(EdgeInsets(top: DLSpace.xs, leading: DLSpace.md, bottom: DLSpace.xs, trailing: DLSpace.md))
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
          .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
              togglePin(note)
            } label: {
              Label(note.pinned ? L("Unpin") : L("Pinned"),
                    systemImage: note.pinned ? "pin.slash" : "pin")
            }
            .tint(DLColor.xpGold)
          }
          .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
              delete(note)
            } label: {
              Label(L("Delete"), systemImage: "trash")
            }
          }
          .contextMenu {
            Button {
              togglePin(note)
            } label: {
              Label(note.pinned ? L("Unpin") : L("Pinned"),
                    systemImage: note.pinned ? "pin.slash" : "pin")
            }
            Button(role: .destructive) {
              delete(note)
            } label: {
              Label(L("Delete"), systemImage: "trash")
            }
          }
        }
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .scrollDismissesKeyboard(.immediately)
  }

  // MARK: - Filter chips

  private var filterChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: DLSpace.sm) {
        ForEach(NoteFilter.allCases) { item in
          chip(label: item.label, isSelected: filter == item) {
            filter = item
          }
        }
      }
      .padding(.horizontal, 2)
    }
  }

  private var tagChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: DLSpace.sm) {
        ForEach(allTags, id: \.self) { tag in
          chip(label: "#\(tag)", isSelected: tagFilter == tag) {
            tagFilter = (tagFilter == tag) ? nil : tag
          }
        }
      }
      .padding(.horizontal, 2)
    }
  }

  private func chip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
    Button {
      withAnimation(DLAnim.quick) { action() }
      Haptics.selection()
    } label: {
      Text(label)
        .font(.dl(.subheadline, weight: .medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
          isSelected ? Color.accentColor.opacity(0.22) : DLColor.surfaceElevated,
          in: Capsule()
        )
        .overlay(
          Capsule().strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
        .foregroundStyle(isSelected ? Color.accentColor : DLColor.textSecondary)
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  // MARK: - Row

  private func row(_ note: DayNote) -> some View {
    HStack(spacing: 0) {
      if let colorHex = note.colorHex {
        RoundedRectangle(cornerRadius: 2)
          .fill(Color(hexString: colorHex))
          .frame(width: 4)
          .padding(.trailing, DLSpace.sm)
          .accessibilityHidden(true)
      }

      GlassCard {
        VStack(alignment: .leading, spacing: DLSpace.sm) {
          HStack(spacing: DLSpace.sm) {
            if let mood = note.mood {
              Text(mood.emoji)
            }
            Text(displayTitle(note))
              .font(.dl(.headline, weight: .semibold))
              .foregroundStyle(DLColor.textPrimary)
              .lineLimit(1)
            Spacer()
            if note.pinned {
              Image(systemName: "pin.fill")
                .font(.system(size: 12))
                .foregroundStyle(DLColor.xpGold)
                .accessibilityLabel(L("Pinned"))
            }
          }

          if !note.preview.isEmpty {
            Text(note.preview)
              .font(.dl(.subheadline))
              .foregroundStyle(DLColor.textSecondary)
              .lineLimit(2)
              .frame(maxWidth: .infinity, alignment: .leading)
          }

          HStack(spacing: DLSpace.md) {
            Text(note.createdAt, format: .dateTime.month().day().hour().minute())
              .font(.dl(.caption))
              .foregroundStyle(DLColor.textTertiary)

            if !note.attachments.isEmpty {
              Label("\(note.attachments.count)", systemImage: "paperclip")
                .font(.dl(.caption, weight: .medium))
                .foregroundStyle(DLColor.textTertiary)
                .accessibilityLabel(Lf("%d attachments", note.attachments.count))
            }

            if !note.tags.isEmpty {
              Text(note.tags.map { "#\($0)" }.joined(separator: " "))
                .font(.dl(.caption))
                .foregroundStyle(DLColor.textTertiary)
                .lineLimit(1)
            }
          }
        }
      }
    }
  }

  private func displayTitle(_ note: DayNote) -> String {
    let trimmed = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty { return trimmed }
    let preview = note.preview
    return preview.isEmpty ? L("New note") : preview
  }

  // MARK: - Actions

  private func togglePin(_ note: DayNote) {
    withAnimation(DLAnim.standard) {
      note.pinned.toggle()
    }
    note.updatedAt = Date()
    try? context.save()
    Haptics.selection()
  }

  private func delete(_ note: DayNote) {
    // Remove attachment binaries from disk before the cascade delete.
    for attachment in note.attachments {
      MediaStore.delete(attachment.fileName)
    }
    // If we just deleted the last note carrying the active tag filter, clear it.
    if let active = tagFilter, note.tags.contains(active) {
      let remaining = notes.filter { $0.id != note.id && $0.tags.contains(active) }
      if remaining.isEmpty { tagFilter = nil }
    }
    withAnimation(DLAnim.standard) {
      context.delete(note)
    }
    try? context.save()
  }
}
