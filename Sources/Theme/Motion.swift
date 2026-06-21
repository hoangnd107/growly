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

// MARK: - Glass surface system

/// Depth levels for the app's unified glass surface system (redesign v2).
/// Every card-like surface in the app routes through `.glass(level:)` so depth,
/// material, edge highlight, and shadow stay consistent everywhere.
enum GlassLevel {
  /// Default card — `ultraThinMaterial`, soft layered shadow.
  case standard
  /// Hero / CTA / celebration — heavier material, deeper shadow, brighter edge.
  case raised
  /// A row or panel nested inside another card — faint material, no shadow.
  case inset
}

/// A premium frosted-glass surface: a translucent material fill, a top-lit edge
/// that fades into a hairline border, and a soft two-layer shadow for real
/// depth. Falls back to an opaque paper surface when Reduce Transparency is on.
private struct GlassModifier: ViewModifier {
  var cornerRadius: CGFloat
  var level: GlassLevel
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorScheme) private var scheme

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    return content
      .background(fill, in: shape)
      .overlay {
        // Single edge stroke: a light sheen at the top fading to the hairline
        // separator at the bottom — reads as glass and defines the card on the
        // near-flat paper backdrop.
        shape.strokeBorder(
          LinearGradient(
            colors: [
              Color.white.opacity(scheme == .dark ? 0.22 : 0.55),
              DLColor.separator.opacity(scheme == .dark ? 0.45 : 0.9),
            ],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: 1
        )
      }
      .compositingGroup()
      .shadow(color: .black.opacity(ambient.opacity), radius: ambient.radius, x: 0, y: ambient.y)
      .shadow(color: .black.opacity(key.opacity), radius: key.radius, x: 0, y: key.y)
  }

  private var fill: AnyShapeStyle {
    if reduceTransparency {
      return AnyShapeStyle(level == .inset ? DLColor.surfaceElevated : DLColor.surface)
    }
    switch level {
    case .standard: return AnyShapeStyle(.ultraThinMaterial)
    case .raised: return AnyShapeStyle(.regularMaterial)
    case .inset: return AnyShapeStyle(.thinMaterial)
    }
  }

  /// Wide, soft ambient shadow.
  private var ambient: (opacity: Double, radius: CGFloat, y: CGFloat) {
    switch level {
    case .standard: return (scheme == .dark ? 0.30 : 0.07, 16, 8)
    case .raised: return (scheme == .dark ? 0.42 : 0.11, 26, 12)
    case .inset: return (0, 0, 0)
    }
  }

  /// Tight contact shadow that grounds the card.
  private var key: (opacity: Double, radius: CGFloat, y: CGFloat) {
    switch level {
    case .standard: return (scheme == .dark ? 0.22 : 0.05, 4, 2)
    case .raised: return (scheme == .dark ? 0.30 : 0.07, 6, 3)
    case .inset: return (0, 0, 0)
    }
  }
}

extension View {
  /// Adds a spring scale-down + light haptic while pressed.
  func bounceTap(scale: CGFloat = 0.95, haptic: Bool = true) -> some View {
    modifier(PressableModifier(scale: scale, haptic: haptic))
  }

  /// Wraps the view in the app's frosted-glass surface (material + edge highlight
  /// + layered shadow). Pass `level: .raised` for hero/CTA surfaces and
  /// `level: .inset` for panels nested inside another glass card.
  func glass(cornerRadius: CGFloat = DLRadius.card, level: GlassLevel = .standard) -> some View {
    modifier(GlassModifier(cornerRadius: cornerRadius, level: level))
  }
}

// MARK: - Navigation-safe press style

/// A `ButtonStyle` that scales slightly while pressed. Unlike `.bounceTap()`
/// (which attaches a `simultaneousGesture(DragGesture)` that can swallow a
/// `NavigationLink`/`Button` activation), this drives the scale from the
/// button's own `configuration.isPressed`, so navigation and actions still fire.
/// Use this on `NavigationLink`s and any tappable card that must always trigger.
struct ScaleButtonStyle: ButtonStyle {
  var scale: CGFloat = 0.97
  var haptic: Bool = false

  func makeBody(configuration: Configuration) -> some View {
    Pressable(configuration: configuration, scale: scale, haptic: haptic)
  }

  /// Nested view so `@Environment` is actually injected — a bare `ButtonStyle`
  /// struct does not receive environment values.
  private struct Pressable: View {
    let configuration: ButtonStyleConfiguration
    let scale: CGFloat
    let haptic: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
      configuration.label
        .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
        .onChange(of: configuration.isPressed) { _, pressed in
          if pressed && haptic { Haptics.light() }
        }
    }
  }
}

// MARK: - Extra motion tokens

extension DLAnim {
  static let pop = Animation.spring(response: 0.34, dampingFraction: 0.55)
  static let smooth = Animation.spring(response: 0.5, dampingFraction: 0.85)
}
