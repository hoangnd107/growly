import SwiftUI
import SwiftData

/// The "Me" tab — an inspiring profile hub: level + rank, lifetime stats, a fully
/// customizable streak-freeze console, an animated badge gallery, and navigation
/// to customization, habits, and settings. No-arg by contract; reads everything
/// from SwiftData.
struct ProfileView: View {
  @Query private var progressList: [UserProgress]
  @Query(sort: \Entry.day, order: .reverse) private var entries: [Entry]
  @Query private var notes: [DayNote]
  @Query(sort: \BadgeRecord.earnedAt, order: .reverse) private var badgeRecords: [BadgeRecord]

  @Environment(\.modelContext) private var context

  var body: some View {
    NavigationStack {
      ZStack {
        if let progress = progressList.first {
          ProfileContent(
            progress: progress,
            entries: entries,
            notes: notes,
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
  let notes: [DayNote]
  let badgeRecords: [BadgeRecord]
  let context: ModelContext

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  // Selected badge for the detail sheet.
  @State private var selectedBadge: Badge?

  private var earnedIDs: Set<String> { Set(badgeRecords.map(\.badgeID)) }

  private var stats: GamificationStats {
    GamificationService.computeStats(
      progress: progress,
      allEntries: entries,
      notes: notes,
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
      VStack(alignment: .leading, spacing: DLSpace.lg) {
        levelHeaderSection
        VStack(alignment: .leading, spacing: DLSpace.sm) {
          SectionLabel(L("Lifetime"))
          statsStrip
        }
        badgeGallery
        navigationCards
        streakFreezeSummaryCard
        settingsCard
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
    // The "Your rank" card was removed (feature 15); rank/level/streak still live
    // in the header at the top.
    LevelHeader(progress: progress)
  }

  // MARK: 2. Stats strip

  /// Lifetime identity stats as an editorial ledger. Deliberately excludes
  /// growth score (owned by Insights) and current/longest streak (owned by
  /// Insights + History + the LevelHeader flame) to avoid cross-tab duplication.
  private var statsStrip: some View {
    let info = progress.levelInfo
    let toNext = max(0, info.xpForNextLevel - info.xpIntoLevel)
    return StatTileGrid(
      tiles: [
        StatTileData(
          value: "\(progress.totalXP)",
          label: L("Total XP"),
          sublabel: Lf("%d XP to level %d", toNext, info.level + 1),
          tint: DLColor.xpGold
        ),
        StatTileData(value: "\(info.level)", label: L("Level"), tint: DLColor.accent),
        StatTileData(value: "\(entries.count)", label: L("Reviews")),
        StatTileData(value: "\(notes.filter { $0.deletedAt == nil }.count)", label: L("Notes")),
      ],
      hero: true
    )
  }

  // MARK: 3. Streak freeze (summary → full editor)

  /// A compact summary that pushes the full editor, so the freeze controls stay
  /// hidden until the user taps in.
  private var streakFreezeSummaryCard: some View {
    NavigationLink {
      StreakFreezeView(progress: progress)
    } label: {
      navRow(
        title: L("Streak Freeze"),
        subtitle: Lf("%d-day completion streak · %d frozen days ahead", progress.currentStreak, upcomingFrozenCount),
        systemImage: "snowflake",
        tint: Color(hex: 0x5AC8FA)
      )
    }
    .buttonStyle(ScaleButtonStyle())
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
          NavigationLink {
            BadgeShowcaseView()
          } label: {
            HStack(spacing: 4) {
              Text("\(earnedIDs.count)/\(BadgeCatalog.all.count)")
                .font(.dl(.subheadline, weight: .semibold))
                .monospacedDigit()
              Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(DLColor.textSecondary)
          }
          .accessibilityLabel(L("See all achievements"))
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
        IdentityView()
      } label: {
        navRow(
          title: L("Identity"),
          subtitle: L("The person you want to become"),
          systemImage: "figure.mind.and.body",
          tint: Color(hex: 0xAF8CFF)
        )
      }
      .buttonStyle(ScaleButtonStyle())

      NavigationLink {
        ManifestoView()
      } label: {
        navRow(
          title: L("Manifesto"),
          subtitle: L("What you stand for"),
          systemImage: "doc.text.fill",
          tint: Color(hex: 0x5AC8FA)
        )
      }
      .buttonStyle(ScaleButtonStyle())

      NavigationLink {
        LifeAreaInsightsView()
      } label: {
        navRow(
          title: L("Life areas"),
          subtitle: L("Review & track health, work, and more"),
          systemImage: "chart.xyaxis.line",
          tint: DLColor.success
        )
      }
      .buttonStyle(ScaleButtonStyle())

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
    }
  }

  /// Settings — pinned to the very bottom of the Me tab.
  private var settingsCard: some View {
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
