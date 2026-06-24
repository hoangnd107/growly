import SwiftUI
import SwiftData

/// History — a calendar + searchable journal. The calendar dots days that have a
/// reflection and/or notes; tapping any day (or a list row) opens a `DayDetailView`
/// summarizing that day's reflection, notes, completed goals/habits, media, and sleep.
/// Streak and Stats now live on the Insights tab.
struct HistoryView: View {
  @Query(sort: \Entry.day, order: .reverse) private var entries: [Entry]
  @Query private var notes: [DayNote]
  @Query private var progressList: [UserProgress]

  @State private var query = ""
  @State private var tagFilter: String?
  @State private var visibleMonth = Calendar.current.startOfDay(for: Date())
  @State private var selectedDay: DaySelection?
  @State private var showMonthPicker = false
  /// A4: the per-day mood list under the calendar — month-scoped vs. all history.
  @State private var moodListAllMonths = false
  /// A4: collapse the daily-mood list; in all-time mode page it 30 days at a time.
  @State private var moodListExpanded = true
  @State private var moodListVisibleCount = 30
  private let moodListPageSize = 30

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

  /// Day-start -> the three dots that day earns (note / mood / complete-the-day).
  /// Respects the active mood + tag filters so the calendar mirrors the list.
  private var dayMarks: [Date: CalendarDayMark] {
    var map: [Date: CalendarDayMark] = [:]
    for entry in entries where passesFilters(entry) {
      let key = calendar.startOfDay(for: entry.day)
      // Reviews always carry a mood; a full WMLA review also lights the green dot.
      map[key, default: CalendarDayMark()].hasMood = true
      if entry.isComplete { map[key, default: CalendarDayMark()].hasComplete = true }
    }
    for note in activeNotes where notePassesFilters(note) {
      map[note.day, default: CalendarDayMark()].hasNote = true
      if note.moodRaw != nil { map[note.day, default: CalendarDayMark()].hasMood = true }
    }
    return map
  }

  /// Whether a note passes the active tag filter (for calendar dots).
  private func notePassesFilters(_ note: DayNote) -> Bool {
    if let tagFilter, !note.tags.contains(tagFilter) { return false }
    return true
  }

  /// Whether an entry passes the active tag filter (used by both the calendar
  /// dots and the list).
  private func passesFilters(_ entry: Entry) -> Bool {
    if let tagFilter, !entry.tags.contains(tagFilter) { return false }
    return true
  }

  private var isFiltering: Bool {
    tagFilter != nil || !query.isEmpty
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
      .navigationTitle(L("Progress"))
      .searchable(text: $query, prompt: Text(L("Search reflections")))
      .toolbar {
        if !allTags.isEmpty {
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
        Text(L("Nothing here yet"))
          .font(.dl(.title3, weight: .bold))
          .foregroundStyle(DLColor.textPrimary)
      }
    } description: {
      Text(L("Your daily reviews and notes will appear here, on the calendar and in this list."))
        .foregroundStyle(DLColor.textSecondary)
    }
    .padding(DLSpace.lg)
  }

  // MARK: - Main scroll content

  private var content: some View {
    ScrollView {
      LazyVStack(spacing: DLSpace.md) {
        calendarSection
      }
      .padding(DLSpace.md)
      .animation(reduceMotion ? nil : DLAnim.smooth, value: tagFilter)
      .animation(reduceMotion ? nil : DLAnim.smooth, value: query)
    }
    .scrollDismissesKeyboard(.interactively)
  }

  @ViewBuilder
  private var calendarSection: some View {
    calendarCard

    moodDayListCard

    // The reflection list only appears while searching / filtering, so the
    // default Progress view stays just calendar + daily moods (item 1, round 3).
    if isFiltering {
      if filtered.isEmpty {
        noMatchesState
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
  }

  private var noMatchesState: some View {
    ContentUnavailableView {
      Label(L("No matches"), systemImage: "magnifyingglass")
        .font(.dl(.headline, weight: .semibold))
    } description: {
      Text(L("Try a different search or clear filters."))
    } actions: {
      if isFiltering {
        Button(L("Clear filters")) {
          withAnimation(reduceMotion ? nil : DLAnim.standard) {
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

        calendarLegend
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

  /// Explains the three calendar dots: note (blue), mood (orange), complete (green).
  private var calendarLegend: some View {
    HStack(spacing: DLSpace.md) {
      legendItem(color: CalendarDayMark.noteColor, label: L("Note"))
      legendItem(color: CalendarDayMark.moodColor, label: L("Mood"))
      legendItem(color: CalendarDayMark.completeColor, label: L("Reviewed"))
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func legendItem(color: Color, label: String) -> some View {
    HStack(spacing: 4) {
      Circle().fill(color).frame(width: 6, height: 6)
      Text(label)
        .font(.dl(.caption2, weight: .medium))
        .foregroundStyle(DLColor.textTertiary)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(label)
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

  // MARK: - Per-day mood list (A4)

  private struct MoodDayRow: Identifiable {
    let day: Date
    let moodValue: Int      // 0 when the day has a note but no mood
    let hasNote: Bool
    var id: Date { day }
  }

  /// Days (most recent first) that have a mood and/or a note, scoped to the
  /// visible month or all history depending on the toggle.
  private var moodDayRows: [MoodDayRow] {
    var moodByDay: [Date: Int] = [:]
    var noteByDay: [Date: Bool] = [:]
    for entry in entries where passesFilters(entry) {
      moodByDay[calendar.startOfDay(for: entry.day)] = entry.moodRaw
    }
    for note in activeNotes where notePassesFilters(note) {
      noteByDay[note.day] = true
      if let mood = note.moodRaw, moodByDay[note.day] == nil { moodByDay[note.day] = mood }
    }
    var days = Set(moodByDay.keys).union(noteByDay.keys)
    if !moodListAllMonths {
      days = days.filter { calendar.isDate($0, equalTo: visibleMonth, toGranularity: .month) }
    }
    return days.sorted(by: >).map { day in
      MoodDayRow(day: day, moodValue: moodByDay[day] ?? 0, hasNote: noteByDay[day] ?? false)
    }
  }

  /// Rows actually rendered: in all-time mode, capped to `moodListVisibleCount`
  /// (a load-more window — the 30 most recent first); a month always shows whole.
  private var visibleMoodDayRows: [MoodDayRow] {
    moodListAllMonths ? Array(moodDayRows.prefix(moodListVisibleCount)) : moodDayRows
  }

  private var moodDayListCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        HStack(spacing: DLSpace.sm) {
          Button {
            withAnimation(reduceMotion ? nil : DLAnim.standard) { moodListExpanded.toggle() }
            Haptics.selection()
          } label: {
            HStack(spacing: DLSpace.sm) {
              Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DLColor.textTertiary)
                .rotationEffect(.degrees(moodListExpanded ? 90 : 0))
              Label(L("Daily moods"), systemImage: "face.smiling")
                .font(.dl(.headline, weight: .semibold))
                .foregroundStyle(theme.accent)
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityHint(moodListExpanded ? L("Expanded. Tap to collapse.") : L("Collapsed. Tap to expand."))
          Spacer()
          Button {
            withAnimation(reduceMotion ? nil : DLAnim.standard) {
              moodListAllMonths.toggle()
              moodListVisibleCount = moodListPageSize
            }
            Haptics.selection()
          } label: {
            Text(moodListAllMonths ? L("All time") : L("This month"))
              .font(.dl(.caption, weight: .semibold))
              .padding(.horizontal, DLSpace.sm)
              .padding(.vertical, 5)
              .background(theme.accent.opacity(0.14), in: Capsule())
              .foregroundStyle(theme.accent)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(moodListAllMonths ? L("Showing all history. Tap to show this month.") : L("Showing this month. Tap to show all history."))
        }

        if moodListExpanded {
          if moodDayRows.isEmpty {
            Text(L("No moods logged for this period yet."))
              .font(.dl(.caption))
              .foregroundStyle(DLColor.textTertiary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, DLSpace.xs)
          } else {
            ForEach(visibleMoodDayRows) { row in
              Button { open(day: row.day) } label: { moodDayRowView(row) }
                .buttonStyle(.plain)
            }
            if moodListAllMonths, moodDayRows.count > visibleMoodDayRows.count {
              Button {
                withAnimation(reduceMotion ? nil : DLAnim.standard) {
                  moodListVisibleCount += moodListPageSize
                }
                Haptics.selection()
              } label: {
                Text(L("Show more days"))
                  .font(.dl(.caption, weight: .semibold))
                  .foregroundStyle(theme.accent)
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, DLSpace.sm)
                  .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
    }
    .animation(reduceMotion ? nil : DLAnim.standard, value: moodListAllMonths)
    .animation(reduceMotion ? nil : DLAnim.standard, value: moodListExpanded)
  }

  private func moodDayRowView(_ row: MoodDayRow) -> some View {
    let option = row.moodValue > 0 ? MoodCatalog.shared.option(forValue: row.moodValue) : nil
    return HStack(spacing: DLSpace.sm) {
      Text(row.day, format: .dateTime.day().month(.abbreviated))
        .font(.dl(.subheadline, weight: .semibold))
        .foregroundStyle(DLColor.textPrimary)
        .frame(width: 72, alignment: .leading)

      if let option {
        Text(option.emoji).font(.system(size: 20))
        Text(option.displayName)
          .font(.dl(.subheadline))
          .foregroundStyle(option.color)
      } else {
        Text("—").foregroundStyle(DLColor.textTertiary)
      }

      Spacer(minLength: 0)

      if row.hasNote {
        Image(systemName: "note.text")
          .font(.system(size: 13))
          .foregroundStyle(CalendarDayMark.noteColor)
          .accessibilityLabel(L("Has note"))
      }
      Image(systemName: "chevron.right")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(DLColor.textTertiary)
    }
    .padding(.vertical, 4)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
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
