import SwiftUI

/// The app's backdrop. Drop into a ZStack behind screen content. A very subtle
/// depth wash (vertical paper lift + a faint accent glow at the top) gives the
/// glass surfaces something to refract without competing with content.
struct ThemedBackground: View {
  /// Kept for source compatibility; the backdrop is a neutral paper wash rather
  /// than a per-theme gradient.
  var theme: GradientTheme? = nil
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    ZStack {
      DLColor.background
      LinearGradient(
        colors: [
          DLColor.surfaceElevated.opacity(scheme == .dark ? 0.55 : 0.9),
          DLColor.background,
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      RadialGradient(
        colors: [DLColor.accent.opacity(scheme == .dark ? 0.10 : 0.05), .clear],
        center: .topTrailing,
        startRadius: 0,
        endRadius: 520
      )
    }
    .ignoresSafeArea()
  }
}

extension View {
  /// Places the gradient theme behind this view (full-bleed).
  func themedBackground(_ theme: GradientTheme) -> some View {
    background(ThemedBackground(theme: theme))
  }
}
