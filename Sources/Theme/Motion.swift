import SwiftUI

// MARK: - Pressable (spring scale on touch + haptic)

private struct PressableModifier: ViewModifier {
  var scale: CGFloat
  var haptic: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var pressed = false

  func body(content: Content) -> some View {
    content
      .scaleEffect(pressed && !reduceMotion ? scale : 1)
      .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pressed)
      .simultaneousGesture(
        DragGesture(minimumDistance: 0)
          .onChanged { _ in
            if !pressed {
              pressed = true
              if haptic { Haptics.light() }
            }
          }
          .onEnded { _ in pressed = false }
      )
  }
}

// MARK: - Glassmorphism surface

private struct GlassModifier: ViewModifier {
  var cornerRadius: CGFloat
  func body(content: Content) -> some View {
    content
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .strokeBorder(
            LinearGradient(
              colors: [.white.opacity(0.18), .white.opacity(0.04)],
              startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            lineWidth: 1
          )
      )
      .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 8)
  }
}

extension View {
  /// Adds a spring scale-down + light haptic while pressed.
  func bounceTap(scale: CGFloat = 0.95, haptic: Bool = true) -> some View {
    modifier(PressableModifier(scale: scale, haptic: haptic))
  }

  /// Wraps the view in a glassmorphism surface (blur + soft border + shadow).
  func glass(cornerRadius: CGFloat = DLRadius.card) -> some View {
    modifier(GlassModifier(cornerRadius: cornerRadius))
  }
}

// MARK: - Extra motion tokens

extension DLAnim {
  static let pop = Animation.spring(response: 0.34, dampingFraction: 0.55)
  static let smooth = Animation.spring(response: 0.5, dampingFraction: 0.85)
}
