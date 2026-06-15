import SwiftUI
import SwiftData

/// Full-screen celebration shown after completing the daily review.
/// Dimmed scrim + confetti, a big celebrating flame, XP / streak multiplier /
/// level-up / new badges, an AICoach quote and Continue.
/// Spring entrance, tap-to-dismiss, Reduce-Motion aware, gradient-theme tinted.
struct CompletionCelebration: View {
  let result: ReviewResult
  @Binding var isPresented: Bool

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Query private var progressList: [UserProgress]

  @State private var appear = false
  @State private var flameAppear = false
  @State private var glowPulse = false

  // Stable so a re-render doesn't shuffle the quote.
  @State private var quote: String = AICoach.quote()

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "warm")
  }

  private var flameGradient: LinearGradient {
    LinearGradient(
      colors: [
        Color(hex: 0xFFE08A),
        DLColor.xpGold,
        DLColor.streakStart,
        DLColor.streakEnd
      ],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  var body: some View {
    ZStack {
      // Dimmed scrim — tap anywhere to dismiss.
      Color.black.opacity(0.55)
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }

      // Soft themed glow behind everything.
      RadialGradient(
        colors: [theme.accent.opacity(0.35), .clear],
        center: .center,
        startRadius: 8,
        endRadius: 320
      )
      .ignoresSafeArea()
      .opacity(appear ? 1 : 0)

      ConfettiView(isActive: appear)
        .allowsHitTesting(false)

      VStack(spacing: DLSpace.md) {
        celebrationHeader

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
          badgesSection
        }

        Text("“\(quote)”")
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
          .bounceTap()
          .padding(.top, DLSpace.sm)
      }
      .padding(DLSpace.xl)
      .scaleEffect(appear ? 1 : 0.85)
      .opacity(appear ? 1 : 0)
    }
    .onAppear(perform: animateIn)
    .accessibilityAddTraits(.isModal)
  }

  // MARK: Header (flame + headline)

  private var celebrationHeader: some View {
    VStack(spacing: DLSpace.sm) {
      // Big celebrating flame with a warm gradient + glow.
      flame
        .scaleEffect(flameAppear ? 1 : 0.4)
        .opacity(flameAppear ? 1 : 0)
        .frame(maxWidth: .infinity)

      Text(result.leveledUp ? L("Level Up!") : L("Day complete!"))
        .font(.dl(.largeTitle, weight: .bold))
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
    }
  }

  private var flame: some View {
    Image(systemName: "flame.fill")
      .font(.system(size: 84, weight: .bold))
      .foregroundStyle(flameGradient)
      .shadow(color: DLColor.streakStart.opacity(0.7), radius: 18, y: 4)
      .shadow(color: DLColor.xpGold.opacity(0.6), radius: 30)
      .scaleEffect(glowPulse && !reduceMotion ? 1.06 : 1.0)
      .accessibilityHidden(true)
  }

  // MARK: Badges

  private var badgesSection: some View {
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
              .multilineTextAlignment(.center)
          }
        }
      }
    }
    .padding(.top, 4)
  }

  // MARK: Animation

  private func animateIn() {
    guard !reduceMotion else {
      appear = true
      flameAppear = true
      return
    }

    withAnimation(DLAnim.bouncy) { appear = true }
    withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.08)) {
      flameAppear = true
    }
    withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
      glowPulse = true
    }
  }

  private func dismiss() {
    Haptics.light()
    withAnimation(DLAnim.quick) { isPresented = false }
  }
}
