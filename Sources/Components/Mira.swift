import SwiftUI

/// Mira — Growly's chibi cat mascot. Drawn entirely in SwiftUI (no assets).
/// Idle: gentle bob. Tap: hops + waves. Long-press + drag: move (when draggable).
/// Optional speech bubble for encouraging quotes.
struct MiraView: View {
  var size: CGFloat = 96
  var quote: String? = nil
  var draggable: Bool = false
  var onInteract: (() -> Void)? = nil

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var bob = false
  @State private var jumpOffset: CGFloat = 0
  @State private var waveAngle: Double = 0
  @State private var squish = false
  @State private var dragOffset: CGSize = .zero

  // Palette
  private let fur = Color(hex: 0xFFC68A)
  private let furDark = Color(hex: 0xEFA158)
  private let earInner = Color(hex: 0xFFB0BE)
  private let blushColor = Color(hex: 0xFF8FA3)
  private let eyeColor = Color(hex: 0x2B2B30)

  var body: some View {
    VStack(spacing: size * 0.05) {
      if let quote, !quote.isEmpty {
        bubble(quote)
          .transition(.scale(scale: 0.6).combined(with: .opacity))
      }
      cat
    }
    .offset(dragOffset)
    .gesture(dragGesture)
    .onTapGesture { react() }
    .onAppear { if !reduceMotion { bob = true } }
    .accessibilityElement(children: .ignore)
    .accessibilityAddTraits(.isButton)
    .accessibilityLabel("Mira")
  }

  // MARK: Cat

  private var cat: some View {
    ZStack {
      tail
      torso
      paw(isWaving: true).offset(x: -size * 0.16, y: size * 0.30)
      paw(isWaving: false).offset(x: size * 0.16, y: size * 0.34)
      head
    }
    .frame(width: size, height: size)
    .scaleEffect(x: squish ? 1.07 : 1, y: squish ? 0.93 : 1, anchor: .bottom)
    .offset(y: bob && !reduceMotion ? -size * 0.025 : 0)
    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: bob)
    .offset(y: jumpOffset)
  }

  private var tail: some View {
    Capsule()
      .fill(furDark)
      .frame(width: size * 0.12, height: size * 0.4)
      .rotationEffect(.degrees(bob ? -28 : -16), anchor: .bottom)
      .offset(x: size * 0.27, y: size * 0.16)
      .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: bob)
  }

  private var torso: some View {
    Ellipse()
      .fill(fur)
      .frame(width: size * 0.5, height: size * 0.42)
      .offset(y: size * 0.24)
  }

  private func paw(isWaving: Bool) -> some View {
    Capsule()
      .fill(furDark)
      .frame(width: size * 0.16, height: size * 0.11)
      .rotationEffect(.degrees(isWaving ? waveAngle : 0), anchor: .trailing)
  }

  private var head: some View {
    ZStack {
      // Ears
      ear.offset(x: -size * 0.2, y: -size * 0.27)
      ear.offset(x: size * 0.2, y: -size * 0.27)
      // Face base
      Circle()
        .fill(fur)
        .frame(width: size * 0.6, height: size * 0.6)
      face
    }
    .offset(y: -size * 0.05)
  }

  private var ear: some View {
    ZStack {
      Triangle().fill(fur)
        .frame(width: size * 0.24, height: size * 0.22)
      Triangle().fill(earInner)
        .frame(width: size * 0.12, height: size * 0.11)
        .offset(y: size * 0.04)
    }
  }

  private var face: some View {
    ZStack {
      // Blush
      Circle().fill(blushColor.opacity(0.45))
        .frame(width: size * 0.1, height: size * 0.1)
        .offset(x: -size * 0.17, y: size * 0.04)
      Circle().fill(blushColor.opacity(0.45))
        .frame(width: size * 0.1, height: size * 0.1)
        .offset(x: size * 0.17, y: size * 0.04)
      // Eyes
      eye(at: -size * 0.12)
      eye(at: size * 0.12)
      // Nose
      Triangle()
        .fill(blushColor)
        .frame(width: size * 0.05, height: size * 0.04)
        .rotationEffect(.degrees(180))
        .offset(y: size * 0.02)
      // Mouth
      MiraMouth()
        .stroke(eyeColor.opacity(0.7), style: StrokeStyle(lineWidth: max(1, size * 0.012), lineCap: .round))
        .frame(width: size * 0.12, height: size * 0.05)
        .offset(y: size * 0.07)
      // Whiskers
      whiskers(flip: false).offset(x: -size * 0.24, y: size * 0.03)
      whiskers(flip: true).offset(x: size * 0.24, y: size * 0.03)
    }
  }

  private func eye(at x: CGFloat) -> some View {
    ZStack {
      Capsule().fill(eyeColor)
        .frame(width: size * 0.07, height: size * 0.1)
      Circle().fill(.white)
        .frame(width: size * 0.022, height: size * 0.022)
        .offset(x: size * 0.012, y: -size * 0.022)
    }
    .offset(x: x, y: -size * 0.05)
  }

  private func whiskers(flip: Bool) -> some View {
    VStack(spacing: size * 0.03) {
      Capsule().frame(width: size * 0.16, height: max(1, size * 0.01))
      Capsule().frame(width: size * 0.16, height: max(1, size * 0.01))
    }
    .foregroundStyle(furDark.opacity(0.7))
    .rotationEffect(.degrees(flip ? -8 : 8))
    .scaleEffect(x: flip ? -1 : 1)
  }

  private func bubble(_ text: String) -> some View {
    Text(text)
      .font(.dl(.caption, weight: .semibold))
      .foregroundStyle(DLColor.textPrimary)
      .multilineTextAlignment(.center)
      .padding(.horizontal, DLSpace.sm)
      .padding(.vertical, DLSpace.xs)
      .frame(maxWidth: size * 2.2)
      .glass(cornerRadius: DLRadius.small)
  }

  // MARK: Interaction

  private func react() {
    onInteract?()
    Haptics.medium()
    guard !reduceMotion else { return }
    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
      jumpOffset = -size * 0.28
      squish = true
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
      withAnimation(.spring(response: 0.42, dampingFraction: 0.6)) {
        jumpOffset = 0
        squish = false
      }
    }
    withAnimation(.easeInOut(duration: 0.16).repeatCount(5, autoreverses: true)) {
      waveAngle = -24
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
      withAnimation(.easeInOut(duration: 0.2)) { waveAngle = 0 }
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

private struct Triangle: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.midX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.closeSubpath()
    return path
  }
}

private struct MiraMouth: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.midX, y: rect.minY))
    path.addQuadCurve(
      to: CGPoint(x: rect.minX, y: rect.maxY),
      control: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.minY)
    )
    path.move(to: CGPoint(x: rect.midX, y: rect.minY))
    path.addQuadCurve(
      to: CGPoint(x: rect.maxX, y: rect.maxY),
      control: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.minY)
    )
    return path
  }
}
