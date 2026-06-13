import SwiftUI
import SwiftData

struct ProfileView: View {
  @Query private var progressList: [UserProgress]
  @Query(sort: \Entry.day, order: .reverse) private var entries: [Entry]
  @Query(sort: \BadgeRecord.earnedAt, order: .reverse) private var badgeRecords: [BadgeRecord]
  @Query(sort: \XPTransaction.date, order: .reverse) private var transactions: [XPTransaction]

  private var earnedIDs: Set<String> { Set(badgeRecords.map { $0.badgeID }) }

  var body: some View {
    NavigationStack {
      ZStack {
        DLColor.background.ignoresSafeArea()
        if let progress = progressList.first {
          content(progress: progress)
        } else {
          ProgressView()
        }
      }
      .navigationTitle("Me")
    }
  }

  @ViewBuilder
  private func content(progress: UserProgress) -> some View {
    let stats = GamificationService.computeStats(
      progress: progress,
      allEntries: entries,
      level: progress.levelInfo.level
    )

    ScrollView {
      VStack(spacing: DLSpace.lg) {
        LevelHeader(progress: progress)

        statsStrip(progress)

        XPHistoryChart(transactions: transactions)

        badgeGallery(stats: stats)

        navigationCards(progress: progress)
      }
      .padding(DLSpace.md)
    }
  }

  // MARK: Stats strip

  private func statsStrip(_ progress: UserProgress) -> some View {
    GlassCard {
      HStack(spacing: 0) {
        statCell(value: "\(progress.totalXP)", label: "Total XP", tint: DLColor.xpGold)
        statDivider
        statCell(value: "\(progress.currentStreak)", label: "Streak", tint: DLColor.streakStart)
        statDivider
        statCell(value: "\(progress.longestStreak)", label: "Longest", tint: DLColor.streakEnd)
        statDivider
        statCell(value: "\(Int(progress.growthScore))", label: "Growth", tint: DLColor.success)
      }
    }
  }

  private func statCell(value: String, label: String, tint: Color) -> some View {
    VStack(spacing: DLSpace.xs) {
      Text(value)
        .font(.dl(.title2, weight: .bold))
        .foregroundStyle(tint)
        .monospacedDigit()
        .contentTransition(.numericText())
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      Text(label)
        .font(.dl(.caption2, weight: .medium))
        .foregroundStyle(DLColor.textSecondary)
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(label): \(value)")
  }

  private var statDivider: some View {
    Rectangle()
      .fill(DLColor.separator.opacity(0.6))
      .frame(width: 1, height: 32)
  }

  // MARK: Badge gallery

  private func badgeGallery(stats: GamificationStats) -> some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        HStack {
          Text("Badges")
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
          ForEach(BadgeCatalog.all) { badge in
            badgeCell(
              badge,
              earned: earnedIDs.contains(badge.id),
              progress: BadgeEngine.progress(for: badge.id, stats: stats)
            )
          }
        }
      }
    }
  }

  private func badgeCell(_ badge: Badge, earned: Bool, progress: Double) -> some View {
    VStack(spacing: 6) {
      ZStack {
        if earned {
          Circle()
            .fill(badge.color.opacity(0.18))
            .frame(width: 56, height: 56)
          Image(systemName: badge.systemIcon)
            .font(.system(size: 22))
            .foregroundStyle(badge.color)
        } else {
          // Locked: a progress ring toward the badge requirement.
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

      Text(badge.title)
        .font(.dl(.caption2, weight: .medium))
        .foregroundStyle(earned ? DLColor.textPrimary : DLColor.textTertiary)
        .multilineTextAlignment(.center)
        .lineLimit(2)

      if earned {
        Text("Earned")
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
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      earned
        ? "\(badge.title) badge, earned. \(badge.subtitle)."
        : "\(badge.title) badge, locked. \(Int(progress * 100)) percent toward \(badge.subtitle)."
    )
  }

  // MARK: Navigation

  private func navigationCards(progress: UserProgress) -> some View {
    VStack(spacing: DLSpace.md) {
      NavigationLink {
        CustomizationShopView(progress: progress)
      } label: {
        navRow(
          title: "Customize",
          subtitle: "Unlock accent colors by level",
          systemImage: "paintpalette.fill",
          tint: progress.accentColor
        )
      }
      .buttonStyle(.plain)

      NavigationLink {
        SettingsView(progress: progress, entries: entries)
      } label: {
        navRow(
          title: "Settings",
          subtitle: "Theme, Face ID, export & about",
          systemImage: "gearshape.fill",
          tint: DLColor.textSecondary
        )
      }
      .buttonStyle(.plain)
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
        Spacer()
        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(DLColor.textTertiary)
      }
    }
  }
}
