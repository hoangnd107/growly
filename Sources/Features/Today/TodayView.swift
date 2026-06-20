import SwiftUI
import SwiftData

struct TodayView: View {
  @Environment(\.modelContext) private var context
  @Query(sort: \Entry.day, order: .reverse) private var entries: [Entry]
  @Query private var progressList: [UserProgress]
  @Query(sort: \Habit.sortIndex) private var habits: [Habit]

  private var today: Date { Calendar.current.startOfDay(for: Date()) }

  private var todayEntry: Entry? {
    entries.first { Calendar.current.isDate($0.day, inSameDayAs: today) }
  }

  private var yesterdayEntry: Entry? {
    guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) else { return nil }
    return entries.first { Calendar.current.isDate($0.day, inSameDayAs: yesterday) }
  }

  var body: some View {
    NavigationStack {
      ZStack {
        if let progress = progressList.first, let entry = todayEntry {
          ThemedBackground(theme: progress.gradientTheme)
          TodayContent(
            entry: entry,
            progress: progress,
            yesterdayEntry: yesterdayEntry,
            habits: habits.filter { !$0.isArchived && $0.deletedAt == nil },
            allEntries: entries
          )
        } else {
          DLColor.background.ignoresSafeArea()
          ProgressView()
        }
      }
      .navigationTitle(L("Today"))
      .navigationBarTitleDisplayMode(.inline)
    }
    .onAppear(perform: ensureTodayEntry)
  }

  private func ensureTodayEntry() {
    guard todayEntry == nil else { return }
    context.insert(Entry(day: today))
    try? context.save()
  }
}

private struct TodayContent: View {
  @Environment(\.modelContext) private var context
  @Bindable var entry: Entry
  @Bindable var progress: UserProgress
  let yesterdayEntry: Entry?
  let habits: [Habit]
  let allEntries: [Entry]

  @Query private var badgeRecords: [BadgeRecord]
  @Query private var allNotes: [DayNote]
  @Query private var identities: [Identity]
  @Query(sort: \SleepLog.date, order: .reverse) private var sleeps: [SleepLog]
  @Query(sort: \SmartGoal.createdAt, order: .reverse) private var goals: [SmartGoal]

  private enum Mode: Hashable { case evening, morning }
  @State private var mode: Mode = .evening
  @State private var showCelebration = false
  @State private var showHabitManager = false
  @State private var showGoals = false
  @State private var showWeeklyReview = false
  @State private var result: ReviewResult = .none

  private var identity: Identity? { identities.first }

  // Sleep quick-entry state (loaded from today's log on appear).
  @State private var bedTime = Date()
  @State private var wakeTime = Date()
  @State private var sleepLoaded = false

  /// Quality is derived from the chosen times (feature 6), never set manually.
  private var quickSleepHours: Double { SleepLog.hours(bedTime: bedTime, wakeTime: wakeTime) }
  private var quickSleepQuality: Int { SleepLog.quality(forHours: quickSleepHours) }

  private var today: Date { Calendar.current.startOfDay(for: Date()) }

  private var todaySleep: SleepLog? {
    sleeps.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
  }

  private var activeGoals: [SmartGoal] {
    goals.filter { !$0.isCompleted }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: DLSpace.lg) {
        header

        if let identity, identity.hasContent {
          NavigationLink {
            IdentityView()
          } label: {
            IdentityReminderCard(identity: identity, accent: Color.accentColor)
          }
          .buttonStyle(.plain)
        }

        modeSelector

        if mode == .evening {
          eveningSection
        } else {
          morningSection
        }
      }
      .padding(DLSpace.md)
    }
    .scrollDismissesKeyboard(.interactively)
    .keyboardDismissButton()
    .sheet(isPresented: $showHabitManager) {
      HabitManagerView()
    }
    .sheet(isPresented: $showGoals) {
      NavigationStack { GoalsView() }
    }
    .sheet(isPresented: $showWeeklyReview) {
      LifeAreaReviewView()
    }
    .overlay {
      if showCelebration {
        CompletionCelebration(result: result, isPresented: $showCelebration)
      }
    }
    .onAppear {
      mode = Calendar.current.component(.hour, from: Date()) < 12 ? .morning : .evening
      loadSleep()
    }
  }

  // MARK: Header (level)

  private var header: some View {
    LevelHeader(progress: progress, todayXP: entry.xpAwarded)
  }

  // MARK: Mode selector (Evening / Morning)

  /// The shared sliding control, so the Evening/Morning toggle animates exactly
  /// like every other selector and the bottom tab bar (feedback item 6).
  private var modeSelector: some View {
    SlidingSegmentedControl(
      items: [Mode.evening, Mode.morning],
      label: { $0 == .evening ? L("Evening") : L("Morning") },
      selection: $mode,
      accent: Color.accentColor
    )
    .accessibilityLabel(L("Time of day"))
  }

  // MARK: Evening

  @ViewBuilder
  private var eveningSection: some View {
    ForEach(ReflectionKind.allCases) { kind in
      ReflectionCard(kind: kind, text: bind(for: kind))
    }

    MoodEnergyCard(moodRaw: $entry.moodRaw, energy: $entry.energy)

    goalsReminderCard

    weeklyReviewCard

    mediaCard

    completionCard

    if entry.xpAwarded > 0 {
      Label(Lf("Day complete · +%d XP earned", entry.xpAwarded), systemImage: "checkmark.seal.fill")
        .font(.dl(.headline, weight: .semibold))
        .foregroundStyle(DLColor.success)
        .frame(maxWidth: .infinity)
        .padding(.vertical, DLSpace.md)
        .background(DLColor.success.opacity(0.12), in: RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous))
    } else {
      PrimaryButton(L("Complete the day"), systemImage: "sparkles", isEnabled: entry.isComplete) {
        saveAndComplete()
      }
      .bounceTap()
    }
  }

  private var completionCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        HStack {
          Text(L("Completion"))
            .font(.dl(.subheadline, weight: .semibold))
            .foregroundStyle(DLColor.textPrimary)
          Spacer()
          Text("\(entry.filledCount)/4")
            .font(.dl(.subheadline, weight: .bold))
            .foregroundStyle(entry.isComplete ? DLColor.success : DLColor.textSecondary)
            .monospacedDigit()
        }
        XPProgressBar(value: Double(entry.filledCount) / 4.0, height: 8)
      }
    }
  }

  private var mediaCard: some View {
    GlassCard {
      MediaPickerField(
        attachments: entry.sortedAttachments,
        onAddImage: { data in addAttachment(data: data, type: .image, ext: "jpg") },
        onAddVideo: { data, ext in addAttachment(data: data, type: .video, ext: ext) },
        onDelete: deleteAttachment,
        onAddAudio: addAudioAttachment,
        showVoiceRecorder: true
      )
    }
  }

  // MARK: Sleep quick entry

  /// Lets the user log last night's bed/wake time (and quality) right from Today,
  /// upserting today's `SleepLog` so it also shows up in Insights.
  private var sleepQuickCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        HStack {
          Label(L("Sleep"), systemImage: "bed.double.fill")
            .font(.dl(.headline, weight: .semibold))
            .foregroundStyle(Color.accentColor)
          Spacer()
          if todaySleep != nil {
            Label(L("Logged"), systemImage: "checkmark.circle.fill")
              .font(.dl(.caption, weight: .semibold))
              .foregroundStyle(DLColor.success)
          }
        }

        DatePicker(L("Bedtime"), selection: $bedTime, displayedComponents: .hourAndMinute)
          .font(.dl(.body))
          .foregroundStyle(DLColor.textPrimary)
        DatePicker(L("Wake time"), selection: $wakeTime, displayedComponents: .hourAndMinute)
          .font(.dl(.body))
          .foregroundStyle(DLColor.textPrimary)

        HStack {
          Text(L("Quality"))
            .font(.dl(.subheadline, weight: .medium))
            .foregroundStyle(DLColor.textPrimary)
          Spacer()
          HStack(spacing: DLSpace.xs) {
            ForEach(1...5, id: \.self) { level in
              Image(systemName: level <= quickSleepQuality ? "star.fill" : "star")
                .font(.system(size: 18))
                .foregroundStyle(DLColor.xpGold)
            }
          }
          Text(SleepLog.qualityLabel(for: quickSleepQuality))
            .font(.dl(.caption, weight: .semibold))
            .foregroundStyle(DLColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Lf("Quality %@", SleepLog.qualityLabel(for: quickSleepQuality)))

        PrimaryButton(
          todaySleep == nil ? L("Save sleep") : L("Update sleep"),
          systemImage: "moon.zzz.fill"
        ) {
          saveSleep()
        }
      }
    }
  }

  // MARK: Weekly review (life areas)

  private var weeklyReviewCard: some View {
    Button {
      Haptics.light()
      showWeeklyReview = true
    } label: {
      GlassCard {
        HStack(spacing: DLSpace.md) {
          ZStack {
            Circle().fill(DLColor.success.opacity(0.18)).frame(width: 44, height: 44)
            Image(systemName: "chart.xyaxis.line")
              .font(.system(size: 18))
              .foregroundStyle(DLColor.success)
          }
          VStack(alignment: .leading, spacing: 2) {
            Text(L("Weekly Review"))
              .font(.dl(.headline, weight: .semibold))
              .foregroundStyle(DLColor.textPrimary)
            Text(L("Rate how your life areas are going"))
              .font(.dl(.caption))
              .foregroundStyle(DLColor.textSecondary)
          }
          Spacer(minLength: 0)
          Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(DLColor.textTertiary)
        }
      }
    }
    .buttonStyle(.plain)
    .bounceTap()
  }

  // MARK: Goals reminder

  /// A compact reminder of active goals with a tap-through to the full Goals view.
  private var goalsReminderCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        HStack {
          Label(L("Goals"), systemImage: "target")
            .font(.dl(.headline, weight: .semibold))
            .foregroundStyle(Color.accentColor)
          Spacer()
          Button(L("View all")) {
            Haptics.light()
            showGoals = true
          }
          .font(.dl(.caption, weight: .semibold))
          .buttonStyle(.plain)
          .foregroundStyle(Color.accentColor)
        }

        if activeGoals.isEmpty {
          Button {
            Haptics.light()
            showGoals = true
          } label: {
            Text(L("No active goals yet. Tap to set one."))
              .font(.dl(.subheadline))
              .foregroundStyle(DLColor.textSecondary)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .buttonStyle(.plain)
        } else {
          ForEach(activeGoals.prefix(3)) { goal in
            VStack(alignment: .leading, spacing: DLSpace.xs) {
              HStack {
                Text(goal.title)
                  .font(.dl(.subheadline, weight: .semibold))
                  .foregroundStyle(DLColor.textPrimary)
                  .lineLimit(1)
                Spacer(minLength: DLSpace.sm)
                Text("\(Int((goal.progress * 100).rounded()))%")
                  .font(.dl(.caption, weight: .semibold))
                  .foregroundStyle(Color.accentColor)
                  .monospacedDigit()
              }
              XPProgressBar(value: goal.progress, height: 6)
            }
          }
        }
      }
    }
  }

  // MARK: Morning

  @ViewBuilder
  private var morningSection: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        Label(L("Yesterday's adjustment"), systemImage: "arrow.triangle.2.circlepath")
          .font(.dl(.subheadline, weight: .semibold))
          .foregroundStyle(ReflectionKind.adjustment.accent)
        if let yesterday = yesterdayEntry, !yesterday.adjustment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Toggle(isOn: bindAdjustmentDone(yesterday)) {
            Text(yesterday.adjustment)
              .font(.dl(.body))
              .foregroundStyle(DLColor.textPrimary)
          }
          .toggleStyle(.switch)
        } else {
          Text(L("No adjustment from yesterday yet. Tonight, set one to carry forward."))
            .font(.dl(.subheadline))
            .foregroundStyle(DLColor.textSecondary)
        }
      }
    }

    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        Label(L("Today's intention"), systemImage: "target")
          .font(.dl(.subheadline, weight: .semibold))
          .foregroundStyle(Color.accentColor)
        TextField(L("What's the one thing that matters today?"), text: $entry.morningIntention, axis: .vertical)
          .lineLimit(1...4)
          .font(.dl(.body))
          .foregroundStyle(DLColor.textPrimary)
      }
    }

    goalsReminderCard

    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        Label(L("Morning prompt"), systemImage: "sparkles")
          .font(.dl(.subheadline, weight: .semibold))
          .foregroundStyle(DLColor.xpGold)
        Text(AICoach.morningPrompt())
          .font(.dl(.body))
          .foregroundStyle(DLColor.textPrimary)
      }
    }

    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        HStack {
          Text(L("Habits"))
            .font(.dl(.headline, weight: .semibold))
            .foregroundStyle(DLColor.textPrimary)
          Spacer()
          Button {
            showHabitManager = true
          } label: {
            Label(L("Manage habits"), systemImage: "slider.horizontal.3")
              .font(.dl(.caption, weight: .semibold))
              .padding(.horizontal, DLSpace.md)
              .padding(.vertical, DLSpace.sm)
              .background(Color.accentColor.opacity(0.16), in: Capsule())
              .foregroundStyle(Color.accentColor)
          }
          .buttonStyle(.plain)
          .bounceTap()
        }

        if habits.isEmpty {
          Text(L("Add habits to track them here."))
            .font(.dl(.subheadline))
            .foregroundStyle(DLColor.textSecondary)
        } else {
          ForEach(habits) { habit in
            habitRow(habit)
          }
        }
      }
    }

    // Sleep is logged in the morning (last night's rest), so it sits at the end.
    sleepQuickCard
  }

  private func habitRow(_ habit: Habit) -> some View {
    let done = habit.isCompleted(on: Date())
    return Button {
      toggleHabit(habit)
    } label: {
      HStack(spacing: DLSpace.md) {
        Text(habit.emoji)
          .font(.system(size: 24))
        Text(habit.name)
          .font(.dl(.body))
          .foregroundStyle(DLColor.textPrimary)
        Spacer()
        Text("+\(habit.xpValue)")
          .font(.dl(.caption2, weight: .semibold))
          .foregroundStyle(DLColor.xpGold)
        Image(systemName: done ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 26))
          .foregroundStyle(done ? DLColor.success : DLColor.textTertiary)
      }
      .padding(.vertical, DLSpace.sm)
    }
    .buttonStyle(.plain)
    .bounceTap()
    .accessibilityLabel(habit.name)
    .accessibilityValue(done ? L("Done") : "")
  }

  // MARK: Bindings & actions

  private func bind(for kind: ReflectionKind) -> Binding<String> {
    Binding(
      get: { entry.text(for: kind) },
      set: { entry.setText($0, for: kind) }
    )
  }

  private func bindAdjustmentDone(_ target: Entry) -> Binding<Bool> {
    Binding(
      get: { target.adjustmentDone },
      set: { target.adjustmentDone = $0; try? context.save() }
    )
  }

  private func addAttachment(data: Data, type: MediaType, ext: String) {
    guard let fileName = MediaStore.save(data, ext: ext) else { return }
    let attachment = MediaAttachment(fileName: fileName, type: type, order: entry.attachments.count)
    attachment.entry = entry
    context.insert(attachment)
    try? context.save()
  }

  /// Attaches a recorded voice memo (already saved to disk by `AudioRecorder`).
  private func addAudioAttachment(_ fileName: String) {
    let attachment = MediaAttachment(fileName: fileName, type: .audio, order: entry.attachments.count)
    attachment.entry = entry
    context.insert(attachment)
    try? context.save()
  }

  private func deleteAttachment(_ attachment: MediaAttachment) {
    MediaStore.delete(attachment.fileName)
    context.delete(attachment)
    try? context.save()
  }

  /// Seeds the sleep pickers from today's log if one exists, else sensible
  /// defaults (11pm → 7am). Runs once per appearance.
  private func loadSleep() {
    guard !sleepLoaded else { return }
    sleepLoaded = true
    if let sleep = todaySleep {
      bedTime = sleep.bedTime
      wakeTime = sleep.wakeTime
    } else {
      let cal = Calendar.current
      bedTime = cal.date(bySettingHour: 23, minute: 0, second: 0, of: Date()) ?? Date()
      wakeTime = cal.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    }
  }

  private func saveSleep() {
    if let sleep = todaySleep {
      sleep.bedTime = bedTime
      sleep.wakeTime = wakeTime
      sleep.refreshQuality()
    } else {
      context.insert(SleepLog(date: today, bedTime: bedTime, wakeTime: wakeTime))
    }
    try? context.save()
    Haptics.success()
  }

  private func toggleHabit(_ habit: Habit) {
    let today = Calendar.current.startOfDay(for: Date())
    if let log = habit.logs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
      log.completed.toggle()
    } else {
      context.insert(HabitLog(date: today, completed: true, habit: habit))
    }
    try? context.save()
    Haptics.selection()
  }

  private func saveAndComplete() {
    try? context.save()
    let completedHabits = habits.filter { $0.isCompleted(on: Date()) }
    let reviewResult = GamificationService.completeReview(
      entry: entry,
      habitsCompleted: completedHabits,
      progress: progress,
      allEntries: allEntries,
      allNotes: allNotes,
      existingBadgeIDs: Set(badgeRecords.map { $0.badgeID }),
      context: context
    )
    try? context.save()
    result = reviewResult
    if reviewResult.xpGained > 0 {
      Haptics.success()
      showCelebration = true
    }
  }
}
