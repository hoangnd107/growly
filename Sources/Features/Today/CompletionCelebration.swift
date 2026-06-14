import SwiftUI

/// Full-screen celebration shown after completing the daily review.
struct CompletionCelebration: View {
  let result: ReviewResult
  @Binding var isPresented: Bool

  @State private var appear = false

  var body: some View {
    ZStack {
      Color.black.opacity(0.55).ignoresSafeArea()
        .onTapGesture { dismiss() }

      ConfettiView(isActive: appear)

      VStack(spacing: DLSpace.md) {
        Text(result.leveledUp ? L("Level Up!") : L("Day complete!"))
          .font(.dl(.largeTitle, weight: .bold))
          .foregroundStyle(.white)

        Label(Lf("+%d XP", result.xpGained), systemImage: "bolt.fill")
          .font(.dl(.title2, weight: .bold))
          .foregroundStyle(DLColor.xpGold)

        if result.multiplier > 1 {
          Text(Lf("Streak bonus ×%.1f", result.multiplier))
            .font(.dl(.subheadline, weight: .semibold))
            .foregroundStyle(DLColor.streakEnd)
        }

        if result.leveledUp {
          Text(Lf("You reached level %d · %@", result.newLevel, LevelSystem.title(for: result.newLevel)))
            .font(.dl(.subheadline))
            .foregroundStyle(.white.opacity(0.9))
            .multilineTextAlignment(.center)
        }

        if !result.newBadges.isEmpty {
          VStack(spacing: DLSpace.sm) {
            Text(result.newBadges.count > 1 ? L("New badges") : L("New badge"))
              .font(.dl(.subheadline, weight: .semibold))
              .foregroundStyle(.white)
            HStack(spacing: DLSpace.md) {
              ForEach(result.newBadges) { badge in
                VStack(spacing: 4) {
                  Image(systemName: badge.systemIcon)
                    .font(.system(size: 30))
                    .foregroundStyle(badge.color)
                  Text(badge.title)
                    .font(.dl(.caption2))
                    .foregroundStyle(.white)
                }
              }
            }
          }
          .padding(.top, 4)
        }

        Text("“\(AICoach.quote())”")
          .font(.dl(.callout))
          .italic()
          .multilineTextAlignment(.center)
          .foregroundStyle(.white.opacity(0.85))
          .padding(.horizontal, DLSpace.lg)
          .padding(.top, 4)

        Button(L("Continue")) { dismiss() }
          .font(.dl(.headline, weight: .semibold))
          .padding(.horizontal, DLSpace.xl)
          .padding(.vertical, 12)
          .background(.white, in: Capsule())
          .foregroundStyle(.black)
          .padding(.top, DLSpace.sm)
      }
      .padding(DLSpace.xl)
      .scaleEffect(appear ? 1 : 0.85)
      .opacity(appear ? 1 : 0)
    }
    .onAppear {
      withAnimation(DLAnim.bouncy) { appear = true }
    }
  }

  private func dismiss() {
    withAnimation(DLAnim.quick) { isPresented = false }
  }
}
