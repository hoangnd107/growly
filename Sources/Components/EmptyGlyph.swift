import SwiftUI

/// A simple, decorative glyph for empty states — a soft tinted disc with a
/// centered SF Symbol. Replaces the former mascot illustration.
struct EmptyGlyph: View {
  let systemImage: String
  var size: CGFloat = 120
  var tint: Color = DLColor.textTertiary

  var body: some View {
    ZStack {
      Circle()
        .fill(tint.opacity(0.14))
        .frame(width: size, height: size)
      Image(systemName: systemImage)
        .font(.system(size: size * 0.42, weight: .semibold))
        .foregroundStyle(tint)
    }
    .accessibilityHidden(true)
  }
}
