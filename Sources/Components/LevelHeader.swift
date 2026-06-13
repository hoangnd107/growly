import SwiftUI

struct LevelHeader: View {
  let progress: UserProgress
  var todayXP: Int = 0

  var body: some View {
    let info = progress.levelInfo
    GlassCard {
      VStack(spacing: DLSpace.sm) {
        HStack(spacing: DLSpace.sm) {
          ZStack {
            Circle().fill(Color.accentColor.opacity(0.18)).frame(width: 46, height: 46)
            Text("\(info.level)")
              .font(.dl(.title3, weight: .bold))
              .foregroundStyle(Color.accentColor)
          }
          VStack(alignment: .leading, spacing: 1) {
            Text(LevelSystem.title(for: info.level))
              .font(.dl(.headline, weight: .semibold))
              .foregroundStyle(DLColor.textPrimary)
            Text("Level \(info.level)")
              .font(.dl(.caption))
              .foregroundStyle(DLColor.textSecondary)
          }
          Spacer()
          StreakFlame(streak: progress.currentStreak)
        }

        XPProgressBar(value: info.progress)

        HStack {
          Text("\(info.xpIntoLevel) / \(info.xpForNextLevel) XP")
            .font(.dl(.caption2))
            .foregroundStyle(DLColor.textSecondary)
            .monospacedDigit()
          Spacer()
          if todayXP > 0 {
            Label("+\(todayXP) today", systemImage: "bolt.fill")
              .font(.dl(.caption2, weight: .semibold))
              .foregroundStyle(DLColor.xpGold)
          }
        }
      }
    }
  }
}
