import SwiftUI
import SwiftData

/// The mascot's mood — drives the eyes and mouth. Plain flame, no limbs.
enum FlameEmotion: CaseIterable {
  case happy, excited, content, sleepy, surprised
}

/// Growly's mascot: a simple flame with an expressive face. No arms or legs —
/// just a flame that gently burns (subtle sway + flicker), blinks an emotion,
/// hops & changes expression when tapped, and can be dragged when `draggable`.
///
/// Drawn entirely in SwiftUI (no image assets). Reduce-Motion aware: the burn
/// loop and tap hop are skipped, leaving a calm static flame.
///
/// Signature matches the old mascot so call sites pass `size`/`quote` unchanged.
struct FlameMascot: View {
  var size: CGFloat = 96
  var quote: String? = nil
  var draggable: Bool = false
  var onInteract: (() -> Void)? = nil

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var burn = false          // continuous gentle burn loop
  @State private var emotion: FlameEmotion = .happy
  @State private var reactScale: CGFloat = 1
  @State private var hop: CGFloat = 0
  @State private var dragOffset: CGSize = .zero

  // Warm flame palette.
  private let coreColor = Color(hex: 0xFFE9A8)
  private let midColor = Color(hex: 0xFFB020)
  private let edgeColor = Color(hex: 0xFF6A00)
  private let glowColor = Color(hex: 0xFF8A1E)
  private let ink = Color(hex: 0x4A2400)

  var body: some View {
    VStack(spacing: size * 0.06) {
      if let quote, !quote.isEmpty {
        bubble(quote)
          .transition(.scale(scale: 0.6).combined(with: .opacity))
      }
      flame
    }
    .offset(dragOffset)
    .gesture(dragGesture)
    .onTapGesture { react() }
    .onAppear { if !reduceMotion { burn = true } }
    .accessibilityElement(children: .ignore)
    .accessibilityAddTraits(.isButton)
    .accessibilityLabel(L("Ember, your flame"))
  }

  // MARK: - Flame body

  private var flame: some View {
    ZStack {
      // Soft glow halo.
      FlameShape()
        .fill(glowColor.opacity(reduceMotion ? 0.28 : (burn ? 0.40 : 0.22)))
        .frame(width: size * 0.95, height: size * 1.12)
        .blur(radius: size * 0.12)

      // Outer flame.
      FlameShape()
        .fill(
          LinearGradient(
            colors: [edgeColor, midColor],
            startPoint: .bottom, endPoint: .top
          )
        )
        .frame(width: size * 0.74, height: size)
        .overlay(
          FlameShape()
            .stroke(edgeColor.opacity(0.5), lineWidth: max(1, size * 0.01))
            .frame(width: size * 0.74, height: size)
        )

      // Inner core flame.
      FlameShape()
        .fill(
          LinearGradient(
            colors: [coreColor, midColor.opacity(0.9)],
            startPoint: .bottom, endPoint: .top
          )
        )
        .frame(width: size * 0.44, height: size * 0.66)
        .offset(y: size * 0.16)
        .opacity(reduceMotion ? 0.95 : (burn ? 1.0 : 0.8))

      face
        .offset(y: size * 0.20)
    }
    .frame(width: size * 0.74, height: size)
    // Gentle "burning" deformation + sway.
    .scaleEffect(
      x: burn && !reduceMotion ? 1.035 : 0.975,
      y: burn && !reduceMotion ? 0.97 : 1.04,
      anchor: .bottom
    )
    .rotationEffect(.degrees(burn && !reduceMotion ? 2.2 : -2.2), anchor: .bottom)
    .animation(
      reduceMotion ? nil : .easeInOut(duration: 1.25).repeatForever(autoreverses: true),
      value: burn
    )
    // Tap reaction (independent of the burn loop).
    .scaleEffect(reactScale)
    .offset(y: hop)
    .frame(height: size * 1.12)
  }

  // MARK: - Face

  private var face: some View {
    VStack(spacing: size * 0.05) {
      HStack(spacing: size * 0.13) {
        eye
        eye
      }
      mouth
        .frame(width: size * 0.16, height: size * 0.1)
    }
  }

  @ViewBuilder
  private var eye: some View {
    switch emotion {
    case .excited, .surprised:
      ZStack {
        Circle().fill(ink)
          .frame(width: size * 0.085, height: size * 0.11)
        Circle().fill(.white)
          .frame(width: size * 0.03, height: size * 0.03)
          .offset(x: size * 0.015, y: -size * 0.025)
      }
    case .sleepy:
      Capsule().fill(ink)
        .frame(width: size * 0.09, height: max(1.5, size * 0.018))
    case .happy, .content:
      FlameEyeArc()
        .stroke(ink, style: StrokeStyle(lineWidth: max(1.5, size * 0.022), lineCap: .round))
        .frame(width: size * 0.09, height: size * 0.055)
    }
  }

  @ViewBuilder
  private var mouth: some View {
    switch emotion {
    case .excited:
      // Open happy mouth.
      Capsule()
        .fill(ink)
        .frame(width: size * 0.13, height: size * 0.085)
        .overlay(alignment: .bottom) {
          Capsule().fill(Color(hex: 0xFF7E8A))
            .frame(width: size * 0.07, height: size * 0.035)
            .offset(y: -size * 0.008)
        }
    case .surprised:
      Circle().fill(ink)
        .frame(width: size * 0.06, height: size * 0.06)
    case .sleepy:
      Circle().fill(ink.opacity(0.8))
        .frame(width: size * 0.04, height: size * 0.04)
    case .happy, .content:
      FlameSmile()
        .stroke(ink, style: StrokeStyle(lineWidth: max(1.5, size * 0.022), lineCap: .round))
        .frame(width: size * 0.16, height: size * 0.075)
    }
  }

  // MARK: - Speech bubble

  private func bubble(_ text: String) -> some View {
    Text(text)
      .font(.dl(.caption, weight: .semibold))
      .foregroundStyle(DLColor.textPrimary)
      .multilineTextAlignment(.center)
      .padding(.horizontal, DLSpace.sm)
      .padding(.vertical, DLSpace.xs)
      .frame(maxWidth: max(120, size * 2.4))
      .glass(cornerRadius: DLRadius.small)
  }

  // MARK: - Interaction

  private func react() {
    onInteract?()
    Haptics.medium()
    // Cycle to a lively expression, then settle back to happy.
    let lively: [FlameEmotion] = [.excited, .surprised, .content]
    emotion = lively.randomElement() ?? .excited
    guard !reduceMotion else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { emotion = .happy }
      return
    }
    withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) {
      reactScale = 1.18
      hop = -size * 0.16
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
      withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
        reactScale = 1
        hop = 0
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
      withAnimation(.easeInOut(duration: 0.25)) { emotion = .happy }
    }
  }

  private var dragGesture: some Gesture {
    LongPressGesture(minimumDuration: 0.18)
      .sequenced(before: DragGesture())
      .onChanged { value in
        guard draggable else { return }
        if case .second(true, let drag?) = value {
          dragOffset = drag.translation
        }
      }
      .onEnded { _ in
        guard draggable else { return }
        Haptics.soft()
      }
  }
}

// MARK: - Shapes

/// A teardrop flame: rounded base tapering to a soft point at the top.
private struct FlameShape: Shape {
  func path(in r: CGRect) -> Path {
    let w = r.width, h = r.height
    var p = Path()
    p.move(to: CGPoint(x: r.midX, y: r.maxY))
    // Left side up to the tip.
    p.addCurve(
      to: CGPoint(x: r.midX + w * 0.03, y: r.minY),
      control1: CGPoint(x: r.minX + w * 0.02, y: r.maxY - h * 0.32),
      control2: CGPoint(x: r.minX + w * 0.34, y: r.minY + h * 0.06)
    )
    // Right side back down to the base.
    p.addCurve(
      to: CGPoint(x: r.midX, y: r.maxY),
      control1: CGPoint(x: r.maxX - w * 0.20, y: r.minY + h * 0.16),
      control2: CGPoint(x: r.maxX - w * 0.02, y: r.maxY - h * 0.30)
    )
    p.closeSubpath()
    return p
  }
}

/// A gentle upward arch used for happy/closed eyes.
private struct FlameEyeArc: Shape {
  func path(in r: CGRect) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: r.minX, y: r.maxY))
    p.addQuadCurve(
      to: CGPoint(x: r.maxX, y: r.maxY),
      control: CGPoint(x: r.midX, y: r.minY - r.height * 0.4)
    )
    return p
  }
}

/// A simple smile curve.
private struct FlameSmile: Shape {
  func path(in r: CGRect) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: r.minX, y: r.minY))
    p.addQuadCurve(
      to: CGPoint(x: r.maxX, y: r.minY),
      control: CGPoint(x: r.midX, y: r.maxY + r.height * 0.4)
    )
    return p
  }
}

// MARK: - Global floating overlay

/// The always-present, draggable mascot that floats above every main screen.
/// Long-press to pick it up and drag; a quick tap makes it hop and change
/// expression. Its position is remembered across launches. Honors the user's
/// `miraEnabled` preference (on by default).
struct FlameMascotOverlay: View {
  @Query private var progressList: [UserProgress]

  @AppStorage("flameMascotX") private var storedX: Double = -1
  @AppStorage("flameMascotY") private var storedY: Double = -1

  @State private var showQuote = false

  private let flameSize: CGFloat = 54
  private let coordSpace = "flameMascotSpace"

  private var enabled: Bool { progressList.first?.miraEnabled ?? true }

  var body: some View {
    GeometryReader { geo in
      if enabled {
        FlameMascot(
          size: flameSize,
          quote: showQuote ? AICoach.quote() : nil,
          draggable: false,
          onInteract: { flashQuote() }
        )
        .position(resolved(in: geo.size))
        .gesture(dragGesture(in: geo.size))
        .accessibilityLabel(L("Ember — drag to move, tap to play"))
      }
    }
    .coordinateSpace(name: coordSpace)
    .ignoresSafeArea(.keyboard)
  }

  /// Current position, defaulting to the lower-left (clear of the Notes "+"
  /// button on the right) and clamped inside the safe drawing area.
  private func resolved(in canvas: CGSize) -> CGPoint {
    let defaultX = flameSize * 0.85 + 12
    let defaultY = canvas.height - 150
    let x = storedX < 0 ? defaultX : storedX
    let y = storedY < 0 ? defaultY : storedY
    let half = flameSize * 0.7
    return CGPoint(
      x: min(max(half, x), canvas.width - half),
      y: min(max(half + 40, y), canvas.height - half - 20)
    )
  }

  private func dragGesture(in canvas: CGSize) -> some Gesture {
    LongPressGesture(minimumDuration: 0.2)
      .sequenced(before: DragGesture(coordinateSpace: .named(coordSpace)))
      .onChanged { value in
        if case .second(true, let drag?) = value {
          storedX = drag.location.x
          storedY = drag.location.y
        }
      }
      .onEnded { _ in Haptics.soft() }
  }

  private func flashQuote() {
    withAnimation(DLAnim.standard) { showQuote = true }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
      withAnimation(DLAnim.standard) { showQuote = false }
    }
  }
}
