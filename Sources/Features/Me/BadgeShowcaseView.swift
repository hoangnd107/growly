import SwiftUI
import SwiftData

/// A dedicated gallery of every badge: earned ones (with the date earned) up top,
/// and the next badge to chase in each family below — so once you earn a tier,
/// the next tier (Bronze → Silver → Gold) surfaces automatically (feature 18).
struct BadgeShowcaseView: View {
  @Query private var progressList: [UserProgress]
  @Query(sort: \Entry.day, order: .reverse) private var entries: [Entry]
  @Query private var notes: [DayNote]
  @Query(sort: \BadgeRecord.earnedAt, order: .reverse) private var badgeRecords: [BadgeRecord]

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  private var earnedDates: [String: Date] {
    Dictionary(badgeRecords.map { ($0.badgeID, $0.earnedAt) }, uniquingKeysWith: { a, _ in a })
  }

  private var stats: GamificationStats? {
    guard let progress = progressList.first else { return nil }
    return GamificationService.computeStats(
      progress: progress,
      allEntries: entries,
      notes: notes,
      level: progress.levelInfo.level
    )
  }

  private var earnedBadges: [Badge] {
    BadgeCatalog.all
      .filter { earnedDates[$0.id] != nil }
      .sorted { (earnedDates[$0.id] ?? .distantPast) > (earnedDates[$1.id] ?? .distantPast) }
  }

  /// The next badge to pursue: the lowest unearned tier in each family, plus any
  /// standalone unearned badges.
  private var nextBadges: [Badge] {
    var result: [Badge] = []
    var seenFamilies = Set<String>()
    for badge in BadgeCatalog.all where earnedDates[badge.id] == nil {
      if let family = badge.family {
        guard !seenFamilies.contains(family) else { continue }
        // Only surface the next tier once all lower tiers are earned.
        let lowerEarned = BadgeCatalog.family(family)
          .filter { $0.tier < badge.tier }
          .allSatisfy { earnedDates[$0.id] != nil }
        if lowerEarned {
          seenFamilies.insert(family)
          result.append(badge)
        }
      } else {
        result.append(badge)
      }
    }
    return result
  }

  private let columns = Array(repeating: GridItem(.flexible(), spacing: DLSpace.md), count: 3)

  var body: some View {
    ZStack {
      ThemedBackground(theme: theme)
      ScrollView {
        VStack(alignment: .leading, spacing: DLSpace.lg) {
          summaryCard
          if !earnedBadges.isEmpty { earnedSection }
          if !nextBadges.isEmpty { nextSection }
        }
        .padding(DLSpace.md)
      }
    }
    .navigationTitle(L("Achievements"))
    .navigationBarTitleDisplayMode(.inline)
    .tint(theme.accent)
  }

  private var summaryCard: some View {
    GlassCard {
      HStack(spacing: DLSpace.md) {
        EmptyGlyph(systemImage: "trophy.fill", size: 64, tint: DLColor.xpGold)
        VStack(alignment: .leading, spacing: 2) {
          Text(Lf("%d of %d earned", earnedBadges.count, BadgeCatalog.all.count))
            .font(.dl(.title3, weight: .bold))
            .foregroundStyle(DLColor.textPrimary)
            .monospacedDigit()
          Text(L("Keep showing up to unlock the next tier."))
            .font(.dl(.caption))
            .foregroundStyle(DLColor.textSecondary)
        }
        Spacer(minLength: 0)
      }
    }
  }

  private var earnedSection: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Text(L("Earned"))
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)
        LazyVGrid(columns: columns, spacing: DLSpace.md) {
          ForEach(earnedBadges) { badge in
            earnedCell(badge)
          }
        }
      }
    }
  }

  private var nextSection: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Text(L("Next up"))
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)
        ForEach(nextBadges) { badge in
          nextRow(badge)
          if badge.id != nextBadges.last?.id {
            Divider().overlay(DLColor.separator.opacity(0.5))
          }
        }
      }
    }
  }

  private func earnedCell(_ badge: Badge) -> some View {
    VStack(spacing: 6) {
      ZStack {
        Circle().fill(badge.color.opacity(0.18)).frame(width: 56, height: 56)
        Image(systemName: badge.systemIcon)
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(badge.color)
      }
      Text(L(badge.title))
        .font(.dl(.caption2, weight: .medium))
        .foregroundStyle(DLColor.textPrimary)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .frame(minHeight: 28, alignment: .top)
      if let date = earnedDates[badge.id] {
        Text(date, format: .dateTime.month(.abbreviated).day().year())
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
      }
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(L(badge.title)). \(L(badge.subtitle)).")
  }

  private func nextRow(_ badge: Badge) -> some View {
    let prog = stats.map { BadgeEngine.progress(for: badge.id, stats: $0) } ?? 0
    return HStack(spacing: DLSpace.md) {
      ZStack {
        Circle().stroke(DLColor.separator.opacity(0.5), lineWidth: 4).frame(width: 44, height: 44)
        Circle()
          .trim(from: 0, to: max(0.001, prog))
          .stroke(badge.color.opacity(0.8), style: StrokeStyle(lineWidth: 4, lineCap: .round))
          .frame(width: 44, height: 44)
          .rotationEffect(.degrees(-90))
        Image(systemName: badge.systemIcon)
          .font(.system(size: 16))
          .foregroundStyle(DLColor.textSecondary)
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(L(badge.title))
          .font(.dl(.subheadline, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)
        Text(L(badge.subtitle))
          .font(.dl(.caption))
          .foregroundStyle(DLColor.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
      Text("\(Int(prog * 100))%")
        .font(.dl(.caption2, weight: .semibold))
        .foregroundStyle(DLColor.textTertiary)
        .monospacedDigit()
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(L(badge.title)), \(Int(prog * 100)) percent. \(L(badge.subtitle)).")
  }
}
