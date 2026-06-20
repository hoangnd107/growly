import SwiftUI

/// The app's gradient theme backdrop. Drop into a ZStack behind screen content.
struct ThemedBackground: View {
  /// Kept for source compatibility; the editorial backdrop is a flat warm paper
  /// rather than a per-theme gradient wash.
  var theme: GradientTheme? = nil

  var body: some View {
    DLColor.background.ignoresSafeArea()
  }
}

extension View {
  /// Places the gradient theme behind this view (full-bleed).
  func themedBackground(_ theme: GradientTheme) -> some View {
    background(ThemedBackground(theme: theme))
  }
}
