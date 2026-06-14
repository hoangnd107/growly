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
            habits: habits.filter { !$0.isArchived },
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

  private enum Mode { case evening, morning }
  @State private var mode: Mode = .evening
  @State private var showCelebration = false
  @State private var showHabitManager = false
  @State private var result: ReviewResult = .none

  var body: some View {
    ScrollView {
      VStack(spacing: DLSpace.lg) {
        header

        Picker(L("Today"), selection: $mode) {
          Text(L("Evening")).tag(Mode.evening)
          Text(L("Morning")).tag(Mode.morning)
        }
        .pickerStyle(.segmented)

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
    .overlay {
      if showCelebration {
        CompletionCelebration(result: result, isPresented: $showCelebration)
      }
    }
    .onAppear {
      mode = Calendar.current.component(.hour, from: Date()) < 12 ? .morning : .evening
    }
  }

  // MARK: Header (level + mascot)

  private var header: some View {
    VStack(spacing: DLSpace.md) {
      HStack(alignment: .top, spacing: DLSpace.md) {
        LevelHeader(progress: progress, todayXP: entry.xpAwarded)
        if progress.miraEnabled {
          MiraView(size: 64, quote: AICoach.quote())
            .padding(.top, DLSpace.xs)
            .accessibilityLabel(L("Mira, your companion"))
        }
      }
    }
  }

  // MARK: Evening

  @ViewBuilder
  private var eveningSection: some View {
    ForEach(ReflectionKind.allCases) { kind in
      ReflectionCard(kind: kind, text: bind(for: kind))
    }

    MoodEnergyCard(moodRaw: $entry.moodRaw, energy: $entry.energy)

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
        onDelete: deleteAttachment
      )
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

  private func deleteAttachment(_ attachment: MediaAttachment) {
    MediaStore.delete(attachment.fileName)
    context.delete(attachment)
    try? context.save()
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
