import SwiftUI
import SwiftData

// MARK: - Weekly Life Review (redesign v2, proposal §8.2)
//
// A deterministic, on-device weekly review across the five life pillars
// (Body · Mind · Focus · Money · Purpose), mapped from data Growly already
// collects (sleep, habits, mood, reflections, finance goals, life-area reviews).
// No AI / Foundation Models — every number is computed from a bounded
// Monday-first week window, so past weeks read correctly and nothing leaks.
//
// It reuses `LifeOSPillar` for each pillar's icon + per-type colour, and lists
// the week's life-area reviews with their own per-type coloured icons.

/// One pillar's summary for a single week.
struct WeeklyPillarSummary: Identifiable {
  let pillar: LifeOSPillar
  /// A short, already-formatted metric line (e.g. "7.4h avg sleep · 5 habit check-ins").
  let metric: String
  /// 0...1, used for the bar and for ranking the week's best / weakest pillar.
  let level: Double
  let hasData: Bool
  var id: String { pillar.rawValue }
}

/// A pure, side-effect-free snapshot of one bounded week.
struct WeeklyReview {
  let weekStart: Date
  let weekEnd: Date            // exclusive (weekStart + 7 days)
  let pillars: [WeeklyPillarSummary]
  let activeDays: Int
  let reflections: Int
  let habitCheckIns: Int
  let lifeAreaReviews: [LifeAreaReview]

  var withData: [WeeklyPillarSummary] { pillars.filter(\.hasData) }
  var hasAnyData: Bool { !withData.isEmpty || activeDays > 0 || !lifeAreaReviews.isEmpty }

  /// Strongest pillar this week (highest level among those with data).
  var biggestWin: WeeklyPillarSummary? { withData.max { $0.level < $1.level } }

  /// Weakest pillar — only meaningful once at least two pillars have data, so a
  /// single logged area is never framed as a problem.
  var needsAttention: WeeklyPillarSummary? {
    guard withData.count >= 2 else { return nil }
    return withData.min { $0.level < $1.level }
  }

  static func compute(
    weekStart: Date,
    calendar: Calendar,
    entries: [Entry],
    notes: [DayNote],
    sleeps: [SleepLog],
    habits: [Habit],
    habitLogs: [HabitLog],
    goals: [SmartGoal],
    lifeAreas: [LifeAreaReview],
    hasIdentity: Bool,
    hasManifesto: Bool
  ) -> WeeklyReview {
    let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
    func inWeek(_ d: Date) -> Bool {
      let day = calendar.startOfDay(for: d)
      return day >= weekStart && day < weekEnd
    }

    // Windowed data.
    let winEntries = entries.filter { inWeek($0.day) }
    let liveNotes = notes.filter { $0.deletedAt == nil }
    let winNotes = liveNotes.filter { inWeek($0.createdAt) }
    let winSleeps = sleeps.filter { inWeek($0.date) }
    let activeHabits = habits.filter { $0.deletedAt == nil && !$0.isArchived }
    let activeHabitIDs = Set(activeHabits.map(\.id))
    let winHabitLogs = habitLogs.filter {
      $0.completed && inWeek($0.date) && ($0.habit.map { activeHabitIDs.contains($0.id) } ?? false)
    }
    let winAreas = lifeAreas.filter { inWeek($0.date) }
      .sorted { $0.date > $1.date }

    func mean(_ xs: [Double]) -> Double { xs.isEmpty ? 0 : xs.reduce(0, +) / Double(xs.count) }

    // MARK: Body — sleep + habit check-ins.
    let hasSleep = !winSleeps.isEmpty
    let avgDur = mean(winSleeps.map(\.durationHours))
    let sleepScore = hasSleep
      ? mean(winSleeps.map { 0.6 * Double($0.computedQuality) / 5.0 + 0.4 * max(0, 1 - abs($0.durationHours - 8) / 4) })
      : 0
    let habitCheckIns = winHabitLogs.count
    let hasHabits = !activeHabits.isEmpty
    let habitScore = activeHabits.isEmpty ? 0 : min(1, Double(habitCheckIns) / Double(activeHabits.count * 7))
    let bodyHasData = hasSleep || habitCheckIns > 0
    let bodyLevel: Double = {
      if hasSleep && hasHabits { return 0.6 * sleepScore + 0.4 * habitScore }
      if hasSleep { return sleepScore }
      return habitScore
    }()
    let sleepStr = String(format: "%.1fh", avgDur)
    let bodyMetric: String = {
      if hasSleep && habitCheckIns > 0 { return Lf("%@ avg sleep · %d habit check-ins", sleepStr, habitCheckIns) }
      if hasSleep { return Lf("%@ avg sleep", sleepStr) }
      if habitCheckIns > 0 { return Lf("%d habit check-ins", habitCheckIns) }
      return ""
    }()

    // MARK: Mind — mood + reflection cadence.
    let moods = winEntries.map { Double($0.moodRaw) } + winNotes.compactMap { $0.moodRaw.map(Double.init) }
    let hasMood = !moods.isEmpty
    let avgMood = mean(moods)
    let reflections = winEntries.count
    let mindHasData = hasMood || reflections > 0
    let moodLevel = hasMood ? max(0, min(1, (avgMood - 1) / 4)) : 0
    let reflLevel = min(1, Double(reflections) / 7.0)
    let mindLevel: Double = {
      if hasMood && reflections > 0 { return 0.6 * moodLevel + 0.4 * reflLevel }
      if hasMood { return moodLevel }
      return reflLevel
    }()
    let moodStr = String(format: "%.1f", avgMood)
    let mindMetric: String = {
      if hasMood && reflections > 0 { return Lf("Mood %@/5 · %d reflections", moodStr, reflections) }
      if hasMood { return Lf("Mood %@/5", moodStr) }
      if reflections > 0 { return Lf("%d reflections", reflections) }
      return ""
    }()

    // MARK: Focus — review completion this week.
    let focusTotal = winEntries.count
    let focusDone = winEntries.filter(\.isComplete).count
    let focusHasData = focusTotal > 0
    let focusLevel = focusTotal > 0
      ? 0.6 * Double(focusDone) / Double(focusTotal) + 0.4 * min(1, Double(focusTotal) / 7.0)
      : 0
    let focusMetric = focusTotal > 0 ? Lf("%d of %d reviews completed", focusDone, focusTotal) : ""

    // MARK: Money — finance review this week, else finance-goal progress.
    let financeGoals = goals.filter { $0.deletedAt == nil && ($0.category?.lowercased().contains("financ") ?? false) }
    let financeReview = winAreas.first { $0.area == .finance }
    let moneyHasData = financeReview != nil || !financeGoals.isEmpty
    let moneyLevel: Double = {
      if let financeReview { return Double(financeReview.rating) / 10.0 }
      if financeGoals.isEmpty { return 0 }
      return mean(financeGoals.map { $0.isCompleted ? 1.0 : $0.progress })
    }()
    let moneyMetric: String = {
      if let financeReview { return Lf("Finances rated %d/10 this week", financeReview.rating) }
      if !financeGoals.isEmpty { return Lf("%d finance goals in progress", financeGoals.count) }
      return ""
    }()

    // MARK: Purpose — life-area reviews this week + goals + identity/manifesto.
    let areasReviewed = Set(winAreas.map(\.areaRaw))
    let activeGoals = goals.filter { $0.deletedAt == nil && !$0.isCompleted }
    let hasGoals = !goals.filter { $0.deletedAt == nil }.isEmpty
    let areaLevel = min(1, Double(areasReviewed.count) / Double(LifeArea.allCases.count))
    let goalLevel = activeGoals.isEmpty ? 0 : mean(activeGoals.map(\.progress))
    let identityLevel = (hasIdentity ? 0.6 : 0) + (hasManifesto ? 0.4 : 0)
    let purposeHasData = !areasReviewed.isEmpty || hasGoals || hasIdentity || hasManifesto
    let purposeLevel = 0.5 * areaLevel + 0.3 * goalLevel + 0.2 * identityLevel
    let purposeMetric: String = {
      if !areasReviewed.isEmpty { return Lf("%d life areas reviewed", areasReviewed.count) }
      if !activeGoals.isEmpty { return Lf("%d active goals", activeGoals.count) }
      return ""
    }()

    // Active days = any day this week with a reflection or a note.
    let activeDates = Set(winEntries.map { calendar.startOfDay(for: $0.day) })
      .union(Set(winNotes.map { calendar.startOfDay(for: $0.createdAt) }))

    let pillars: [WeeklyPillarSummary] = [
      WeeklyPillarSummary(pillar: .body, metric: bodyMetric, level: bodyLevel, hasData: bodyHasData),
      WeeklyPillarSummary(pillar: .mind, metric: mindMetric, level: mindLevel, hasData: mindHasData),
      WeeklyPillarSummary(pillar: .focus, metric: focusMetric, level: focusLevel, hasData: focusHasData),
      WeeklyPillarSummary(pillar: .money, metric: moneyMetric, level: moneyLevel, hasData: moneyHasData),
      WeeklyPillarSummary(pillar: .purpose, metric: purposeMetric, level: purposeLevel, hasData: purposeHasData),
    ]

    return WeeklyReview(
      weekStart: weekStart,
      weekEnd: weekEnd,
      pillars: pillars,
      activeDays: activeDates.count,
      reflections: reflections,
      habitCheckIns: habitCheckIns,
      lifeAreaReviews: winAreas
    )
  }
}

// MARK: - View

/// The Weekly Life Review report: step through weeks, see each pillar's week at
/// a glance, the biggest win / what needs attention, the week's life-area
/// reviews, and a deterministic note to your future self. Pushed from Insights.
struct WeeklyLifeReviewView: View {
  @Query private var entries: [Entry]
  @Query private var notes: [DayNote]
  @Query private var habits: [Habit]
  @Query private var habitLogs: [HabitLog]
  @Query private var sleeps: [SleepLog]
  @Query private var goals: [SmartGoal]
  @Query private var lifeAreas: [LifeAreaReview]
  @Query private var identities: [Identity]
  @Query private var manifestos: [PersonalManifesto]

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// 0 = current week, -1 = last week, etc. Never positive (no future weeks).
  @State private var weekOffset = 0

  /// Tapping the week label opens a date picker to jump straight to any past week.
  @State private var showWeekPicker = false
  @State private var pickerDate = Date()

  private let calendar: Calendar = {
    var cal = Calendar.current
    cal.firstWeekday = 2 // Monday-first weeks
    return cal
  }()

  private var currentWeekStart: Date {
    calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? calendar.startOfDay(for: Date())
  }

  private var weekStart: Date {
    calendar.date(byAdding: .weekOfYear, value: weekOffset, to: currentWeekStart) ?? currentWeekStart
  }

  private var review: WeeklyReview {
    WeeklyReview.compute(
      weekStart: weekStart,
      calendar: calendar,
      entries: entries,
      notes: notes,
      sleeps: sleeps,
      habits: habits,
      habitLogs: habitLogs,
      goals: goals,
      lifeAreas: lifeAreas,
      hasIdentity: identities.first?.hasContent ?? false,
      hasManifesto: manifestos.first?.hasContent ?? false
    )
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DLSpace.lg) {
        EditorialHeader(L("Your week"), L("Weekly Life Review"))
        weekStepper

        let r = review
        if !r.hasAnyData {
          emptyCard
        } else {
          glanceCard(r)
          if r.biggestWin != nil { highlightsCard(r) }
          pillarsCard(r)
          lifeAreasCard(r)
          letterCard(r)
        }
      }
      .padding(DLSpace.md)
    }
    .background(ThemedBackground())
    .navigationTitle(L("Weekly Life Review"))
    .navigationBarTitleDisplayMode(.inline)
    .animation(reduceMotion ? nil : DLAnim.standard, value: weekOffset)
  }

  // MARK: Week stepper

  /// "Jun 16 – Jun 22" for the selected week, localized.
  private var weekRangeText: String {
    let locale = LocalizationManager.shared.locale ?? .current
    let f = DateFormatter()
    f.locale = locale
    f.setLocalizedDateFormatFromTemplate("MMMd")
    let last = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
    return "\(f.string(from: weekStart)) – \(f.string(from: last))"
  }

  /// A friendly word for the two most recent weeks; the date range otherwise.
  private var weekLabel: String {
    switch weekOffset {
    case 0: return L("This week")
    case -1: return L("Last week")
    default: return weekRangeText
    }
  }

  private var weekStepper: some View {
    HStack {
      stepButton(systemImage: "chevron.left", disabled: false) { weekOffset -= 1 }
      Spacer()
      // Tapping the label is the "filter": it opens a date picker to choose any
      // past week directly, instead of only stepping one week at a time.
      Button {
        pickerDate = weekStart
        Haptics.selection()
        showWeekPicker = true
      } label: {
        HStack(spacing: DLSpace.xs) {
          VStack(spacing: 1) {
            Text(weekLabel)
              .font(.dl(.headline, weight: .semibold))
              .foregroundStyle(DLColor.textPrimary)
              .contentTransition(.numericText())
            // Show the concrete dates as a subtitle only when the main label is a word.
            if weekOffset == 0 || weekOffset == -1 {
              Text(weekRangeText)
                .font(.dl(.caption2))
                .foregroundStyle(DLColor.textTertiary)
            }
          }
          Image(systemName: "calendar")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(DLColor.accent)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(L("Choose a week"))
      Spacer()
      stepButton(systemImage: "chevron.right", disabled: weekOffset >= 0) { if weekOffset < 0 { weekOffset += 1 } }
    }
    .padding(.horizontal, DLSpace.sm)
    .padding(.vertical, DLSpace.sm)
    .glass(cornerRadius: DLRadius.card, level: .standard)
    .sheet(isPresented: $showWeekPicker) { weekPickerSheet }
  }

  /// A date picker (capped at today) that jumps the report to the week containing
  /// the chosen day. Selecting any date dismisses and updates the report.
  private var weekPickerSheet: some View {
    NavigationStack {
      VStack(spacing: DLSpace.lg) {
        DatePicker(
          L("Jump to week"),
          selection: $pickerDate,
          in: ...Date(),
          displayedComponents: .date
        )
        .datePickerStyle(.graphical)
        .tint(DLColor.accent)
        .onChange(of: pickerDate) { _, newValue in
          selectWeek(containing: newValue)
        }
        Spacer(minLength: 0)
      }
      .padding(DLSpace.md)
      .background(ThemedBackground())
      .navigationTitle(L("Choose a week"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(L("Done")) { showWeekPicker = false }
            .font(.dl(.body, weight: .semibold))
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  /// Maps a chosen day to a non-positive `weekOffset` (the Monday-first week that
  /// contains it), clamped so the report never shows a future week.
  private func selectWeek(containing date: Date) {
    let target = calendar.dateInterval(of: .weekOfYear, for: date)?.start
      ?? calendar.startOfDay(for: date)
    let weeksBack = calendar.dateComponents([.weekOfYear], from: target, to: currentWeekStart).weekOfYear ?? 0
    let newOffset = min(0, -weeksBack)
    if newOffset != weekOffset {
      withAnimation(reduceMotion ? nil : DLAnim.standard) { weekOffset = newOffset }
      Haptics.selection()
    }
  }

  private func stepButton(systemImage: String, disabled: Bool, action: @escaping () -> Void) -> some View {
    Button {
      withAnimation(reduceMotion ? nil : DLAnim.standard) { action() }
      Haptics.selection()
    } label: {
      Image(systemName: systemImage)
        .font(.system(size: 15, weight: .bold))
        .foregroundStyle(disabled ? DLColor.textTertiary.opacity(0.4) : DLColor.accent)
        .frame(width: 40, height: 36)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(disabled)
    .accessibilityLabel(systemImage == "chevron.left" ? L("Previous week") : L("Next week"))
  }

  // MARK: At a glance

  private func glanceCard(_ r: WeeklyReview) -> some View {
    VStack(alignment: .leading, spacing: DLSpace.sm) {
      SectionLabel(L("This week at a glance"))
      CompactStatRow(tiles: [
        StatTileData(value: "\(r.activeDays)/7", label: L("Active days"), tint: DLColor.accent),
        StatTileData(value: "\(r.reflections)", label: L("Reflections"), tint: DLColor.success),
        StatTileData(value: "\(r.habitCheckIns)", label: L("Habit check-ins"), tint: DLColor.xpGold),
      ])
    }
  }

  // MARK: Highlights

  private func highlightsCard(_ r: WeeklyReview) -> some View {
    GlassCard {
      VStack(spacing: DLSpace.md) {
        if let win = r.biggestWin {
          highlightRow(
            title: L("Biggest win"),
            pillar: win,
            systemImage: "trophy.fill",
            tint: DLColor.xpGold
          )
        }
        if let need = r.needsAttention, need.id != r.biggestWin?.id {
          Hairline()
          highlightRow(
            title: L("Needs attention"),
            pillar: need,
            systemImage: "arrow.up.forward.circle.fill",
            tint: DLColor.warning
          )
        }
      }
    }
  }

  private func highlightRow(title: String, pillar: WeeklyPillarSummary, systemImage: String, tint: Color) -> some View {
    HStack(spacing: DLSpace.md) {
      ZStack {
        Circle().fill(tint.opacity(0.16)).frame(width: 40, height: 40)
        Image(systemName: systemImage)
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(tint)
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.dl(.caption2, weight: .bold))
          .tracking(1.0)
          .foregroundStyle(DLColor.textTertiary)
        Text(pillar.pillar.title)
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)
        if !pillar.metric.isEmpty {
          Text(pillar.metric)
            .font(.dl(.caption))
            .foregroundStyle(DLColor.textSecondary)
        }
      }
      Spacer(minLength: 0)
      Image(systemName: pillar.pillar.icon)
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(pillar.pillar.color)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(title): \(pillar.pillar.title). \(pillar.metric)")
  }

  // MARK: Pillars

  private func pillarsCard(_ r: WeeklyReview) -> some View {
    VStack(alignment: .leading, spacing: DLSpace.sm) {
      SectionLabel(L("Pillars this week"))
      GlassCard {
        VStack(spacing: DLSpace.md) {
          ForEach(Array(r.pillars.enumerated()), id: \.element.id) { index, pillar in
            if index > 0 { Hairline() }
            pillarRow(pillar)
          }
        }
      }
    }
  }

  private func pillarRow(_ p: WeeklyPillarSummary) -> some View {
    VStack(alignment: .leading, spacing: DLSpace.xs) {
      HStack(spacing: DLSpace.sm) {
        Image(systemName: p.pillar.icon)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(p.pillar.color)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 1) {
          Text(p.pillar.title)
            .font(.dl(.subheadline, weight: .semibold))
            .foregroundStyle(DLColor.textPrimary)
          Text(p.hasData ? (p.metric.isEmpty ? p.pillar.caption : p.metric) : p.pillar.emptyHint)
            .font(.dl(.caption2))
            .foregroundStyle(DLColor.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: DLSpace.sm)
      }
      if p.hasData {
        GeometryReader { geo in
          ZStack(alignment: .leading) {
            Capsule().fill(DLColor.separator.opacity(0.3))
            Capsule()
              .fill(
                LinearGradient(
                  colors: [p.pillar.color, p.pillar.color.opacity(0.55)],
                  startPoint: .leading,
                  endPoint: .trailing
                )
              )
              .frame(width: max(4, geo.size.width * min(1, max(0, p.level))))
          }
        }
        .frame(height: 8)
      }
    }
    .padding(.vertical, 2)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(p.hasData ? "\(p.pillar.title): \(p.metric)" : "\(p.pillar.title). \(p.pillar.emptyHint)")
  }

  // MARK: Life areas reviewed this week

  private func lifeAreasCard(_ r: WeeklyReview) -> some View {
    VStack(alignment: .leading, spacing: DLSpace.sm) {
      SectionLabel(L("Life areas reviewed"))
      GlassCard {
        if r.lifeAreaReviews.isEmpty {
          Text(L("No life areas reviewed this week."))
            .font(.dl(.subheadline))
            .foregroundStyle(DLColor.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DLSpace.xs)
        } else {
          VStack(spacing: DLSpace.md) {
            ForEach(Array(r.lifeAreaReviews.enumerated()), id: \.element.id) { index, area in
              if index > 0 { Hairline() }
              lifeAreaRow(area)
            }
          }
        }
      }
    }
  }

  private func lifeAreaRow(_ review: LifeAreaReview) -> some View {
    HStack(spacing: DLSpace.md) {
      // Per-type coloured icon (request: each life area a distinct colour).
      ZStack {
        Circle().fill(review.area.color.opacity(0.16)).frame(width: 36, height: 36)
        Image(systemName: review.area.systemIcon)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(review.area.color)
      }
      VStack(alignment: .leading, spacing: 1) {
        Text(L(review.area.title))
          .font(.dl(.subheadline, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)
        Text(review.date, format: .dateTime.weekday(.wide))
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
      }
      Spacer(minLength: DLSpace.sm)
      Text("\(review.rating)/10")
        .font(.dl(.subheadline, weight: .bold))
        .monospacedDigit()
        .foregroundStyle(review.area.color)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(L(review.area.title)): \(review.rating)/10")
  }

  // MARK: Note to your future self

  private func letterCard(_ r: WeeklyReview) -> some View {
    GlassCard(level: .raised) {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        Label(L("A note to your future self"), systemImage: "envelope.open.fill")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(DLColor.accent)
        Text(L("Dear future self,"))
          .font(.serif(.title3, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)
        ForEach(futureSelfLines(r), id: \.self) { line in
          Text(line)
            .font(.dl(.body))
            .foregroundStyle(DLColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Text(L("Small actions repeated beat rare bursts. Keep building — your future self is being shaped one week at a time."))
          .font(.dl(.body))
          .foregroundStyle(DLColor.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func futureSelfLines(_ r: WeeklyReview) -> [String] {
    var lines = [Lf("This week you showed up on %d of 7 days and logged %d reflections.", r.activeDays, r.reflections)]
    if let win = r.biggestWin {
      lines.append(Lf("Your strongest area this week was %@.", win.pillar.title))
    }
    return lines
  }

  // MARK: Empty

  private var emptyCard: some View {
    GlassCard {
      VStack(spacing: DLSpace.md) {
        EmptyGlyph(systemImage: "calendar.badge.clock", size: 96, tint: DLColor.accent)
        Text(L("Nothing logged for this week yet."))
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)
          .multilineTextAlignment(.center)
        Text(L("Log a review, mood, sleep, or habit to see your week come together."))
          .font(.dl(.subheadline))
          .foregroundStyle(DLColor.textSecondary)
          .multilineTextAlignment(.center)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, DLSpace.md)
    }
  }
}
