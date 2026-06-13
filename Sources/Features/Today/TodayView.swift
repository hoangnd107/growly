import SwiftUI
import SwiftData
import PhotosUI

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
        DLColor.background.ignoresSafeArea()
        if let progress = progressList.first, let entry = todayEntry {
          TodayContent(
            entry: entry,
            progress: progress,
            yesterdayEntry: yesterdayEntry,
            habits: habits.filter { !$0.isArchived },
            allEntries: entries
          )
        } else {
          ProgressView()
        }
      }
      .navigationTitle("Today")
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
  @State private var result: ReviewResult = .none
  @State private var photoItem: PhotosPickerItem?

  var body: some View {
    ScrollView {
      VStack(spacing: DLSpace.lg) {
        LevelHeader(progress: progress, todayXP: entry.xpAwarded)

        Picker("Mode", selection: $mode) {
          Text("Evening").tag(Mode.evening)
          Text("Morning").tag(Mode.morning)
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
    .overlay {
      if showCelebration {
        CompletionCelebration(result: result, isPresented: $showCelebration)
      }
    }
    .onAppear {
      mode = Calendar.current.component(.hour, from: Date()) < 12 ? .morning : .evening
    }
    .onChange(of: photoItem) { _, newItem in
      guard let newItem else { return }
      Task {
        if let data = try? await newItem.loadTransferable(type: Data.self) {
          entry.photo = data
          try? context.save()
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

    photoCard

    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        HStack {
          Text("Completion")
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

    if entry.xpAwarded > 0 {
      Label("Day complete · +\(entry.xpAwarded) XP earned", systemImage: "checkmark.seal.fill")
        .font(.dl(.headline, weight: .semibold))
        .foregroundStyle(DLColor.success)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(DLColor.success.opacity(0.12), in: RoundedRectangle(cornerRadius: DLRadius.small))
    } else {
      PrimaryButton("Complete the day", systemImage: "sparkles", isEnabled: entry.isComplete) {
        saveAndComplete()
      }
    }
  }

  private var photoCard: some View {
    GlassCard {
      HStack {
        if let data = entry.photo, let uiImage = UIImage(data: data) {
          Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12))
          Text("Photo attached")
            .font(.dl(.subheadline))
            .foregroundStyle(DLColor.textSecondary)
          Spacer()
          Button(role: .destructive) {
            entry.photo = nil
            try? context.save()
          } label: {
            Image(systemName: "trash")
          }
        } else {
          PhotosPicker(selection: $photoItem, matching: .images) {
            Label("Attach a photo", systemImage: "photo.badge.plus")
              .font(.dl(.subheadline, weight: .medium))
              .foregroundStyle(Color.accentColor)
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
        Label("Yesterday's adjustment", systemImage: "arrow.triangle.2.circlepath")
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
          Text("No adjustment from yesterday yet. Tonight, set one to carry forward.")
            .font(.dl(.subheadline))
            .foregroundStyle(DLColor.textSecondary)
        }
      }
    }

    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        Label("Today's intention", systemImage: "target")
          .font(.dl(.subheadline, weight: .semibold))
          .foregroundStyle(Color.accentColor)
        TextField("What's the one thing that matters today?", text: $entry.morningIntention, axis: .vertical)
          .lineLimit(1...4)
          .font(.dl(.body))
          .foregroundStyle(DLColor.textPrimary)
      }
    }

    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        Label("Morning prompt", systemImage: "sparkles")
          .font(.dl(.subheadline, weight: .semibold))
          .foregroundStyle(DLColor.xpGold)
        Text(AICoach.morningPrompt())
          .font(.dl(.body))
          .foregroundStyle(DLColor.textPrimary)
      }
    }

    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        Text("Habits")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)
        if habits.isEmpty {
          Text("Add habits in onboarding to track them here.")
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
      HStack(spacing: DLSpace.sm) {
        Text(habit.emoji)
        Text(habit.name)
          .font(.dl(.body))
          .foregroundStyle(DLColor.textPrimary)
        Spacer()
        Text("+\(habit.xpValue)")
          .font(.dl(.caption2, weight: .semibold))
          .foregroundStyle(DLColor.xpGold)
        Image(systemName: done ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 22))
          .foregroundStyle(done ? DLColor.success : DLColor.textTertiary)
      }
      .padding(.vertical, 4)
    }
    .buttonStyle(.plain)
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
