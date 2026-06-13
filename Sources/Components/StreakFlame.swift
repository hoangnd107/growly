import SwiftUI

struct StreakFlame: View {
  let streak: Int
  var size: CGFloat = 20

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var pulse = false

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: "flame.fill")
        .font(.system(size: size))
        .foregroundStyle(
          LinearGradient(
            colors: [DLColor.streakStart, DLColor.streakEnd],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .scaleEffect(pulse ? 1.12 : 1.0)
        .shadow(color: DLColor.streakEnd.opacity(0.5), radius: pulse ? 8 : 3)
      Text("\(streak)")
        .font(.dl(.subheadline, weight: .bold))
        .foregroundStyle(DLColor.textPrimary)
        .monospacedDigit()
    }
    .onAppear {
      guard streak > 0, !reduceMotion else { return }
      withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
        pulse = true
      }
    }
  }
}
