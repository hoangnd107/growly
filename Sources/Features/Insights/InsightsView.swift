import SwiftUI
import SwiftData

struct InsightsView: View {
  @Query(sort: \Entry.day, order: .reverse) private var entries: [Entry]
  @Query private var progressList: [UserProgress]

  var body: some View {
    NavigationStack {
      ZStack {
        DLColor.background.ignoresSafeArea()
        ScrollView {
          VStack(spacing: DLSpace.lg) {
            GlassCard {
              VStack(alignment: .leading, spacing: DLSpace.sm) {
                Label("Weekly coach", systemImage: "sparkles")
                  .font(.dl(.headline, weight: .semibold))
                  .foregroundStyle(Color.accentColor)
                Text(AICoach.weeklySummary(entries: entries))
                  .font(.dl(.body))
                  .foregroundStyle(DLColor.textPrimary)
              }
            }

            if let progress = progressList.first {
              GlassCard {
                VStack(alignment: .leading, spacing: DLSpace.sm) {
                  Label("Growth score", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.dl(.headline, weight: .semibold))
                    .foregroundStyle(DLColor.success)
                  Text("\(Int(progress.growthScore))")
                    .font(.dl(.largeTitle, weight: .bold))
                    .foregroundStyle(DLColor.textPrimary)
                    .monospacedDigit()
                  Text("A compound score of your consistency and depth.")
                    .font(.dl(.caption))
                    .foregroundStyle(DLColor.textSecondary)
                }
              }
            }
          }
          .padding(DLSpace.md)
        }
      }
      .navigationTitle("Insights")
    }
  }
}
