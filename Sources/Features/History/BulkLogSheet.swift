import SwiftUI
import SwiftData

/// Bulk back-fill (round 7, item 1). Pick one habit, mood, or energy level, then
/// tick any number of past days on a month calendar to apply it to all of them at
/// once — far faster than opening each day individually in Progress. Habits are
/// marked completed; mood/energy set (or create) the day's Entry value. Future
/// days are disabled, and days that already carry the value show a small dot so
/// you only fill the gaps.
struct BulkLogSheet: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @Query(sort: \Habit.sortIndex) private var allHabits: [Habit]
  @Query private var entries: [Entry]
  @Query private var progressList: [UserProgress]

  /// What we're filling in across the selected days.
  enum Kind: String, CaseIterable, Identifiable {
    case habit, mood, energy
    var id: String { rawValue }
    var label: String {
      switch self {
      case .habit: return L("Habit")
      case .mood: return L("Mood")
      case .energy: return L("Energy")
      }
    }
  }

  @State private var kind: Kind = .habit
  @State private var selectedHabitID: UUID?
  @State private var moodValue = 3
  @State private var energyLevel = 3
  @State private var visibleMonth = Calendar.current.startOfDay(for: Date())
  @State private var selectedDays: Set<Date> = []
  @State private var showMonthPicker = false

  private var calendar: Calendar { Calendar.current }
  private var today: Date { calendar.startOfDay(for: Date()) }

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  /// Active, non-archived habits, in display order.
  private var habits: [Habit] {
    allHabits.filter { $0.deletedAt == nil && !$0.isArchived }
  }

  private var selectedHabit: Habit? {
    habits.first { $0.id == selectedHabitID } ?? habits.first
  }

  /// True only when there's actually something to apply.
  private var canApply: Bool {
    guard !selectedDays.isEmpty else { return false }
    if kind == .habit { return selectedHabit != nil }
    return true
  }

  // MARK: - Body

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        ScrollView {
          VStack(spacing: DLSpace.md) {
            kindPicker
            itemCard
            calendarCard
          }
          .padding(DLSpace.md)
        }
        bottomBar
      }
      .background(ThemedBackground(theme: theme))
      .navigationTitle(L("Bulk log"))
      .navigationBarTitleDisplayMode(.inline)
      .tint(theme.accent)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(L("Cancel")) { Haptics.light(); dismiss() }
            .tint(theme.accent)
        }
      }
      .sheet(isPresented: $showMonthPicker) {
        monthPickerSheet
          .presentationDetents([.height(320), .medium])
          .presentationDragIndicator(.visible)
      }
      .onChange(of: kind) { _, _ in selectedDays.removeAll() }
      .onChange(of: selectedHabitID) { _, _ in selectedDays.removeAll() }
      .onAppear { if selectedHabitID == nil { selectedHabitID = habits.first?.id } }
    }
  }

  // MARK: - Kind picker

  private var kindPicker: some View {
    SlidingSegmentedControl(
      items: Kind.allCases,
      label: { $0.label },
      selection: $kind,
      accent: theme.accent
    )
    .accessibilityLabel(L("What to log"))
  }

  // MARK: - Item selector

  @ViewBuilder
  private var itemCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        switch kind {
        case .habit: habitSelector
        case .mood: moodSelector
        case .energy: energySelector
        }
      }
    }
  }

  @ViewBuilder
  private var habitSelector: some View {
    Text(L("Choose a habit"))
      .font(.dl(.caption, weight: .semibold))
      .foregroundStyle(DLColor.textSecondary)
    if habits.isEmpty {
      Text(L("No habits yet. Add habits from Insights → Manage."))
        .font(.dl(.subheadline))
        .foregroundStyle(DLColor.textTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DLSpace.xs)
    } else {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: DLSpace.sm) {
          ForEach(habits) { habit in
            let isSelected = habit.id == selectedHabit?.id
            Button {
              selectedHabitID = habit.id
              Haptics.selection()
            } label: {
              HStack(spacing: 6) {
                Text(habit.emoji.isEmpty ? "✅" : habit.emoji)
                Text(habit.name)
                  .font(.dl(.subheadline, weight: .semibold))
                  .lineLimit(1)
              }
              .foregroundStyle(isSelected ? .white : DLColor.textPrimary)
              .padding(.horizontal, DLSpace.md)
              .padding(.vertical, DLSpace.sm)
              .background(
                isSelected ? AnyShapeStyle(theme.accent) : AnyShapeStyle(DLColor.surfaceElevated),
                in: Capsule()
              )
              .contentShape(Capsule())
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.vertical, 2)
      }
    }
  }

  @ViewBuilder
  private var moodSelector: some View {
    Text(L("Choose a mood"))
      .font(.dl(.caption, weight: .semibold))
      .foregroundStyle(DLColor.textSecondary)
    HStack(spacing: DLSpace.xs) {
      ForEach(MoodCatalog.shared.options) { mood in
        let isSelected = moodValue == mood.value
        Button {
          moodValue = mood.value
          Haptics.selection()
        } label: {
          VStack(spacing: 2) {
            Text(mood.emoji)
              .font(.system(size: isSelected ? 30 : 24))
            Text(mood.displayName)
              .font(.dl(.caption2))
              .foregroundStyle(isSelected ? mood.color : DLColor.textTertiary)
              .lineLimit(1)
              .minimumScaleFactor(0.6)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
          .background(
            isSelected ? mood.color.opacity(0.16) : Color.clear,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
          )
        }
        .buttonStyle(.plain)
      }
    }
    .animation(reduceMotion ? nil : DLAnim.quick, value: moodValue)
  }

  @ViewBuilder
  private var energySelector: some View {
    Text(L("Choose an energy level"))
      .font(.dl(.caption, weight: .semibold))
      .foregroundStyle(DLColor.textSecondary)
    HStack(spacing: DLSpace.sm) {
      ForEach(1...5, id: \.self) { level in
        Button {
          energyLevel = level
          Haptics.selection()
        } label: {
          Image(systemName: level <= energyLevel ? "bolt.fill" : "bolt")
            .font(.system(size: 24))
            .foregroundStyle(level <= energyLevel ? DLColor.xpGold : DLColor.textTertiary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
      Text("\(energyLevel)/5")
        .font(.dl(.subheadline, weight: .semibold))
        .foregroundStyle(DLColor.textSecondary)
        .monospacedDigit()
    }
  }

  // MARK: - Calendar

  private var calendarCard: some View {
    GlassCard {
      VStack(spacing: DLSpace.md) {
        calendarHeader
        MultiSelectMonthGrid(
          month: visibleMonth,
          accent: theme.accent,
          selection: $selectedDays,
          isLogged: isAlreadyLogged
        )
        .id(calendar.startOfMonth(for: visibleMonth))
        legend
      }
    }
  }

  private var calendarHeader: some View {
    HStack(spacing: DLSpace.sm) {
      chevron("chevron.left", enabled: true, label: L("Previous month")) { shiftMonth(-1) }
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
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(L("Choose month and year"))
      Spacer(minLength: 0)
      chevron("chevron.right", enabled: !isViewingCurrentMonth, label: L("Next month")) { shiftMonth(1) }
    }
  }

  private func chevron(_ systemName: String, enabled: Bool, label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(enabled ? theme.accent : DLColor.textTertiary)
        .frame(width: 40, height: 40)
        .background(DLColor.surfaceElevated.opacity(0.6), in: Circle())
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
    .accessibilityLabel(label)
  }

  private var legend: some View {
    HStack(spacing: DLSpace.md) {
      HStack(spacing: 4) {
        Circle().fill(theme.accent).frame(width: 8, height: 8)
        Text(L("Selected")).font(.dl(.caption2, weight: .medium)).foregroundStyle(DLColor.textTertiary)
      }
      HStack(spacing: 4) {
        Circle().fill(DLColor.success).frame(width: 6, height: 6)
        Text(L("Already logged")).font(.dl(.caption2, weight: .medium)).foregroundStyle(DLColor.textTertiary)
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Bottom bar (Apply)

  private var bottomBar: some View {
    VStack(spacing: DLSpace.sm) {
      if !selectedDays.isEmpty {
        Button {
          withAnimation(reduceMotion ? nil : DLAnim.standard) { selectedDays.removeAll() }
          Haptics.light()
        } label: {
          Text(L("Clear selection"))
            .font(.dl(.subheadline, weight: .semibold))
            .foregroundStyle(theme.accent)
        }
        .buttonStyle(.plain)
      }
      PrimaryButton(applyTitle, systemImage: "checkmark.circle.fill", isEnabled: canApply) {
        apply()
      }
    }
    .padding(DLSpace.md)
    .background(.ultraThinMaterial)
  }

  private var applyTitle: String {
    selectedDays.isEmpty ? L("Select days to fill") : Lf("Apply to %d days", selectedDays.count)
  }

  // MARK: - Already-logged indicator

  /// Whether the chosen item already has a value on `day` (so it reads as a dot).
  private func isAlreadyLogged(_ day: Date) -> Bool {
    let target = calendar.startOfDay(for: day)
    switch kind {
    case .habit:
      return selectedHabit?.isCompleted(on: target) ?? false
    case .mood, .energy:
      return entries.contains { calendar.isDate($0.day, inSameDayAs: target) }
    }
  }

  // MARK: - Month navigation

  private var isViewingCurrentMonth: Bool {
    calendar.isDate(visibleMonth, equalTo: today, toGranularity: .month)
  }

  private func shiftMonth(_ delta: Int) {
    guard let next = calendar.date(byAdding: .month, value: delta, to: visibleMonth) else { return }
    // Never page into a future month.
    if delta > 0, calendar.compare(next, to: today, toGranularity: .month) == .orderedDescending { return }
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

  /// Rebuilds `visibleMonth` from the picker, clamped to never land in a future
  /// month, keeping day-of-month at 1 so jumps never overflow.
  private func setMonthYear(month: Int?, year: Int?) {
    var comps = calendar.dateComponents([.year, .month], from: visibleMonth)
    if let month { comps.month = month }
    if let year { comps.year = year }
    comps.day = 1
    guard let date = calendar.date(from: comps) else { return }
    let capped = min(date, calendar.startOfMonth(for: today))
    withAnimation(reduceMotion ? nil : DLAnim.standard) {
      visibleMonth = calendar.startOfDay(for: capped)
    }
  }

  // MARK: - Apply

  private func apply() {
    let days = selectedDays
    guard !days.isEmpty else { return }
    switch kind {
    case .habit:
      guard let habit = selectedHabit else { return }
      for day in days {
        let target = calendar.startOfDay(for: day)
        if let log = habit.logs.first(where: { calendar.isDate($0.date, inSameDayAs: target) }) {
          log.completed = true
        } else {
          context.insert(HabitLog(date: target, completed: true, habit: habit))
        }
      }
    case .mood:
      for day in days {
        let entry = ensureEntry(for: day)
        entry.moodRaw = moodValue
        entry.updatedAt = Date()
      }
    case .energy:
      for day in days {
        let entry = ensureEntry(for: day)
        entry.energy = energyLevel
        entry.updatedAt = Date()
      }
    }
    try? context.save()
    Haptics.success()
    dismiss()
  }

  /// Finds (or inserts) the Entry for `day`, so a mood/energy can be set on a day
  /// that never had a reflection.
  private func ensureEntry(for day: Date) -> Entry {
    let target = calendar.startOfDay(for: day)
    if let existing = entries.first(where: { calendar.isDate($0.day, inSameDayAs: target) }) {
      return existing
    }
    let new = Entry(day: target)
    context.insert(new)
    return new
  }
}

// MARK: - Multi-select month grid

/// A 7-column month grid where tapping a past/today day toggles it in `selection`.
/// Selected days fill with the accent; days the caller marks via `isLogged` carry a
/// small green dot. Future days are dimmed and not tappable.
private struct MultiSelectMonthGrid: View {
  let month: Date
  let accent: Color
  @Binding var selection: Set<Date>
  let isLogged: (Date) -> Bool

  private var calendar: Calendar {
    var cal = Calendar.current
    cal.firstWeekday = 2 // Monday-first (matches the rest of the app's calendars).
    return cal
  }

  private var today: Date { Calendar.current.startOfDay(for: Date()) }

  private var weekdaySymbols: [String] {
    let symbols = calendar.veryShortStandaloneWeekdaySymbols
    let shift = calendar.firstWeekday - 1
    guard shift > 0, shift < symbols.count else { return symbols }
    return Array(symbols[shift...] + symbols[..<shift])
  }

  private var slots: [Date?] {
    guard
      let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
      let range = calendar.range(of: .day, in: .month, for: monthStart)
    else { return [] }
    let firstWeekday = calendar.component(.weekday, from: monthStart)
    let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7
    var result: [Date?] = Array(repeating: nil, count: leadingBlanks)
    for offset in 0..<range.count {
      if let day = calendar.date(byAdding: .day, value: offset, to: monthStart) {
        result.append(calendar.startOfDay(for: day))
      }
    }
    return result
  }

  private let columns = Array(repeating: GridItem(.flexible(), spacing: DLSpace.xs), count: 7)

  var body: some View {
    VStack(spacing: DLSpace.sm) {
      LazyVGrid(columns: columns, spacing: 0) {
        ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
          Text(symbol)
            .font(.dl(.caption2, weight: .semibold))
            .foregroundStyle(DLColor.textTertiary)
            .frame(maxWidth: .infinity)
        }
      }
      LazyVGrid(columns: columns, spacing: DLSpace.xs) {
        ForEach(Array(slots.enumerated()), id: \.offset) { _, day in
          if let day {
            dayCell(day)
          } else {
            Color.clear.frame(height: 46)
          }
        }
      }
    }
  }

  @ViewBuilder
  private func dayCell(_ day: Date) -> some View {
    let target = calendar.startOfDay(for: day)
    let isFuture = target > today
    let isSelected = selection.contains(target)
    let isToday = calendar.isDate(target, inSameDayAs: today)
    let logged = isLogged(target)
    let dayNumber = calendar.component(.day, from: target)

    Button {
      guard !isFuture else { return }
      if selection.contains(target) { selection.remove(target) } else { selection.insert(target) }
      Haptics.selection()
    } label: {
      VStack(spacing: 3) {
        Text("\(dayNumber)")
          .font(.dl(.subheadline, weight: isSelected || isToday ? .bold : .regular))
          .foregroundStyle(numberColor(isSelected: isSelected, isFuture: isFuture))
          .monospacedDigit()
          .frame(width: 32, height: 32)
          .background {
            if isSelected {
              Circle().fill(accent)
            } else if isToday {
              Circle().strokeBorder(accent, lineWidth: 1.5)
            }
          }
        Circle()
          .fill(logged && !isSelected ? DLColor.success : Color.clear)
          .frame(width: 5, height: 5)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 46)
      .opacity(isFuture ? 0.3 : 1)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(isFuture)
    .accessibilityLabel(Text(target, format: .dateTime.month().day()))
    .accessibilityValue(isSelected ? L("Selected") : (logged ? L("Already logged") : ""))
    .accessibilityAddTraits(isFuture ? [] : .isButton)
  }

  private func numberColor(isSelected: Bool, isFuture: Bool) -> Color {
    if isSelected { return .white }
    if isFuture { return DLColor.textTertiary }
    return DLColor.textPrimary
  }
}

// MARK: - Calendar helper

private extension Calendar {
  /// First day (start of day) of the month containing `date` — gives the month
  /// grid a stable identity so it cross-fades on month changes.
  func startOfMonth(for date: Date) -> Date {
    startOfDay(for: self.date(from: dateComponents([.year, .month], from: date)) ?? date)
  }
}
