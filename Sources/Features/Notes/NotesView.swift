import SwiftUI
import SwiftData

/// The Notes tab — an Apple-Journal-style timeline of free-form notes.
///
/// Notes are grouped into soft timeline sections by a Week / Month / Year
/// granularity (Monday-first weeks). Pinned notes float into their own section
/// on top. A folder chip row, a filter menu, and `.searchable` narrow the list.
/// Rows are glass cards with a color stripe, mood, location, bookmark and
/// attachment cues.
///
/// Built on a `List`, so each row gets native **swipe actions** (leading: edit /
/// pin · trailing: bookmark / delete) and a multi-select **edit mode** that
/// supports tap-to-select, drag-across-to-select, and "Select all". A bottom
/// action bar (pin, bookmark, change date, delete) acts on the whole selection,
/// and a draggable floating "+" composes a new note.
struct NotesView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @Query(sort: \DayNote.createdAt, order: .reverse) private var notes: [DayNote]
  @Query private var progressList: [UserProgress]

  // Search / filtering
  @State private var query = ""
  @State private var granularity: Granularity = .month
  @State private var folderFilter: String?
  @State private var filter: NoteFilter = .all
  @State private var moodFilter: Mood?

  // Sheets
  @State private var editorNote: DayNote?
  @State private var creatingNote = false

  // Multi-select
  @State private var editMode: EditMode = .inactive
  @State private var selection = Set<UUID>()
  @State private var showBatchDatePicker = false
  @State private var batchDate = Date()

  // Floating button drag
  @State private var fabDrag: CGSize = .zero
  @State private var fabBase: CGSize = .zero

  private let calendar: Calendar = {
    var cal = Calendar.current
    cal.firstWeekday = 2 // Monday-first weeks
    return cal
  }()

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  private var selecting: Bool { editMode.isEditing }

  // MARK: - Granularity

  private enum Granularity: String, CaseIterable, Identifiable {
    case week, month, year
    var id: String { rawValue }

    var label: String {
      switch self {
      case .week: return L("Week")
      case .month: return L("Month")
      case .year: return L("Year")
      }
    }
  }

  // MARK: - Filter

  private enum NoteFilter: Hashable {
    case all, pinned, bookmarked, media
  }

  private var isFiltering: Bool { filter != .all || moodFilter != nil }

  // MARK: - Derived data

  /// Distinct, sorted folder names across all notes (nil folders excluded).
  private var folders: [String] {
    var seen = Set<String>()
    var ordered: [String] = []
    for note in notes {
      if let folder = note.folder?.trimmingCharacters(in: .whitespacesAndNewlines),
         !folder.isEmpty, !seen.contains(folder) {
        seen.insert(folder)
        ordered.append(folder)
      }
    }
    return ordered.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
  }

  /// All notes after search + folder + filter narrowing (pinned still included).
  private var matched: [DayNote] {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return notes.filter { note in
      if let folderFilter, note.folder != folderFilter { return false }
      switch filter {
      case .all: break
      case .pinned: if !note.pinned { return false }
      case .bookmarked: if !note.bookmarked { return false }
      case .media: if note.attachments.isEmpty { return false }
      }
      if let moodFilter, note.mood != moodFilter { return false }
      guard !q.isEmpty else { return true }
      return note.title.lowercased().contains(q)
        || note.text.lowercased().contains(q)
        || note.tags.contains { $0.lowercased().contains(q) }
        || (note.locationName?.lowercased().contains(q) ?? false)
    }
  }

  private var pinnedNotes: [DayNote] {
    matched.filter { $0.pinned }
  }

  /// Unpinned notes grouped into timeline sections by the selected granularity,
  /// newest period first.
  private var sections: [TimelineSection] {
    let unpinned = matched.filter { !$0.pinned }
    var order: [Date] = []
    var buckets: [Date: [DayNote]] = [:]

    for note in unpinned {
      let key = periodStart(for: note.createdAt)
      if buckets[key] == nil {
        buckets[key] = []
        order.append(key)
      }
      buckets[key]?.append(note)
    }

    return order.map { key in
      TimelineSection(id: key, label: periodLabel(for: key), notes: buckets[key] ?? [])
    }
  }

  private struct TimelineSection: Identifiable {
    let id: Date
    let label: String
    let notes: [DayNote]
  }

  private var hasResults: Bool {
    !pinnedNotes.isEmpty || !sections.isEmpty
  }

  /// IDs of every note currently visible (pinned + timeline), for "Select all".
  private var visibleIDs: [UUID] {
    pinnedNotes.map(\.id) + sections.flatMap { $0.notes.map(\.id) }
  }

  // MARK: - Period helpers

  private func periodStart(for date: Date) -> Date {
    let comps: DateComponents
    switch granularity {
    case .week:
      comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
    case .month:
      comps = calendar.dateComponents([.year, .month], from: date)
    case .year:
      comps = calendar.dateComponents([.year], from: date)
    }
    return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
  }

  private func periodLabel(for start: Date) -> String {
    let locale = LocalizationManager.shared.locale ?? .current
    switch granularity {
    case .week:
      let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
      let f = DateFormatter()
      f.locale = locale
      f.setLocalizedDateFormatFromTemplate("MMMd")
      return "\(f.string(from: start)) – \(f.string(from: end))"
    case .month:
      let f = DateFormatter()
      f.locale = locale
      f.setLocalizedDateFormatFromTemplate("MMMMyyyy")
      return f.string(from: start)
    case .year:
      let f = DateFormatter()
      f.locale = locale
      f.setLocalizedDateFormatFromTemplate("yyyy")
      return f.string(from: start)
    }
  }

  // MARK: - Body

  var body: some View {
    NavigationStack {
      ZStack(alignment: .bottomTrailing) {
        ThemedBackground(theme: theme)

        if notes.isEmpty {
          emptyState
        } else if !hasResults {
          noMatchesState
        } else {
          timeline
        }

        if !selecting {
          floatingAddButton
        }
      }
      .safeAreaInset(edge: .bottom) {
        if selecting { batchActionBar }
      }
      .navigationTitle(L("Notes"))
      .searchable(text: $query, prompt: L("Search notes"))
      .toolbar { toolbarContent }
      .sheet(item: $editorNote) { note in
        NavigationStack { NoteEditorView(note: note) }
      }
      .sheet(isPresented: $creatingNote) {
        NavigationStack { NoteEditorView(note: nil) }
      }
      .sheet(isPresented: $showBatchDatePicker) { batchDateSheet }
      .tint(theme.accent)
    }
  }

  // MARK: - Toolbar

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    if !notes.isEmpty {
      ToolbarItem(placement: .topBarLeading) {
        if selecting {
          Button(allSelected ? L("Deselect all") : L("Select all")) {
            toggleSelectAll()
          }
          .font(.dl(.subheadline, weight: .semibold))
          .accessibilityLabel(allSelected ? L("Deselect all") : L("Select all"))
        } else {
          filterMenu
        }
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          withAnimation(DLAnim.standard) {
            if selecting {
              editMode = .inactive
              selection.removeAll()
            } else {
              editMode = .active
            }
          }
          Haptics.selection()
        } label: {
          Text(selecting ? L("Done") : L("Select"))
            .font(.dl(.subheadline, weight: .semibold))
        }
        .accessibilityLabel(selecting ? L("Done selecting") : L("Select notes"))
      }
    }
  }

  private var allSelected: Bool {
    !visibleIDs.isEmpty && selection.count >= visibleIDs.count
  }

  private var filterMenu: some View {
    Menu {
      Picker(L("Filter"), selection: $filter) {
        Label(L("All notes"), systemImage: "tray.full").tag(NoteFilter.all)
        Label(L("Pinned"), systemImage: "pin").tag(NoteFilter.pinned)
        Label(L("Bookmarked"), systemImage: "bookmark").tag(NoteFilter.bookmarked)
        Label(L("With attachments"), systemImage: "paperclip").tag(NoteFilter.media)
      }
      Divider()
      Picker(L("Mood"), selection: $moodFilter) {
        Text(L("Any mood")).tag(Mood?.none)
        ForEach(Mood.allCases) { mood in
          Text("\(mood.emoji)  \(L(mood.label))").tag(Mood?.some(mood))
        }
      }
      if isFiltering {
        Divider()
        Button(role: .destructive) {
          filter = .all
          moodFilter = nil
          Haptics.light()
        } label: {
          Label(L("Clear filters"), systemImage: "xmark.circle")
        }
      }
    } label: {
      Image(systemName: isFiltering ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        .font(.system(size: 17, weight: .semibold))
    }
    .accessibilityLabel(L("Filter notes"))
  }

  // MARK: - Timeline list

  private var timeline: some View {
    List(selection: $selection) {
      // Controls — never participate in selection.
      Section {
        VStack(spacing: DLSpace.sm) {
          granularityPicker
          if !folders.isEmpty { folderChips }
        }
        .listRowInsets(EdgeInsets(top: DLSpace.sm, leading: DLSpace.md, bottom: DLSpace.xs, trailing: DLSpace.md))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .selectionDisabled()
      }

      if !pinnedNotes.isEmpty {
        Section {
          ForEach(pinnedNotes) { note in noteRow(note) }
        } header: {
          sectionHeader(label: L("Pinned"), count: pinnedNotes.count, systemImage: "pin.fill", tint: DLColor.xpGold)
        }
      }

      ForEach(sections) { section in
        Section {
          ForEach(section.notes) { note in noteRow(note) }
        } header: {
          sectionHeader(label: section.label, count: section.notes.count)
        }
      }

      if !selecting {
        // Breathing room so the floating button never covers the last row.
        Color.clear
          .frame(height: 76)
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
          .selectionDisabled()
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .textCase(nil)
    .environment(\.editMode, $editMode)
    .scrollDismissesKeyboard(.immediately)
    .animation(reduceMotion ? nil : DLAnim.standard, value: selection)
  }

  // MARK: - Granularity picker

  private var granularityPicker: some View {
    HStack(spacing: 4) {
      ForEach(Granularity.allCases) { item in
        let isSelected = granularity == item
        Button {
          withAnimation(DLAnim.standard) { granularity = item }
          Haptics.selection()
        } label: {
          Text(item.label)
            .font(.dl(.subheadline, weight: .semibold))
            .foregroundStyle(isSelected ? Color.white : DLColor.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
              if isSelected {
                Capsule().fill(theme.accent)
              }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
      }
    }
    .padding(4)
    .background(DLColor.surfaceElevated, in: Capsule())
    .overlay(Capsule().strokeBorder(DLColor.separator.opacity(0.6), lineWidth: 1))
    .highPriorityGesture(
      DragGesture(minimumDistance: 24)
        .onEnded { value in
          guard abs(value.translation.width) > abs(value.translation.height),
                abs(value.translation.width) > 40 else { return }
          shiftGranularity(by: value.translation.width < 0 ? 1 : -1)
        }
    )
  }

  /// Moves the timeline granularity one step (Week ↔ Month ↔ Year), clamped.
  private func shiftGranularity(by delta: Int) {
    let all = Granularity.allCases
    guard let index = all.firstIndex(of: granularity) else { return }
    let next = min(max(index + delta, 0), all.count - 1)
    guard next != index else { return }
    withAnimation(DLAnim.standard) { granularity = all[next] }
    Haptics.selection()
  }

  // MARK: - Folder chips

  private var folderChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: DLSpace.sm) {
        folderChip(label: L("All"), folder: nil, isSelected: folderFilter == nil)
        ForEach(folders, id: \.self) { folder in
          folderChip(label: folder, folder: folder, isSelected: folderFilter == folder)
        }
      }
      .padding(.vertical, 2)
    }
  }

  private func folderChip(label: String, folder: String?, isSelected: Bool) -> some View {
    Button {
      withAnimation(DLAnim.quick) {
        folderFilter = (folderFilter == folder) ? nil : folder
      }
      Haptics.selection()
    } label: {
      HStack(spacing: 4) {
        if folder != nil {
          Image(systemName: "folder.fill").font(.system(size: 11))
        }
        Text(label)
          .font(.dl(.subheadline, weight: .medium))
          .lineLimit(1)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(
        isSelected ? theme.accent.opacity(0.22) : DLColor.surfaceElevated,
        in: Capsule()
      )
      .overlay(
        Capsule().strokeBorder(isSelected ? theme.accent : Color.clear, lineWidth: 1.5)
      )
      .foregroundStyle(isSelected ? theme.accent : DLColor.textSecondary)
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  // MARK: - Timeline section header

  private func sectionHeader(
    label: String,
    count: Int,
    systemImage: String? = nil,
    tint: Color? = nil
  ) -> some View {
    HStack(spacing: DLSpace.sm) {
      if let systemImage {
        Image(systemName: systemImage)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(tint ?? DLColor.textSecondary)
      }
      Text(label)
        .font(.dl(.subheadline, weight: .semibold))
        .foregroundStyle(DLColor.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)

      Text("\(count)")
        .font(.dl(.caption2, weight: .semibold))
        .foregroundStyle(DLColor.textSecondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(DLColor.surfaceElevated, in: Capsule())

      Rectangle()
        .fill(DLColor.separator.opacity(0.7))
        .frame(height: 1)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Lf("%@, %d notes", label, count))
  }

  // MARK: - Note row

  private func noteRow(_ note: DayNote) -> some View {
    rowCard(note)
      .listRowInsets(EdgeInsets(top: DLSpace.xs, leading: DLSpace.md, bottom: DLSpace.xs, trailing: DLSpace.md))
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
      .tag(note.id)
      .contentShape(Rectangle())
      .onTapGesture {
        if !selecting { editorNote = note }
      }
      .swipeActions(edge: .leading, allowsFullSwipe: true) {
        Button { editorNote = note } label: {
          Label(L("Edit"), systemImage: "pencil")
        }
        .tint(theme.accent)

        Button { togglePin(note) } label: {
          Label(note.pinned ? L("Unpin") : L("Pin"),
                systemImage: note.pinned ? "pin.slash" : "pin")
        }
        .tint(DLColor.xpGold)
      }
      .swipeActions(edge: .trailing, allowsFullSwipe: true) {
        Button(role: .destructive) { delete([note]) } label: {
          Label(L("Delete"), systemImage: "trash")
        }

        Button { toggleBookmark(note) } label: {
          Label(note.bookmarked ? L("Remove bookmark") : L("Bookmark"),
                systemImage: note.bookmarked ? "bookmark.slash" : "bookmark")
        }
        .tint(DLColor.success)
      }
      .contextMenu { contextMenu(note) }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(rowAccessibilityLabel(note))
      .accessibilityAddTraits(selecting && selection.contains(note.id) ? .isSelected : [])
  }

  private func rowCard(_ note: DayNote) -> some View {
    HStack(spacing: 0) {
      RoundedRectangle(cornerRadius: 2, style: .continuous)
        .fill(note.colorHex.map { Color(hexString: $0) } ?? theme.accent.opacity(0.5))
        .frame(width: 4)
        .padding(.trailing, DLSpace.sm)
        .accessibilityHidden(true)

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
            Spacer(minLength: DLSpace.sm)
            if note.bookmarked {
              Image(systemName: "bookmark.fill")
                .font(.system(size: 12))
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)
            }
            if note.pinned {
              Image(systemName: "pin.fill")
                .font(.system(size: 12))
                .foregroundStyle(DLColor.xpGold)
                .accessibilityHidden(true)
            }
          }

          let preview = previewText(note)
          if !preview.isEmpty {
            Text(preview)
              .font(.dl(.subheadline))
              .foregroundStyle(DLColor.textSecondary)
              .lineLimit(2)
              .frame(maxWidth: .infinity, alignment: .leading)
          }

          metadataRow(note)
        }
      }
    }
  }

  private func metadataRow(_ note: DayNote) -> some View {
    HStack(spacing: DLSpace.md) {
      Text(note.createdAt, format: .dateTime.month().day().hour().minute())
        .font(.dl(.caption))
        .foregroundStyle(DLColor.textTertiary)
        .lineLimit(1)

      if note.hasLocation {
        Label {
          Text(note.locationName ?? L("Location")).lineLimit(1)
        } icon: {
          Image(systemName: "mappin.and.ellipse")
        }
        .font(.dl(.caption, weight: .medium))
        .foregroundStyle(DLColor.textTertiary)
        .labelStyle(.titleAndIcon)
      }

      if !note.attachments.isEmpty {
        Label("\(note.attachments.count)", systemImage: "paperclip")
          .font(.dl(.caption, weight: .medium))
          .foregroundStyle(DLColor.textTertiary)
      }

      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// Title text, falling back to a marker-free preview of the body.
  private func displayTitle(_ note: DayNote) -> String {
    let trimmed = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty { return trimmed }
    let preview = previewText(note)
    return preview.isEmpty ? L("New note") : preview
  }

  /// Body preview with inline-formatting markers stripped so the list never
  /// shows raw `**` / `==` syntax.
  private func previewText(_ note: DayNote) -> String {
    MarkdownFormatter.plain(note.text)
  }

  private func rowAccessibilityLabel(_ note: DayNote) -> String {
    var parts: [String] = [displayTitle(note)]
    if let mood = note.mood { parts.append(mood.label) }
    if note.pinned { parts.append(L("Pinned")) }
    if note.bookmarked { parts.append(L("Bookmarked")) }
    if note.hasLocation { parts.append(note.locationName ?? L("Location")) }
    return parts.joined(separator: ", ")
  }

  // MARK: - Context menu

  @ViewBuilder
  private func contextMenu(_ note: DayNote) -> some View {
    Button {
      editorNote = note
    } label: {
      Label(L("Edit"), systemImage: "pencil")
    }
    Button {
      togglePin(note)
    } label: {
      Label(note.pinned ? L("Unpin") : L("Pin"),
            systemImage: note.pinned ? "pin.slash" : "pin")
    }
    Button {
      toggleBookmark(note)
    } label: {
      Label(note.bookmarked ? L("Remove bookmark") : L("Bookmark"),
            systemImage: note.bookmarked ? "bookmark.slash" : "bookmark")
    }
    Divider()
    Button(role: .destructive) {
      delete([note])
    } label: {
      Label(L("Delete"), systemImage: "trash")
    }
  }

  // MARK: - Empty / no-match states

  private var emptyState: some View {
    ContentUnavailableView {
      VStack(spacing: DLSpace.md) {
        EmptyGlyph(systemImage: "note.text", size: 120, tint: theme.accent)
        Text(L("No notes yet"))
          .font(.dl(.title3, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)
      }
    } description: {
      Text(L("Tap + to capture a thought, idea, or memory."))
        .font(.dl(.subheadline))
        .foregroundStyle(DLColor.textSecondary)
    }
  }

  private var noMatchesState: some View {
    ContentUnavailableView {
      Label(L("No matches"), systemImage: "magnifyingglass")
    } description: {
      Text(L("Try a different search or filter."))
    } actions: {
      if isFiltering || folderFilter != nil || !query.isEmpty {
        Button(L("Clear filters")) {
          withAnimation(DLAnim.standard) {
            filter = .all
            moodFilter = nil
            folderFilter = nil
            query = ""
          }
          Haptics.light()
        }
        .font(.dl(.subheadline, weight: .semibold))
        .tint(theme.accent)
      }
    }
  }

  // MARK: - Floating add button

  private var floatingAddButton: some View {
    Button {
      creatingNote = true
    } label: {
      Image(systemName: "plus")
        .font(.system(size: 24, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: 56, height: 56)
        .background(theme.accentGradient, in: Circle())
        .shadow(color: theme.accent.opacity(0.45), radius: 14, x: 0, y: 8)
    }
    .buttonStyle(.plain)
    .bounceTap()
    .accessibilityLabel(L("New note"))
    .offset(x: fabBase.width + fabDrag.width, y: fabBase.height + fabDrag.height)
    .padding(.trailing, DLSpace.lg)
    .padding(.bottom, DLSpace.lg)
    .gesture(
      DragGesture()
        .onChanged { value in fabDrag = value.translation }
        .onEnded { value in
          fabBase.width += value.translation.width
          fabBase.height += value.translation.height
          fabDrag = .zero
          Haptics.soft()
        }
    )
    .animation(reduceMotion ? nil : DLAnim.standard, value: fabBase)
  }

  // MARK: - Batch action bar

  private var batchActionBar: some View {
    HStack(spacing: DLSpace.lg) {
      batchButton(title: L("Pin"), systemImage: "pin.fill", action: batchPin)
      batchButton(title: L("Bookmark"), systemImage: "bookmark.fill", action: batchBookmark)
      batchButton(title: L("Date"), systemImage: "calendar") {
        batchDate = Date()
        showBatchDatePicker = true
      }
      batchButton(title: L("Delete"), systemImage: "trash", role: .destructive) {
        delete(selectedNotes())
        withAnimation(DLAnim.standard) {
          selection.removeAll()
          editMode = .inactive
        }
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, DLSpace.sm)
    .padding(.horizontal, DLSpace.md)
    .background(.ultraThinMaterial)
    .overlay(alignment: .top) {
      Rectangle().fill(DLColor.separator.opacity(0.6)).frame(height: 1)
    }
    .disabled(selection.isEmpty)
    .opacity(selection.isEmpty ? 0.5 : 1)
  }

  private func batchButton(
    title: String,
    systemImage: String,
    role: ButtonRole? = nil,
    action: @escaping () -> Void
  ) -> some View {
    Button(role: role) {
      action()
    } label: {
      VStack(spacing: 4) {
        Image(systemName: systemImage)
          .font(.system(size: 18, weight: .semibold))
        Text(title)
          .font(.dl(.caption2, weight: .medium))
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      .frame(maxWidth: .infinity)
      .foregroundStyle(role == .destructive ? DLColor.streakEnd : theme.accent)
    }
    .buttonStyle(.plain)
  }

  private var batchDateSheet: some View {
    NavigationStack {
      VStack(spacing: DLSpace.lg) {
        DatePicker(
          L("Created"),
          selection: $batchDate,
          displayedComponents: [.date, .hourAndMinute]
        )
        .datePickerStyle(.graphical)
        .tint(theme.accent)
        .padding(DLSpace.md)

        Spacer()
      }
      .padding(.top, DLSpace.md)
      .background(ThemedBackground(theme: theme))
      .navigationTitle(Lf("Change date · %d", selection.count))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(L("Cancel")) { showBatchDatePicker = false }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button(L("Apply")) {
            batchChangeDate(to: batchDate)
            showBatchDatePicker = false
          }
          .fontWeight(.semibold)
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  // MARK: - Selection helpers

  private func toggleSelectAll() {
    withAnimation(DLAnim.standard) {
      if allSelected {
        selection.removeAll()
      } else {
        selection = Set(visibleIDs)
      }
    }
    Haptics.selection()
  }

  private func selectedNotes() -> [DayNote] {
    notes.filter { selection.contains($0.id) }
  }

  // MARK: - Single-note actions

  private func togglePin(_ note: DayNote) {
    withAnimation(DLAnim.standard) { note.pinned.toggle() }
    note.updatedAt = Date()
    try? context.save()
    Haptics.selection()
  }

  private func toggleBookmark(_ note: DayNote) {
    withAnimation(DLAnim.standard) { note.bookmarked.toggle() }
    note.updatedAt = Date()
    try? context.save()
    Haptics.selection()
  }

  // MARK: - Batch actions

  private func batchPin() {
    let targets = selectedNotes()
    let shouldPin = !targets.allSatisfy { $0.pinned }
    withAnimation(DLAnim.standard) {
      for note in targets {
        note.pinned = shouldPin
        note.updatedAt = Date()
      }
    }
    try? context.save()
    Haptics.success()
  }

  private func batchBookmark() {
    let targets = selectedNotes()
    let shouldBookmark = !targets.allSatisfy { $0.bookmarked }
    withAnimation(DLAnim.standard) {
      for note in targets {
        note.bookmarked = shouldBookmark
        note.updatedAt = Date()
      }
    }
    try? context.save()
    Haptics.success()
  }

  private func batchChangeDate(to date: Date) {
    let targets = selectedNotes()
    withAnimation(DLAnim.standard) {
      for note in targets {
        note.createdAt = date
        note.updatedAt = Date()
      }
    }
    try? context.save()
    Haptics.success()
  }

  // MARK: - Delete (also removes media binaries from disk)

  private func delete(_ targets: [DayNote]) {
    guard !targets.isEmpty else { return }
    let deletedFolders = Set(targets.compactMap { $0.folder })

    withAnimation(DLAnim.standard) {
      for note in targets {
        for attachment in note.attachments {
          MediaStore.delete(attachment.fileName)
        }
        selection.remove(note.id)
        context.delete(note)
      }
    }
    try? context.save()

    if let active = folderFilter, deletedFolders.contains(active),
       !notes.contains(where: { $0.folder == active }) {
      folderFilter = nil
    }
    Haptics.warning()
  }
}
