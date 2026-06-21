import SwiftUI
import SwiftData

// MARK: - Life OS pillars

/// The six pillars of the Life OS Score (redesign v2, proposal §8.3), each
/// scored from data Growly already collects. Maxima sum to 1000.
enum LifeOSPillar: String, CaseIterable, Identifiable {
  case body, mind, focus, money, purpose, consistency

  var id: String { rawValue }

  var maxPoints: Double {
    switch self {
    case .body, .mind, .focus: return 200
    case .money, .purpose: return 150
    case .consistency: return 100
    }
  }

  var title: String {
    switch self {
    case .body: return L("Body")
    case .mind: return L("Mind")
    case .focus: return L("Focus")
    case .money: return L("Money")
    case .purpose: return L("Purpose")
    case .consistency: return L("Consistency")
    }
  }

  var caption: String {
    switch self {
    case .body: return L("Sleep & habits")
    case .mind: return L("Mood & reflection")
    case .focus: return L("Intent & follow-through")
    case .money: return L("Financial goals & review")
    case .purpose: return L("Goals, identity & life areas")
    case .consistency: return L("Streaks & active days")
    }
  }

  /// Shown when the pillar has no data yet, to guide the user.
  var emptyHint: String {
    switch self {
    case .body: return L("Log sleep or track a habit to grow this pillar.")
    case .mind: return L("Log your mood and write reviews to grow this pillar.")
    case .focus: return L("Set morning intentions and complete reviews to grow this pillar.")
    case .money: return L("Add a finance goal or rate your finances to grow this pillar.")
    case .purpose: return L("Set goals, an identity, or review your life areas to grow this pillar.")
    case .consistency: return L("Keep a daily streak going to grow this pillar.")
    }
  }

  var icon: String {
    switch self {
    case .body: return "heart.fill"
    case .mind: return "brain.head.profile"
    case .focus: return "scope"
    case .money: return "dollarsign.circle.fill"
    case .purpose: return "flag.fill"
    case .consistency: return "flame.fill"
    }
  }

  var color: Color {
    switch self {
    case .body: return Color(hex: 0xFF3D5A)
    case .mind: return Color(hex: 0xAF8CFF)
    case .focus: return Color(hex: 0x5AC8FA)
    case .money: return DLColor.success
    case .purpose: return DLColor.warning
    case .consistency: return DLColor.xpGold
    }
  }
}

/// One pillar's contribution to the score.
struct LifeOSPillarScore: Identifiable {
  let pillar: LifeOSPillar
  let points: Double
  let hasData: Bool
  var id: String { pillar.rawValue }
  var maxPoints: Double { pillar.maxPoints }
  var fraction: Double { maxPoints > 0 ? min(1, max(0, points / maxPoints)) : 0 }
}

// MARK: - Score model

/// A deterministic snapshot of the user's "life operating system" over a time
/// window. Pure and side-effect free so it is easy to reason about and test.
struct LifeOSScore {
  let pillars: [LifeOSPillarScore]
  static let maxTotal = 1000

  var total: Int { Int(pillars.reduce(0) { $0 + $1.points }.rounded()) }
  var fraction: Double { Double(total) / Double(Self.maxTotal) }

  static func compute(
    range: StatsRange,
    now: Date = Date(),
    calendar: Calendar = .current,
    entries: [Entry],
    notes: [DayNote],
    habits: [Habit],
    habitLogs: [HabitLog],
    sleeps: [SleepLog],
    goals: [SmartGoal],
    lifeAreas: [LifeAreaReview],
    hasIdentity: Bool,
    hasManifesto: Bool,
    progress: UserProgress?
  ) -> LifeOSScore {
    let today = calendar.startOfDay(for: now)
    let start = range.startDate(now: now, calendar: calendar).map { calendar.startOfDay(for: $0) }
    func inWindow(_ d: Date) -> Bool {
      guard let start else { return true }
      return calendar.startOfDay(for: d) >= start
    }

    // Denominator (in days) for rate metrics — rewards sustained activity.
    let nominalDays: Int = {
      switch range {
      case .week: return 7
      case .month: return 30
      case .quarter: return 90
      case .year: return 365
      case .all:
        let earliest = (entries.map(\.day) + notes.map(\.createdAt) + sleeps.map(\.date)).min()
        if let earliest {
          let days = (calendar.dateComponents([.day], from: calendar.startOfDay(for: earliest), to: today).day ?? 0) + 1
          return min(365, max(1, days))
        }
        return 1
      }
    }()

    // Windowed data sets.
    let winEntries = entries.filter { inWindow($0.day) }
    let liveNotes = notes.filter { $0.deletedAt == nil }
    let winNotes = liveNotes.filter { inWindow($0.createdAt) }
    let winSleeps = sleeps.filter { inWindow($0.date) }
    let activeHabits = habits.filter { $0.deletedAt == nil && !$0.isArchived }
    let activeHabitIDs = Set(activeHabits.map(\.id))
    let winCompletedLogs = habitLogs.filter {
      $0.completed && inWindow($0.date) && ($0.habit.map { activeHabitIDs.contains($0.id) } ?? false)
    }

    let entryDays = Set(winEntries.map { calendar.startOfDay(for: $0.day) })

    // MARK: Body — sleep quality/duration + habit completion.
    let hasSleep = !winSleeps.isEmpty
    let sleepScore: Double = hasSleep
      ? winSleeps.map { s in
          let q = Double(s.computedQuality) / 5.0
          let dur = max(0, 1 - abs(s.durationHours - 8) / 4) // 8h ideal; 0 at 4h/12h
          return 0.6 * q + 0.4 * dur
        }.reduce(0, +) / Double(winSleeps.count)
      : 0
    let hasHabits = !activeHabits.isEmpty
    let habitRate: Double = {
      let denom = Double(activeHabits.count * nominalDays)
      return denom > 0 ? min(1, Double(winCompletedLogs.count) / denom) : 0
    }()
    let bodyHasData = hasSleep || hasHabits
    let bodyFrac: Double = {
      if hasSleep && hasHabits { return 0.6 * sleepScore + 0.4 * habitRate }
      if hasSleep { return sleepScore }
      if hasHabits { return habitRate }
      return 0
    }()

    // MARK: Mind — mood + reflection cadence.
    let moods = winEntries.map { Double($0.moodRaw) } + winNotes.compactMap { $0.moodRaw.map(Double.init) }
    let hasMood = !moods.isEmpty
    let moodFrac = hasMood ? min(1, max(0, (moods.reduce(0, +) / Double(moods.count) - 1) / 4)) : 0
    let hasEntries = !winEntries.isEmpty
    let reflectionFrac = min(1, Double(entryDays.count) / Double(nominalDays))
    let mindHasData = hasMood || hasEntries
    let mindFrac: Double = {
      if hasMood && hasEntries { return 0.6 * moodFrac + 0.4 * reflectionFrac }
      if hasMood { return moodFrac }
      if hasEntries { return reflectionFrac }
      return 0
    }()

    // MARK: Focus — intention set, review completeness, adjustment follow-through.
    let focusHasData = !winEntries.isEmpty
    let entryTotal = Double(winEntries.count)
    let completeRate = entryTotal > 0 ? Double(winEntries.filter { $0.isComplete }.count) / entryTotal : 0
    let adjustmentRate = entryTotal > 0 ? Double(winEntries.filter { $0.adjustmentDone }.count) / entryTotal : 0
    let intentionRate = entryTotal > 0
      ? Double(winEntries.filter { !$0.morningIntention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count) / entryTotal
      : 0
    let focusFrac = focusHasData ? (0.5 * completeRate + 0.3 * adjustmentRate + 0.2 * intentionRate) : 0

    // MARK: Money — finance goals + finance life-area rating.
    let financeGoals = goals.filter { $0.deletedAt == nil && ($0.category?.lowercased().contains("financ") ?? false) }
    let hasFinanceGoals = !financeGoals.isEmpty
    let financeGoalFrac = hasFinanceGoals
      ? financeGoals.map { $0.isCompleted ? 1.0 : $0.progress }.reduce(0, +) / Double(financeGoals.count)
      : 0
    let latestFinanceReview = lifeAreas.filter { $0.area == .finance && inWindow($0.date) }.max(by: { $0.date < $1.date })
    let hasFinanceReview = latestFinanceReview != nil
    let financeReviewFrac = latestFinanceReview.map { Double($0.rating) / 10.0 } ?? 0
    let moneyHasData = hasFinanceGoals || hasFinanceReview
    let moneyFrac: Double = {
      if hasFinanceGoals && hasFinanceReview { return 0.5 * financeGoalFrac + 0.5 * financeReviewFrac }
      if hasFinanceGoals { return financeGoalFrac }
      if hasFinanceReview { return financeReviewFrac }
      return 0
    }()

    // MARK: Purpose — goals + identity/manifesto + life-area coverage.
    let activeGoals = goals.filter { $0.deletedAt == nil && !$0.isCompleted }
    let completedGoals = goals.filter { $0.deletedAt == nil && $0.isCompleted }
    let goalCount = activeGoals.count + completedGoals.count
    let hasGoals = goalCount > 0
    let goalProgress = activeGoals.isEmpty ? 0 : activeGoals.map(\.progress).reduce(0, +) / Double(activeGoals.count)
    let goalFrac = hasGoals ? min(1, 0.5 * min(1, Double(goalCount) / 3.0) + 0.5 * goalProgress) : 0
    let identityFrac = (hasIdentity ? 0.6 : 0) + (hasManifesto ? 0.4 : 0)
    let areasReviewed = Set(lifeAreas.filter { inWindow($0.date) }.map(\.areaRaw))
    let lifeAreaFrac = min(1, Double(areasReviewed.count) / Double(LifeArea.allCases.count))
    let purposeHasData = hasGoals || hasIdentity || hasManifesto || !areasReviewed.isEmpty
    let purposeFrac = 0.4 * goalFrac + 0.3 * identityFrac + 0.3 * lifeAreaFrac

    // MARK: Consistency — streaks + active days.
    let current = Double(progress?.currentStreak ?? 0)
    let longest = Double(progress?.longestStreak ?? 0)
    let streakFrac = 0.7 * min(1, current / 30.0) + 0.3 * min(1, longest / 60.0)
    let activeDays = entryDays.union(Set(winNotes.map { calendar.startOfDay(for: $0.createdAt) }))
    let activityFrac = min(1, Double(activeDays.count) / Double(nominalDays))
    let consistencyHasData = (current > 0 || longest > 0) || !activeDays.isEmpty
    let consistencyFrac = 0.6 * streakFrac + 0.4 * activityFrac

    func score(_ pillar: LifeOSPillar, _ frac: Double, _ hasData: Bool) -> LifeOSPillarScore {
      LifeOSPillarScore(pillar: pillar, points: min(1, max(0, frac)) * pillar.maxPoints, hasData: hasData)
    }

    return LifeOSScore(pillars: [
      score(.body, bodyFrac, bodyHasData),
      score(.mind, mindFrac, mindHasData),
      score(.focus, focusFrac, focusHasData),
      score(.money, moneyFrac, moneyHasData),
      score(.purpose, purposeFrac, purposeHasData),
      score(.consistency, consistencyFrac, consistencyHasData),
    ])
  }
}

// MARK: - View

/// The Life OS Score report: a hero ring summing six pillars (0–1000) with a
/// full time filter and a per-pillar breakdown. Self-contained so it can be
/// pushed from the Insights detailed-reports grid.
struct LifeOSScoreView: View {
  @Query private var entries: [Entry]
  @Query private var notes: [DayNote]
  @Query private var habits: [Habit]
  @Query private var habitLogs: [HabitLog]
  @Query private var sleeps: [SleepLog]
  @Query private var goals: [SmartGoal]
  @Query private var lifeAreas: [LifeAreaReview]
  @Query private var identities: [Identity]
  @Query private var manifestos: [PersonalManifesto]
  @Query private var progressList: [UserProgress]

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var range: StatsRange = .month

  private var score: LifeOSScore {
    LifeOSScore.compute(
      range: range,
      entries: entries,
      notes: notes,
      habits: habits,
      habitLogs: habitLogs,
      sleeps: sleeps,
      goals: goals,
      lifeAreas: lifeAreas,
      hasIdentity: identities.first?.hasContent ?? false,
      hasManifesto: manifestos.first?.hasContent ?? false,
      progress: progressList.first
    )
  }

  private var tier: String {
    switch score.total {
    case ..<300: return L("Getting started")
    case ..<500: return L("Building")
    case ..<700: return L("Thriving")
    case ..<850: return L("Flourishing")
    default: return L("Mastery")
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DLSpace.lg) {
        EditorialHeader(L("Your life"), L("Life OS Score"))

        SlidingSegmentedControl(
          items: StatsRange.allCases,
          label: { $0.label },
          selection: $range,
          accent: DLColor.accent
        )

        heroCard
        pillarsCard

        Text(L("A snapshot of how well your life’s core systems are running. It rewards consistency, not perfection — small actions repeated beat rare bursts."))
          .font(.dl(.caption))
          .foregroundStyle(DLColor.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(DLSpace.md)
    }
    .background(ThemedBackground())
    .navigationTitle(L("Life OS Score"))
    .navigationBarTitleDisplayMode(.inline)
    .animation(reduceMotion ? nil : DLAnim.standard, value: range)
  }

  // MARK: Hero ring

  private var heroCard: some View {
    GlassCard(level: .raised) {
      VStack(spacing: DLSpace.md) {
        ring
        Text(tier)
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)
      }
      .frame(maxWidth: .infinity)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Lf("Life OS Score %d out of 1000, %@", score.total, tier))
    }
  }

  private var ring: some View {
    let pillarColors = LifeOSPillar.allCases.map(\.color)
    return ZStack {
      Circle()
        .stroke(DLColor.separator.opacity(0.4), lineWidth: 16)
      Circle()
        .trim(from: 0, to: max(0.001, score.fraction))
        .stroke(
          AngularGradient(colors: pillarColors + [pillarColors.first ?? DLColor.accent], center: .center),
          style: StrokeStyle(lineWidth: 16, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(reduceMotion ? nil : DLAnim.smooth, value: score.fraction)
      VStack(spacing: 2) {
        Text("\(score.total)")
          .font(.system(size: 56, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(DLColor.textPrimary)
          .contentTransition(.numericText())
        Text(L("of 1000"))
          .font(.dl(.subheadline, weight: .medium))
          .foregroundStyle(DLColor.textSecondary)
      }
    }
    .frame(width: 200, height: 200)
    .padding(.top, DLSpace.xs)
  }

  // MARK: Pillars

  private var pillarsCard: some View {
    VStack(alignment: .leading, spacing: DLSpace.sm) {
      SectionLabel(L("Pillars"))
      GlassCard {
        VStack(spacing: DLSpace.md) {
          ForEach(Array(score.pillars.enumerated()), id: \.element.id) { index, pillar in
            if index > 0 { Hairline() }
            pillarRow(pillar)
          }
        }
      }
    }
  }

  private func pillarRow(_ p: LifeOSPillarScore) -> some View {
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
          Text(p.pillar.caption)
            .font(.dl(.caption2))
            .foregroundStyle(DLColor.textTertiary)
            .lineLimit(1)
        }
        Spacer(minLength: DLSpace.sm)
        Text("\(Int(p.points.rounded()))/\(Int(p.maxPoints))")
          .font(.dl(.subheadline, weight: .bold))
          .monospacedDigit()
          .foregroundStyle(p.hasData ? p.pillar.color : DLColor.textTertiary)
          .contentTransition(.numericText())
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
              .frame(width: max(4, geo.size.width * p.fraction))
          }
        }
        .frame(height: 8)
      } else {
        Text(p.pillar.emptyHint)
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(.vertical, 2)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Lf("%@: %d of %d points", p.pillar.title, Int(p.points.rounded()), Int(p.maxPoints)))
  }
}
