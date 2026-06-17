import SwiftUI
import SwiftData

/// History — a calendar + searchable journal, plus Streak and Stats views (a
/// segmented control switches between them). The calendar dots days that have a
/// reflection and/or notes; tapping any day (or a list row) opens a `DayDetailView`
/// summarizing that day's reflection, notes, completed goals/habits, media, and sleep.
struct HistoryView: View {
  @Query(sort: \Entry.day, order: .reverse) private var entries: [Entry]
  @Query private var notes: [DayNote]
  @Query private var progressList: [UserProgress]

  @State private var query = ""
  @State private var moodFilter: Int?
  @State private var tagFilter: String?
  @State private var visibleMonth = Calendar.current.startOfDay(for: Date())
  @State private var selectedDay: DaySelection?
  @State private var showMonthPicker = false
  @State private var historyMode: HistoryMode = .calendar

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private enum HistoryMode: String, CaseIterable, Identifiable {
    case calendar, streak, stats
    var id: String { rawValue }
    var label: String {
      switch self {
      case .calendar: return L("Calendar")
      case .streak: return L("Streak")
      case .stats: return L("Stats")
      }
    }
  }

  /// Wraps a day for `.sheet(item:)` presentation of `DayDetailView`.
  private struct DaySelection: Identifiable {
    let day: Date
    var id: Date { day }
  }

  private var calendar: Calendar { Calendar.current }

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  /// Notes not in the Trash.
  private var activeNotes: [DayNote] {
    notes.filter { $0.deletedAt == nil }
  }

  /// Day-start -> what that day contains (reflection dot and/or note dot). Respects
  /// the active mood + tag filters so the calendar mirrors the list.
  private var dayMarks: [Date: CalendarDayMark] {
    var map: [Date: CalendarDayMark] = [:]
    for entry in entries where passesFilters(entry) {
      let key = calendar.startOfDay(for: entry.day)
      map[key, default: CalendarDayMark()].entryColor = entry.moodOption.color
    }
    for note in activeNotes where notePassesFilters(note) {
      map[note.day, default: CalendarDayMark()].noteColor = note.moodOption?.color ?? theme.accent
    }
    return map
  }

  /// Whether a note passes the active mood + tag filters (for calendar dots).
  private func notePassesFilters(_ note: DayNote) -> Bool {
    if let moodFilter, note.moodRaw != moodFilter { return false }
    if let tagFilter, !note.tags.contains(tagFilter) { return false }
    return true
  }

  /// Whether an entry passes the active mood + tag filters (used by both the
  /// calendar dots and the list).
  private func passesFilters(_ entry: Entry) -> Bool {
    if let moodFilter, entry.moodRaw != moodFilter { return false }
    if let tagFilter, !entry.tags.contains(tagFilter) { return false }
    return true
  }

  private var isFiltering: Bool {
    moodFilter != nil || tagFilter != nil || !query.isEmpty
  }

  /// Distinct, sorted tags across all entries (for the tag filter menu).
  private var allTags: [String] {
    var seen = Set<String>()
    var ordered: [String] = []
    for entry in entries {
      for tag in entry.tags {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, !seen.contains(trimmed) {
          seen.insert(trimmed)
          ordered.append(trimmed)
        }
      }
    }
    return ordered.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
  }

  /// Entries shown in the list, filtered by search text, mood, and tag.
  private var filtered: [Entry] {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return entries.filter { entry in
      guard passesFilters(entry) else { return false }
      guard !q.isEmpty else { return true }
      return entry.win.lowercased().contains(q)
        || entry.mistake.lowercased().contains(q)
        || entry.lesson.lowercased().contains(q)
        || entry.adjustment.lowercased().contains(q)
        || entry.morningIntention.lowercased().contains(q)
        || entry.tags.contains { $0.lowercased().contains(q) }
    }
  }

  // MARK: - Body

  var body: some View {
    NavigationStack {
      ZStack {
        ThemedBackground(theme: theme)

        if entries.isEmpty && activeNotes.isEmpty {
          emptyState
        } else {
          content
        }
      }
      .navigationTitle(L("History"))
      .searchable(text: $query, prompt: Text(L("Search reflections")))
      .toolbar {
        if !allTags.isEmpty && historyMode == .calendar {
          ToolbarItem(placement: .topBarTrailing) { tagMenu }
        }
      }
      .sheet(item: $selectedDay) { selection in
        DayDetailView(day: selection.day)
          .presentationDetents([.large])
          .presentationDragIndicator(.visible)
      }
      .sheet(isPresented: $showMonthPicker) {
        monthPickerSheet
          .presentationDetents([.height(320), .medium])
          .presentationDragIndicator(.visible)
      }
    }
  }

  private func open(day: Date) {
    Haptics.selection()
    selectedDay = DaySelection(day: calendar.startOfDay(for: day))
  }

  // MARK: - Tag filter menu

  private var tagMenu: some View {
    Menu {
      Picker(L("Tag"), selection: $tagFilter) {
        Text(L("All tags")).tag(String?.none)
        ForEach(allTags, id: \.self) { tag in
          Text("#\(tag)").tag(String?.some(tag))
        }
      }
      if tagFilter != nil {
        Divider()
        Button(role: .destructive) {
          tagFilter = nil
          Haptics.light()
        } label: {
          Label(L("Clear filters"), systemImage: "xmark.circle")
        }
      }
    } label: {
      Image(systemName: tagFilter != nil ? "tag.circle.fill" : "tag.circle")
        .font(.system(size: 17, weight: .semibold))
    }
    .accessibilityLabel(L("Filter by tag"))
  }

  // MARK: - Empty state (no entries at all)

  private var emptyState: some View {
    ContentUnavailableView {
      VStack(spacing: DLSpace.md) {
        EmptyGlyph(systemImage: "book.closed", size: 110, tint: theme.accent)
        Text(L("No entries yet"))
          .font(.dl(.title3, weight: .bold))
          .foregroundStyle(DLColor.textPrimary)
      }
    } description: {
      Text(L("Your daily reflections will appear here, on the calendar and in this list."))
        .foregroundStyle(DLColor.textSecondary)
    }
    .padding(DLSpace.lg)
  }

  // MARK: - Main scroll content

  private var content: some View {
    ScrollView {
      LazyVStack(spacing: DLSpace.md) {
        modePicker
        switch historyMode {
        case .calendar: calendarSection
        case .streak: StreakCard()
        case .stats: StatsCard()
        }
      }
      .padding(DLSpace.md)
      .animation(reduceMotion ? nil : DLAnim.smooth, value: moodFilter)
      .animation(reduceMotion ? nil : DLAnim.smooth, value: tagFilter)
      .animation(reduceMotion ? nil : DLAnim.smooth, value: query)
      .animation(reduceMotion ? nil : DLAnim.smooth, value: historyMode)
    }
    .scrollDismissesKeyboard(.interactively)
  }

  private var modePicker: some View {
    Picker("", selection: $historyMode) {
      ForEach(HistoryMode.allCases) { mode in
        Text(mode.label).tag(mode)
      }
    }
    .pickerStyle(.segmented)
    .accessibilityLabel(L("History view"))
  }

  @ViewBuilder
  private var calendarSection: some View {
    calendarCard

    moodFilterChips

    if filtered.isEmpty {
      if isFiltering {
        noMatchesState
      } else {
        calendarHint
      }
    } else {
      ForEach(filtered) { entry in
        Button {
          open(day: entry.day)
        } label: {
          row(entry)
        }
        .buttonStyle(.plain)
        .bounceTap()
      }
    }
  }

  private var calendarHint: some View {
    Text(L("Tap a highlighted day to see its details."))
      .font(.dl(.caption))
      .foregroundStyle(DLColor.textTertiary)
      .multilineTextAlignment(.center)
      .frame(maxWidth: .infinity)
      .padding(.top, DLSpace.lg)
  }

  private var noMatchesState: some View {
    ContentUnavailableView {
      Label(L("No matches"), systemImage: "magnifyingglass")
        .font(.dl(.headline, weight: .semibold))
    } description: {
      Text(L("Try a different search or clear the mood filter."))
    } actions: {
      if isFiltering {
        Button(L("Clear filters")) {
          withAnimation(reduceMotion ? nil : DLAnim.standard) {
            moodFilter = nil
            tagFilter = nil
            query = ""
          }
          Haptics.light()
        }
        .font(.dl(.subheadline, weight: .semibold))
        .tint(theme.accent)
      }
    }
    .padding(.top, DLSpace.xl)
  }

  // MARK: - Calendar card

  private var calendarCard: some View {
    GlassCard {
      VStack(spacing: DLSpace.md) {
        calendarHeader

        CalendarMonthView(
          month: visibleMonth,
          marks: dayMarks,
          onSelect: { day in open(day: day) }
        )
        .id(calendar.startOfMonth(for: visibleMonth))
        .transition(.opacity)
      }
    }
    .contentShape(Rectangle())
    // Swipe left → next month, swipe right → previous month. The 24pt minimum
    // distance keeps day taps working; the axis check ignores vertical scrolls.
    .gesture(
      DragGesture(minimumDistance: 24)
        .onEnded { value in
          guard abs(value.translation.width) > abs(value.translation.height) else { return }
          shiftMonth(by: value.translation.width < 0 ? 1 : -1)
        }
    )
  }

  private var calendarHeader: some View {
    HStack(spacing: DLSpace.sm) {
      chevronButton(systemName: "chevron.left", label: L("Previous month")) {
        shiftMonth(by: -1)
      }

      Spacer(minLength: 0)

      Button {
        Haptics.selection()
        showMonthPicker = true
      } label: {
        HStack(spacing: DLSpace.xs) {
          Text(visibleMonth, format: .dateTime.month(.wide).year())
            .font(.dl(.headline, weight: .bold))
            .foregroundStyle(DLColor.textPrimary)
          Image(systemName: "chevron.up.chevron.down")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(theme.accent)
        }
        .padding(.horizontal, DLSpace.sm)
        .padding(.vertical, 6)
        .background(theme.accent.opacity(0.12), in: Capsule())
        .contentShape(Capsule())
      }
      .buttonStyle(.plain)
      .bounceTap()
      .accessibilityLabel(L("Choose month and year"))
      .accessibilityValue(Text(visibleMonth, format: .dateTime.month(.wide).year()))

      Spacer(minLength: 0)

      chevronButton(systemName: "chevron.right", label: L("Next month")) {
        shiftMonth(by: 1)
      }
    }
  }

  private func chevronButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(DLColor.textSecondary)
        .frame(width: 44, height: 44)
        .background(DLColor.surfaceElevated.opacity(0.6), in: Circle())
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .bounceTap()
    .accessibilityLabel(label)
  }

  private func shiftMonth(by value: Int) {
    guard let next = calendar.date(byAdding: .month, value: value, to: visibleMonth) else { return }
    withAnimation(reduceMotion ? nil : DLAnim.standard) {
      visibleMonth = calendar.startOfDay(for: next)
    }
    Haptics.selection()
  }

  // MARK: - Month / year picker sheet

  private var pickerYearRange: ClosedRange<Int> {
    let currentYear = calendar.component(.year, from: Date())
    return (currentYear - 5)...currentYear
  }

  private var monthPickerSheet: some View {
    let selMonth = Binding<Int>(
      get: { calendar.component(.month, from: visibleMonth) },
      set: { setMonthYear(month: $0, year: nil) }
    )
    let selYear = Binding<Int>(
      get: { calendar.component(.year, from: visibleMonth) },
      set: { setMonthYear(month: nil, year: $0) }
    )

    return NavigationStack {
      VStack(spacing: 0) {
        HStack(spacing: 0) {
          Picker(L("Month"), selection: selMonth) {
            ForEach(1...12, id: \.self) { m in
              Text(calendar.standaloneMonthSymbols[m - 1]).tag(m)
            }
          }
          .pickerStyle(.wheel)
          .frame(maxWidth: .infinity)

          Picker(L("Year"), selection: selYear) {
            ForEach(Array(pickerYearRange), id: \.self) { y in
              Text(verbatim: String(y)).tag(y)
            }
          }
          .pickerStyle(.wheel)
          .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, DLSpace.md)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(ThemedBackground(theme: theme))
      .navigationTitle(L("Jump to month"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(L("Today")) {
            withAnimation(reduceMotion ? nil : DLAnim.standard) {
              visibleMonth = calendar.startOfDay(for: Date())
            }
            Haptics.light()
          }
          .tint(theme.accent)
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button(L("Done")) { showMonthPicker = false }
            .font(.dl(.body, weight: .semibold))
            .tint(theme.accent)
        }
      }
    }
  }

  /// Rebuilds `visibleMonth` from the picker, keeping the day-of-month at 1 so
  /// month/year jumps never overflow (e.g. Jan 31 -> Feb).
  private func setMonthYear(month: Int?, year: Int?) {
    var comps = calendar.dateComponents([.year, .month], from: visibleMonth)
    if let month { comps.month = month }
    if let year { comps.year = year }
    comps.day = 1
    if let date = calendar.date(from: comps) {
      withAnimation(reduceMotion ? nil : DLAnim.standard) {
        visibleMonth = calendar.startOfDay(for: date)
      }
    }
  }

  // MARK: - Mood filter chips

  private var moodFilterChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: DLSpace.sm) {
        chip(label: L("All"), emoji: nil, color: theme.accent, isSelected: moodFilter == nil) {
          moodFilter = nil
        }
        ForEach(MoodCatalog.shared.options) { mood in
          chip(label: mood.displayName, emoji: mood.emoji, color: mood.color, isSelected: moodFilter == mood.value) {
            moodFilter = (moodFilter == mood.value) ? nil : mood.value
          }
        }
      }
      .padding(.horizontal, 2)
      .padding(.vertical, 2)
    }
    .scrollClipDisabled()
  }

  private func chip(label: String, emoji: String?, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
    Button {
      withAnimation(reduceMotion ? nil : DLAnim.pop) { action() }
      Haptics.selection()
    } label: {
      HStack(spacing: 5) {
        if let emoji { Text(emoji).font(.system(size: 15)) }
        Text(label)
          .font(.dl(.subheadline, weight: .semibold))
      }
      .padding(.horizontal, DLSpace.md)
      .padding(.vertical, DLSpace.sm)
      .foregroundStyle(isSelected ? color : DLColor.textSecondary)
      .background {
        Capsule()
          .fill(isSelected ? color.opacity(0.18) : DLColor.surfaceElevated.opacity(0.5))
      }
      .overlay(
        Capsule().strokeBorder(isSelected ? color : DLColor.separator.opacity(0.5), lineWidth: 1.5)
      )
    }
    .buttonStyle(.plain)
    .bounceTap()
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }

  // MARK: - List row

  private func row(_ entry: Entry) -> some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        HStack(spacing: DLSpace.sm) {
          Text(entry.moodOption.emoji)
            .font(.system(size: 26))
            .frame(width: 38, height: 38)
            .background(entry.moodOption.color.opacity(0.16), in: Circle())

          VStack(alignment: .leading, spacing: 1) {
            Text(entry.day, format: .dateTime.weekday(.wide))
              .font(.dl(.subheadline, weight: .bold))
              .foregroundStyle(DLColor.textPrimary)
            Text(entry.day, format: .dateTime.month().day().year())
              .font(.dl(.caption, weight: .medium))
              .foregroundStyle(DLColor.textTertiary)
          }

          Spacer(minLength: DLSpace.sm)

          if entry.xpAwarded > 0 {
            Label("\(entry.xpAwarded)", systemImage: "bolt.fill")
              .font(.dl(.caption2, weight: .bold))
              .foregroundStyle(DLColor.xpGold)
              .padding(.horizontal, DLSpace.sm)
              .padding(.vertical, 5)
              .background(DLColor.xpGold.opacity(0.14), in: Capsule())
              .accessibilityLabel(Lf("%d XP earned", entry.xpAwarded))
          }
        }

        if !entry.win.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Text(entry.win)
            .font(.dl(.subheadline))
            .foregroundStyle(DLColor.textSecondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        if !entry.tags.isEmpty {
          Text(entry.tags.map { "#\($0)" }.joined(separator: "  "))
            .font(.dl(.caption, weight: .medium))
            .foregroundStyle(theme.accent.opacity(0.9))
            .lineLimit(1)
        }
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityHint(L("Opens this reflection"))
  }
}

// MARK: - Calendar helper

private extension Calendar {
  /// First day (start of day) of the month containing `date`. Used to give the
  /// month grid a stable identity so it cross-fades on month changes.
  func startOfMonth(for date: Date) -> Date {
    startOfDay(for: self.date(from: dateComponents([.year, .month], from: date)) ?? date)
  }
}
