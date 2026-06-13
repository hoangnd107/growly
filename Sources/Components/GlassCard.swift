import SwiftUI

/// A rounded, subtly glassy container used throughout the app.
struct GlassCard<Content: View>: View {
  var padding: CGFloat
  @ViewBuilder var content: Content

  init(padding: CGFloat = DLSpace.md, @ViewBuilder content: () -> Content) {
    self.padding = padding
    self.content = content()
  }

  var body: some View {
    content
      .padding(padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DLRadius.card, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: DLRadius.card, style: .continuous)
          .strokeBorder(DLColor.separator.opacity(0.6), lineWidth: 1)
      )
  }
}
