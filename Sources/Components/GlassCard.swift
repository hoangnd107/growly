import SwiftUI

/// A rounded, frosted-glass container used throughout the app. Pass
/// `level: .raised` for hero/CTA surfaces and `.inset` for panels nested inside
/// another glass card (redesign v2 glass system).
struct GlassCard<Content: View>: View {
  var padding: CGFloat
  var level: GlassLevel
  @ViewBuilder var content: Content

  init(padding: CGFloat = DLSpace.md, level: GlassLevel = .standard, @ViewBuilder content: () -> Content) {
    self.padding = padding
    self.level = level
    self.content = content()
  }

  var body: some View {
    content
      .padding(padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .glass(cornerRadius: DLRadius.card, level: level)
  }
}
