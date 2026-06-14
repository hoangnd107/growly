import SwiftUI

/// The app's gradient theme backdrop. Drop into a ZStack behind screen content.
struct ThemedBackground: View {
  let theme: GradientTheme
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    theme.background(scheme).ignoresSafeArea()
  }
}

extension View {
  /// Places the gradient theme behind this view (full-bleed).
  func themedBackground(_ theme: GradientTheme) -> some View {
    background(ThemedBackground(theme: theme))
  }
}
