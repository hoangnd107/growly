import SwiftUI
import SwiftData

/// The "Me" tab — an inspiring profile hub: level + rank, lifetime stats, a fully
/// customizable streak-freeze console, an animated badge gallery, and navigation
/// to customization, habits, and settings. No-arg by contract; reads everything
/// from SwiftData.
struct ProfileView: View {
  @Query private var progressList: [UserProgress]
  @Query(sort: \Entry.day, order: .reverse) private var entries: [Entry]
  @Query(sort: \BadgeRecord.earnedAt, order: .reverse) private var badgeRecords: [BadgeRecord]

  @Environment(\.modelContext) private var context

  var body: some View {
    NavigationStack {
      ZStack {
        if let progress = progressList.first {
          ProfileContent(
            progress: progress,
            entries: entries,
            badgeRecords: badgeRecords,
            context: context
          )
          .themedBackground(progress.gradientTheme)
        } else {
          DLColor.background.ignoresSafeArea()
          ProgressView()
        }
      }
      .navigationTitle(L("Me"))
    }
  }
}

// MARK: - Content

/// Holds the per-screen editable state (freeze controls). Split out so the freeze
/// UI can mutate the @Bindable model directly and persist on demand.
private struct ProfileContent: View {
  @Bindable var progress: UserProgress
  let entries: [Entry]
  let badgeRecords: [BadgeRecord]
  let context: ModelContext

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  // Freeze console state.
  @State private var freezeDays: Int = 3
  @State private var costPerDay: Int = 50

  // Selected badge for the detail sheet.
  @State private var selectedBadge: Badge?

  private var earnedIDs: Set<String> { Set(badgeRecords.map(\.badgeID)) }

  private var stats: GamificationStats {
    GamificationService.computeStats(
      progress: progress,
      allEntries: entries,
      level: progress.levelInfo.level
    )
  }

  private var startOfToday: Date { Calendar.current.startOfDay(for: Date()) }

  /// Frozen days that are today or in the future (the ones still "active").
  private var upcomingFrozenCount: Int {
    let cal = Calendar.current
    let today = startOfToday
    return progress.streakFreezeDates.filter { cal.startOfDay(for: $0) >= today }.count
  }

  var body: some View {
    ScrollView {
      VStack(spacing: DLSpace.lg) {
        levelHeaderSection
        statsStrip
        badgeGallery
        navigationCards
        streakFreezeCard
      }
      .padding(DLSpace.md)
      .frame(maxWidth: 640)
      .frame(maxWidth: .infinity)
    }
    .scrollDismissesKeyboard(.interactively)
    .dismissKeyboardOnTap()
    .keyboardDismissButton()
    .sheet(item: $selectedBadge) { badge in
      badgeDetailSheet(badge)
    }
  }

  // MARK: 1. Level header + rank

  private var levelHeaderSection: some View {
    let level = progress.levelInfo.level
    let rank = LevelSystem.title(for: level)
    return VStack(spacing: DLSpace.md) {
      LevelHeader(progress: progress)

      GlassCard {
        HStack(alignment: .center, spacing: DLSpace.md) {
          EmptyGlyph(systemImage: "rosette", size: 76, tint: progress.accentColor)

          VStack(alignment: .leading, spacing: DLSpace.xs) {
            Text(L("Your rank"))
              .font(.dl(.caption, weight: .medium))
              .foregroundStyle(DLColor.textSecondary)
              .textCase(.uppercase)
            Text(L(rank))
              .font(.dl(.largeTitle, weight: .bold))
              .foregroundStyle(progress.accentColor)
              .lineLimit(1)
              .minimumScaleFactor(0.6)
            Text(Lf("Level %d", level))
              .font(.dl(.subheadline, weight: .semibold))
              .foregroundStyle(DLColor.textPrimary)
          }
          Spacer(minLength: 0)
        }
      }
    }
  }

  // MARK: 2. Stats strip

  private var statsStrip: some View {
    GlassCard {
      HStack(spacing: 0) {
        statCell(value: "\(progress.totalXP)", label: L("Total XP"), tint: DLColor.xpGold, icon: "bolt.fill")
        statDivider
        statCell(value: "\(progress.currentStreak)", label: L("Streak"), tint: DLColor.streakStart, icon: "flame.fill")
        statDivider
        statCell(value: "\(progress.longestStreak)", label: L("Longest"), tint: DLColor.streakEnd, icon: "trophy.fill")
        statDivider
        statCell(value: "\(Int(progress.growthScore))", label: L("Growth"), tint: DLColor.success, icon: "leaf.fill")
      }
    }
  }

  private func statCell(value: String, label: String, tint: Color, icon: String) -> some View {
    VStack(spacing: DLSpace.xs) {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(tint)
      Text(value)
        .font(.dl(.title2, weight: .bold))
        .foregroundStyle(DLColor.textPrimary)
        .monospacedDigit()
        .contentTransition(.numericText())
        .lineLimit(1)
        .minimumScaleFactor(0.5)
      Text(label)
        .font(.dl(.caption2, weight: .medium))
        .foregroundStyle(DLColor.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(label): \(value)")
  }

  private var statDivider: some View {
    Rectangle()
      .fill(DLColor.separator.opacity(0.6))
      .frame(width: 1, height: 40)
  }

  // MARK: 3. Streak freeze console

  private var streakFreezeCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        HStack(spacing: DLSpace.sm) {
          ZStack {
            Circle().fill(DLColor.streakStart.opacity(0.16)).frame(width: 40, height: 40)
            Image(systemName: "snowflake")
              .font(.system(size: 18, weight: .semibold))
              .foregroundStyle(Color(hex: 0x5AC8FA))
          }
          VStack(alignment: .leading, spacing: 1) {
            Text(L("Streak Freeze"))
              .font(.dl(.headline, weight: .semibold))
              .foregroundStyle(DLColor.textPrimary)
            Text(Lf("%d day streak · %d frozen days ahead", progress.currentStreak, upcomingFrozenCount))
              .font(.dl(.caption))
              .foregroundStyle(DLColor.textSecondary)
              .lineLimit(2)
          }
          Spacer(minLength: 0)
        }

        Divider().overlay(DLColor.separator.opacity(0.5))

        // Adjust streak — type a value or nudge with the stepper.
        HStack {
          Text(L("Adjust streak"))
            .font(.dl(.subheadline, weight: .medium))
            .foregroundStyle(DLColor.textPrimary)
          Spacer()
          numberField($progress.currentStreak, tint: DLColor.streakStart, placeholder: L("Streak"))
          Stepper("", value: $progress.currentStreak, in: 0...3650)
            .labelsHidden()
        }
        .onChange(of: progress.currentStreak) { _, newValue in
          if newValue < 0 { progress.currentStreak = 0 }
          if newValue > progress.longestStreak { progress.longestStreak = newValue }
          save()
        }

        // Days to freeze — type a value or nudge with the stepper.
        HStack {
          Text(L("Freeze days"))
            .font(.dl(.subheadline, weight: .medium))
            .foregroundStyle(DLColor.textPrimary)
          Spacer()
          numberField($freezeDays, tint: DLColor.textPrimary, placeholder: L("Days"))
          Stepper("", value: $freezeDays, in: 1...365)
            .labelsHidden()
        }
        .onChange(of: freezeDays) { _, newValue in
          if newValue < 1 { freezeDays = 1 }
        }

        // Cost per day — freely settable, can be 0 (free), no upper limit.
        VStack(alignment: .leading, spacing: DLSpace.xs) {
          HStack {
            Text(L("XP cost per day"))
              .font(.dl(.subheadline, weight: .medium))
              .foregroundStyle(DLColor.textPrimary)
            Spacer()
            TextField(L("Cost"), value: $costPerDay, format: .number)
              .keyboardType(.numberPad)
              .multilineTextAlignment(.trailing)
              .font(.dl(.subheadline, weight: .bold))
              .foregroundStyle(DLColor.xpGold)
              .frame(width: 72)
              .padding(.vertical, 6)
              .padding(.horizontal, DLSpace.sm)
              .background(
                RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous)
                  .fill(DLColor.separator.opacity(0.35))
              )
              .onChange(of: costPerDay) { _, newValue in
                if newValue < 0 { costPerDay = 0 }
              }
          }
          Stepper(value: $costPerDay, in: 0...100_000, step: 10) {
            Text(Lf("Total: %d XP", max(0, freezeDays * costPerDay)))
              .font(.dl(.caption, weight: .medium))
              .foregroundStyle(DLColor.textSecondary)
              .monospacedDigit()
          }
        }

        PrimaryButton(
          Lf("Freeze %d days", freezeDays),
          systemImage: "snowflake"
        ) {
          freeze()
        }

        Button {
          clearFrozen()
        } label: {
          HStack(spacing: DLSpace.xs) {
            Image(systemName: "trash")
            Text(L("Clear frozen days"))
          }
          .font(.dl(.subheadline, weight: .semibold))
          .foregroundStyle(upcomingFrozenCount > 0 ? DLColor.warning : DLColor.textTertiary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .disabled(upcomingFrozenCount == 0)
      }
    }
  }

  /// Adds the next `freezeDays` calendar days (starting today) to the frozen set,
  /// avoiding duplicates, then deducts `days * costPerDay` from totalXP (clamped >= 0).
  private func freeze() {
    let cal = Calendar.current
    var existing = Set(progress.streakFreezeDates.map { cal.startOfDay(for: $0) })
    var additions: [Date] = []
    for offset in 0..<max(1, freezeDays) {
      guard let day = cal.date(byAdding: .day, value: offset, to: startOfToday) else { continue }
      let normalized = cal.startOfDay(for: day)
      if !existing.contains(normalized) {
        existing.insert(normalized)
        additions.append(normalized)
      }
    }
    progress.streakFreezeDates.append(contentsOf: additions)

    let cost = max(0, freezeDays * max(0, costPerDay))
    progress.totalXP = max(0, progress.totalXP - cost)

    save()
    Haptics.success()
  }

  /// Removes all frozen dates that are today or in the future.
  private func clearFrozen() {
    let cal = Calendar.current
    let today = startOfToday
    progress.streakFreezeDates.removeAll { cal.startOfDay(for: $0) >= today }
    save()
    Haptics.medium()
  }

  // MARK: 4. Badge gallery

  private var badgeGallery: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        HStack {
          Text(L("Badges"))
            .font(.dl(.headline, weight: .semibold))
            .foregroundStyle(DLColor.textPrimary)
          Spacer()
          Text("\(earnedIDs.count)/\(BadgeCatalog.all.count)")
            .font(.dl(.subheadline, weight: .semibold))
            .foregroundStyle(DLColor.textSecondary)
            .monospacedDigit()
        }

        LazyVGrid(
          columns: Array(repeating: GridItem(.flexible(), spacing: DLSpace.md), count: 3),
          spacing: DLSpace.md
        ) {
          ForEach(Array(BadgeCatalog.all.enumerated()), id: \.element.id) { index, badge in
            BadgeCell(
              badge: badge,
              earned: earnedIDs.contains(badge.id),
              progress: BadgeEngine.progress(for: badge.id, stats: stats),
              index: index,
              reduceMotion: reduceMotion
            )
            .onTapGesture { selectedBadge = badge }
          }
        }
      }
    }
  }

  private func badgeDetailSheet(_ badge: Badge) -> some View {
    let earned = earnedIDs.contains(badge.id)
    let prog = BadgeEngine.progress(for: badge.id, stats: stats)
    return VStack(spacing: DLSpace.lg) {
      ZStack {
        Circle().fill(badge.color.opacity(0.18)).frame(width: 96, height: 96)
        Image(systemName: badge.systemIcon)
          .font(.system(size: 40, weight: .semibold))
          .foregroundStyle(earned ? badge.color : DLColor.textTertiary)
      }
      .padding(.top, DLSpace.xl)

      VStack(spacing: DLSpace.sm) {
        Text(L(badge.title))
          .font(.dl(.title2, weight: .bold))
          .foregroundStyle(DLColor.textPrimary)
          .multilineTextAlignment(.center)
        Text(L(badge.subtitle))
          .font(.dl(.body))
          .foregroundStyle(DLColor.textSecondary)
          .multilineTextAlignment(.center)
      }

      if earned {
        Label(L("Earned"), systemImage: "checkmark.seal.fill")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(badge.color)
      } else {
        VStack(spacing: DLSpace.sm) {
          XPProgressBar(value: prog)
            .frame(maxWidth: 220)
          Text(Lf("%d%% complete", Int(prog * 100)))
            .font(.dl(.subheadline, weight: .semibold))
            .foregroundStyle(DLColor.textSecondary)
            .monospacedDigit()
        }
      }

      Spacer()
    }
    .padding(DLSpace.lg)
    .frame(maxWidth: .infinity)
    .themedBackground(progress.gradientTheme)
    .presentationDetents([.medium])
    .presentationDragIndicator(.visible)
  }

  // MARK: 5. Navigation

  private var navigationCards: some View {
    VStack(spacing: DLSpace.md) {
      NavigationLink {
        CustomizationShopView(progress: progress)
      } label: {
        navRow(
          title: L("Customize"),
          subtitle: L("Themes & accent colors"),
          systemImage: "paintpalette.fill",
          tint: progress.accentColor
        )
      }
      .buttonStyle(ScaleButtonStyle())

      NavigationLink {
        HabitManagerView()
      } label: {
        navRow(
          title: L("Habits"),
          subtitle: L("Add, edit & reorder your habits"),
          systemImage: "checklist",
          tint: DLColor.success
        )
      }
      .buttonStyle(ScaleButtonStyle())

      NavigationLink {
        SettingsView(progress: progress, entries: entries)
      } label: {
        navRow(
          title: L("Settings"),
          subtitle: L("Face ID, reminders, export & about"),
          systemImage: "gearshape.fill",
          tint: DLColor.textSecondary
        )
      }
      .buttonStyle(ScaleButtonStyle())
    }
  }

  private func navRow(title: String, subtitle: String, systemImage: String, tint: Color) -> some View {
    GlassCard {
      HStack(spacing: DLSpace.md) {
        ZStack {
          Circle().fill(tint.opacity(0.18)).frame(width: 44, height: 44)
          Image(systemName: systemImage)
            .font(.system(size: 18))
            .foregroundStyle(tint)
        }
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.dl(.headline, weight: .semibold))
            .foregroundStyle(DLColor.textPrimary)
          Text(subtitle)
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

  // MARK: Persistence

  /// A compact, typeable number field (matches the XP-cost input style).
  private func numberField(_ value: Binding<Int>, tint: Color, placeholder: String) -> some View {
    TextField(placeholder, value: value, format: .number)
      .keyboardType(.numberPad)
      .multilineTextAlignment(.trailing)
      .font(.dl(.subheadline, weight: .bold))
      .foregroundStyle(tint)
      .frame(width: 64)
      .padding(.vertical, 6)
      .padding(.horizontal, DLSpace.sm)
      .background(
        RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous)
          .fill(DLColor.separator.opacity(0.35))
      )
  }

  private func save() {
    try? context.save()
  }
}

// MARK: - Badge cell (with unlock celebration)

private struct BadgeCell: View {
  let badge: Badge
  let earned: Bool
  let progress: Double
  let index: Int
  let reduceMotion: Bool

  @State private var appeared = false
  @State private var shine = false

  var body: some View {
    VStack(spacing: 6) {
      ZStack {
        if earned {
          Circle()
            .fill(badge.color.opacity(0.18))
            .frame(width: 56, height: 56)

          // Celebratory pulse ring.
          Circle()
            .stroke(badge.color.opacity(shine ? 0.0 : 0.6), lineWidth: 2)
            .frame(width: 56, height: 56)
            .scaleEffect(shine ? 1.5 : 1.0)

          Image(systemName: badge.systemIcon)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(badge.color)
            .scaleEffect(appeared ? 1.0 : 0.2)
            .rotationEffect(.degrees(appeared ? 0 : -20))
        } else {
          Circle()
            .stroke(DLColor.separator.opacity(0.5), lineWidth: 4)
            .frame(width: 56, height: 56)
          Circle()
            .trim(from: 0, to: max(0.001, progress))
            .stroke(
              badge.color.opacity(0.7),
              style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
            .frame(width: 56, height: 56)
            .rotationEffect(.degrees(-90))
          Image(systemName: "lock.fill")
            .font(.system(size: 18))
            .foregroundStyle(DLColor.textTertiary)
        }
      }

      Text(L(badge.title))
        .font(.dl(.caption2, weight: .medium))
        .foregroundStyle(earned ? DLColor.textPrimary : DLColor.textTertiary)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .frame(minHeight: 28, alignment: .top)

      if earned {
        Text(L("Earned"))
          .font(.dl(.caption2, weight: .semibold))
          .foregroundStyle(badge.color)
      } else {
        Text("\(Int(progress * 100))%")
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
          .monospacedDigit()
      }
    }
    .frame(maxWidth: .infinity)
    .opacity(earned ? 1 : 0.85)
    .contentShape(Rectangle())
    .onAppear(perform: celebrateIfNeeded)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      earned
        ? "\(L(badge.title)) badge, earned. \(L(badge.subtitle))."
        : "\(L(badge.title)) badge, locked. \(Int(progress * 100)) percent toward \(L(badge.subtitle))."
    )
  }

  private func celebrateIfNeeded() {
    guard !appeared else { return }
    guard earned, !reduceMotion else {
      appeared = true
      return
    }
    // Staggered pop-in + shine for earned badges.
    let delay = Double(index) * 0.06
    withAnimation(DLAnim.bouncy.delay(delay)) {
      appeared = true
    }
    withAnimation(.easeOut(duration: 0.7).delay(delay + 0.1)) {
      shine = true
    }
  }
}
