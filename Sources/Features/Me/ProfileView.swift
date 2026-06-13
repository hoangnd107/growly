import SwiftUI
import SwiftData

struct ProfileView: View {
  @Query private var progressList: [UserProgress]
  @Query(sort: \BadgeRecord.earnedAt, order: .reverse) private var badgeRecords: [BadgeRecord]

  private var earnedIDs: Set<String> { Set(badgeRecords.map { $0.badgeID }) }

  var body: some View {
    NavigationStack {
      ZStack {
        DLColor.background.ignoresSafeArea()
        ScrollView {
          VStack(spacing: DLSpace.lg) {
            if let progress = progressList.first {
              LevelHeader(progress: progress)
            }

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
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DLSpace.md), count: 3), spacing: DLSpace.md) {
                  ForEach(BadgeCatalog.all) { badge in
                    badgeCell(badge, earned: earnedIDs.contains(badge.id))
                  }
                }
              }
            }
          }
          .padding(DLSpace.md)
        }
      }
      .navigationTitle("Me")
    }
  }

  private func badgeCell(_ badge: Badge, earned: Bool) -> some View {
    VStack(spacing: 6) {
      ZStack {
        Circle()
          .fill(earned ? badge.color.opacity(0.18) : DLColor.separator.opacity(0.4))
          .frame(width: 56, height: 56)
        Image(systemName: earned ? badge.systemIcon : "lock.fill")
          .font(.system(size: 22))
          .foregroundStyle(earned ? badge.color : DLColor.textTertiary)
      }
      Text(badge.title)
        .font(.dl(.caption2, weight: .medium))
        .foregroundStyle(earned ? DLColor.textPrimary : DLColor.textTertiary)
        .multilineTextAlignment(.center)
        .lineLimit(2)
    }
    .frame(maxWidth: .infinity)
    .opacity(earned ? 1 : 0.7)
  }
}
