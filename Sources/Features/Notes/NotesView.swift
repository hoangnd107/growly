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
  @State private var moodFilter: Int?
  @State private var sortOrder: NoteSort = .createdDesc

  // Sheets
  @State private var editorNote: DayNote?
  @State private var showTrash = false

  // Multi-select
  @State private var editMode: EditMode = .inactive
  @State private var selection = Set<UUID>()

  // Collapsed timeline sections, keyed by the section's period-start date
  // (`pinnedSectionKey` stands in for the Pinned section).
  @State private var collapsedSections: Set<Date> = []
  private let pinnedSectionKey = Date.distantPast
  @State private var showBatchDatePicker = false
  @State private var batchDate = Date()

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

  // MARK: - Sort

  private enum NoteSort: String, CaseIterable, Identifiable {
    case createdDesc, createdAsc, title, tag
    var id: String { rawValue }

    var label: String {
      switch self {
      case .createdDesc: return L("Newest first")
      case .createdAsc: return L("Oldest first")
      case .title: return L("Title")
      case .tag: return L("Tag")
      }
    }

    var systemImage: String {
      switch self {
      case .createdDesc: return "arrow.down"
      case .createdAsc: return "arrow.up"
      case .title: return "textformat"
      case .tag: return "tag"
      }
    }
  }

  // MARK: - Action colors (consistent + distinct across swipe / batch / badges)

  private enum NoteActionColor {
    static let edit = Color(hex: 0x0A84FF)      // blue
    static let pin = DLColor.xpGold             // gold
    static let bookmark = Color(hex: 0xAF52DE)  // purple
    static let date = Color(hex: 0x30B0C7)      // teal
    static let delete = DLColor.streakEnd       // red
  }

  // MARK: - Derived data

  /// Notes not in the Trash (soft-deleted notes are excluded everywhere).
  private var activeNotes: [DayNote] {
    notes.filter { $0.deletedAt == nil }
  }

  /// Tiles for the stats-forward header (item 8). The note count leads as a
  /// full-width hero with a "+N this week" momentum cue; pinned / bookmarked /
  /// with-media follow as a 2×2 ledger.
  private var notesStatTiles: [StatTileData] {
    let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    let recent = activeNotes.filter { $0.createdAt >= weekAgo }.count
    return [
      StatTileData(
        value: "\(activeNotes.count)",
        label: L("Total notes"),
        sublabel: recent > 0 ? Lf("+%d this week", recent) : nil,
        tint: DLColor.accent
      ),
      StatTileData(value: "\(activeNotes.filter { $0.pinned }.count)", label: L("Pinned"), tint: DLColor.xpGold),
      StatTileData(value: "\(activeNotes.filter { $0.bookmarked }.count)", label: L("Bookmarked")),
      StatTileData(value: "\(activeNotes.filter { !$0.attachments.isEmpty }.count)", label: L("With media")),
    ]
  }

  /// Notes currently in the Trash.
  private var trashedNotes: [DayNote] {
    notes.filter { $0.deletedAt != nil }
  }

  /// Distinct, sorted folder names across active notes (nil folders excluded).
  private var folders: [String] {
    var seen = Set<String>()
    var ordered: [String] = []
    for note in activeNotes {
      if let folder = note.folder?.trimmingCharacters(in: .whitespacesAndNewlines),
         !folder.isEmpty, !seen.contains(folder) {
        seen.insert(folder)
        ordered.append(folder)
      }
    }
    return ordered.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
  }

  /// All active notes after search + folder + filter narrowing, then sorted by the
  /// selected order (pinned still included).
  private var matched: [DayNote] {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let filtered = activeNotes.filter { note in
      if let folderFilter, note.folder != folderFilter { return false }
      switch filter {
      case .all: break
      case .pinned: if !note.pinned { return false }
      case .bookmarked: if !note.bookmarked { return false }
      case .media: if note.attachments.isEmpty { return false }
      }
      if let moodFilter, note.moodRaw != moodFilter { return false }
      guard !q.isEmpty else { return true }
      return note.title.lowercased().contains(q)
        || note.text.lowercased().contains(q)
        || note.tags.contains { $0.lowercased().contains(q) }
        || (note.locationName?.lowercased().contains(q) ?? false)
    }
    return sorted(filtered)
  }

  /// Applies the selected sort order. Title / Tag sorts still group into timeline
  /// sections; the order just controls placement within and the section sequence.
  private func sorted(_ list: [DayNote]) -> [DayNote] {
    switch sortOrder {
    case .createdDesc:
      return list.sorted { $0.createdAt > $1.createdAt }
    case .createdAsc:
      return list.sorted { $0.createdAt < $1.createdAt }
    case .title:
      return list.sorted {
        displayTitle($0).localizedCaseInsensitiveCompare(displayTitle($1)) == .orderedAscending
      }
    case .tag:
      // Empty-tag notes sort last; ties fall back to newest-first.
      let last = "\u{10FFFF}"
      return list.sorted {
        let a = $0.tags.first?.lowercased() ?? last
        let b = $1.tags.first?.lowercased() ?? last
        if a == b { return $0.createdAt > $1.createdAt }
        return a < b
      }
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
      ZStack {
        ThemedBackground(theme: theme)

        if activeNotes.isEmpty {
          emptyState
        } else if !hasResults {
          noMatchesState
        } else {
          timeline
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
      .sheet(isPresented: $showTrash) { TrashView() }
      .sheet(isPresented: $showBatchDatePicker) { batchDateSheet }
      .tint(theme.accent)
    }
  }

  // MARK: - Toolbar

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    if !activeNotes.isEmpty {
      // Left: filter + sort + (when present) trash — grouped, well away from Select.
      ToolbarItem(placement: .topBarLeading) {
        if selecting {
          Button(allSelected ? L("Deselect all") : L("Select all")) {
            toggleSelectAll()
          }
          .font(.dl(.subheadline, weight: .semibold))
          .accessibilityLabel(allSelected ? L("Deselect all") : L("Select all"))
        } else {
          HStack(spacing: DLSpace.md) {
            filterMenu
            sortMenu
            if !trashedNotes.isEmpty { trashButton }
          }
        }
      }
      // Right: Select / Done only.
      ToolbarItem(placement: .topBarTrailing) {
        selectButton
      }
    } else if !trashedNotes.isEmpty {
      // No active notes, but the bin still has restorable notes.
      ToolbarItem(placement: .topBarTrailing) { trashButton }
    }
  }

  private var trashButton: some View {
    Button { showTrash = true } label: {
      Image(systemName: "trash")
        .font(.system(size: 17, weight: .semibold))
    }
    .accessibilityLabel(L("Recently deleted"))
  }

  private var selectButton: some View {
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

  private var sortMenu: some View {
    Menu {
      Picker(L("Sort by"), selection: $sortOrder) {
        ForEach(NoteSort.allCases) { order in
          Label(order.label, systemImage: order.systemImage).tag(order)
        }
      }
    } label: {
      Image(systemName: "arrow.up.arrow.down.circle")
        .font(.system(size: 17, weight: .semibold))
    }
    .accessibilityLabel(L("Sort notes"))
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
        Text(L("Any mood")).tag(Int?.none)
        ForEach(MoodCatalog.shared.options) { mood in
          Text("\(mood.emoji)  \(mood.displayName)").tag(Int?.some(mood.value))
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
      // Stats-forward header: at-a-glance counts for the note collection. Hidden
      // during multi-select to keep the batch UI uncluttered. Word/writing stats
      // deliberately live in Insights' WritingStatsView, not here, to avoid dupes.
      if !selecting {
        Section {
          CompactStatRow(tiles: notesStatTiles)
          .listRowInsets(EdgeInsets(top: DLSpace.md, leading: DLSpace.md, bottom: DLSpace.xs, trailing: DLSpace.md))
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
          .selectionDisabled()
        }
      }

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
          if !collapsedSections.contains(pinnedSectionKey) {
            ForEach(pinnedNotes) { note in noteRow(note) }
          }
        } header: {
          sectionHeader(label: L("Pinned"), count: pinnedNotes.count, sectionKey: pinnedSectionKey, systemImage: "pin.fill", tint: DLColor.xpGold)
        }
      }

      ForEach(sections) { section in
        Section {
          if !collapsedSections.contains(section.id) {
            ForEach(section.notes) { note in noteRow(note) }
          }
        } header: {
          sectionHeader(label: section.label, count: section.notes.count, sectionKey: section.id)
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
    SlidingSegmentedControl(
      items: Granularity.allCases,
      label: { $0.label },
      selection: $granularity,
      accent: theme.accent
    )
    .accessibilityLabel(L("Timeline range"))
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
    sectionKey: Date,
    systemImage: String? = nil,
    tint: Color? = nil
  ) -> some View {
    let collapsed = collapsedSections.contains(sectionKey)
    return Button {
      withAnimation(reduceMotion ? nil : DLAnim.standard) {
        if collapsed {
          collapsedSections.remove(sectionKey)
        } else {
          collapsedSections.insert(sectionKey)
        }
      }
      Haptics.selection()
    } label: {
      HStack(spacing: DLSpace.sm) {
        Image(systemName: "chevron.right")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(DLColor.textTertiary)
          .rotationEffect(.degrees(collapsed ? 0 : 90))

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
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Lf("%@, %d notes", label, count))
    .accessibilityHint(collapsed ? L("Collapsed. Tap to expand.") : L("Expanded. Tap to collapse."))
    .accessibilityAddTraits(.isButton)
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
        // In select mode, tapping anywhere on the row toggles its selection.
        if selecting {
          toggleSelection(note)
        } else {
          editorNote = note
        }
      }
      .swipeActions(edge: .leading, allowsFullSwipe: true) {
        Button { editorNote = note } label: {
          Label(L("Edit"), systemImage: "pencil")
        }
        .tint(NoteActionColor.edit)       // blue — edit

        Button { togglePin(note) } label: {
          Label(note.pinned ? L("Unpin") : L("Pin"),
                systemImage: note.pinned ? "pin.slash" : "pin")
        }
        .tint(NoteActionColor.pin)        // gold — pin
      }
      .swipeActions(edge: .trailing, allowsFullSwipe: true) {
        Button(role: .destructive) { delete([note]) } label: {
          Label(L("Delete"), systemImage: "trash")
        }
        .tint(NoteActionColor.delete)     // red — delete

        Button { toggleBookmark(note) } label: {
          Label(note.bookmarked ? L("Remove bookmark") : L("Bookmark"),
                systemImage: note.bookmarked ? "bookmark.slash" : "bookmark")
        }
        .tint(NoteActionColor.bookmark)   // purple — bookmark
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
            if let option = note.moodOption {
              Text(option.emoji)
            }
            Text(displayTitle(note))
              .font(.dl(.headline, weight: .semibold))
              .foregroundStyle(DLColor.textPrimary)
              .lineLimit(1)
            Spacer(minLength: DLSpace.sm)
            if note.bookmarked {
              Image(systemName: "bookmark.fill")
                .font(.system(size: 12))
                .foregroundStyle(NoteActionColor.bookmark)
                .accessibilityHidden(true)
            }
            if note.pinned {
              Image(systemName: "pin.fill")
                .font(.system(size: 12))
                .foregroundStyle(NoteActionColor.pin)
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
          Text(locationLabel(note)).lineLimit(1)
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

      if note.charCount > 0 {
        Label(Lf("%d chars", note.charCount), systemImage: "textformat.size")
          .font(.dl(.caption, weight: .medium))
          .foregroundStyle(DLColor.textTertiary)
          .labelStyle(.titleAndIcon)
          .monospacedDigit()
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

  /// "Cafe +2" — the primary place plus a count when a note has several.
  private func locationLabel(_ note: DayNote) -> String {
    let base = note.primaryLocationName ?? L("Location")
    let count = note.locations.count
    return count > 1 ? "\(base) +\(count - 1)" : base
  }

  private func rowAccessibilityLabel(_ note: DayNote) -> String {
    var parts: [String] = [displayTitle(note)]
    if let option = note.moodOption { parts.append(option.displayName) }
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

  // MARK: - Batch action bar

  private var batchActionBar: some View {
    HStack(spacing: DLSpace.lg) {
      batchButton(title: L("Pin"), systemImage: "pin.fill", tint: NoteActionColor.pin, action: batchPin)
      batchButton(title: L("Bookmark"), systemImage: "bookmark.fill", tint: NoteActionColor.bookmark, action: batchBookmark)
      batchButton(title: L("Date"), systemImage: "calendar", tint: NoteActionColor.date) {
        batchDate = Date()
        showBatchDatePicker = true
      }
      batchButton(title: L("Delete"), systemImage: "trash", tint: NoteActionColor.delete, role: .destructive) {
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
    tint: Color,
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
      .foregroundStyle(tint)
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

  /// Toggles a single note's membership in the multi-select set (so tapping the
  /// row body selects it, not just the leading checkmark).
  private func toggleSelection(_ note: DayNote) {
    withAnimation(DLAnim.quick) {
      if selection.contains(note.id) {
        selection.remove(note.id)
      } else {
        selection.insert(note.id)
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

  // MARK: - Delete (soft-delete → Trash; media is kept until purged there)

  private func delete(_ targets: [DayNote]) {
    guard !targets.isEmpty else { return }
    let deletedFolders = Set(targets.compactMap { $0.folder })
    let now = Date()

    withAnimation(DLAnim.standard) {
      for note in targets {
        note.deletedAt = now
        note.updatedAt = now
        selection.remove(note.id)
      }
    }
    try? context.save()

    if let active = folderFilter, deletedFolders.contains(active),
       !activeNotes.contains(where: { $0.folder == active }) {
      folderFilter = nil
    }
    Haptics.warning()
  }
}
