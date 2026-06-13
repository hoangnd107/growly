import SwiftUI

struct ConfettiSpec: Identifiable {
  let id = UUID()
  let xFraction: Double
  let delay: Double
  let duration: Double
  let hue: Double
  let size: CGFloat

  var color: Color { Color(hue: hue, saturation: 0.7, brightness: 0.95) }

  static func random() -> ConfettiSpec {
    ConfettiSpec(
      xFraction: .random(in: 0...1),
      delay: .random(in: 0...0.4),
      duration: .random(in: 1.4...2.4),
      hue: .random(in: 0...1),
      size: .random(in: 6...11)
    )
  }
}

struct ConfettiView: View {
  var isActive: Bool
  private let pieces: [ConfettiSpec] = (0..<50).map { _ in ConfettiSpec.random() }

  var body: some View {
    GeometryReader { geo in
      ZStack {
        ForEach(pieces) { spec in
          ConfettiPieceView(spec: spec, isActive: isActive, canvas: geo.size)
        }
      }
    }
    .allowsHitTesting(false)
    .ignoresSafeArea()
  }
}

private struct ConfettiPieceView: View {
  let spec: ConfettiSpec
  let isActive: Bool
  let canvas: CGSize

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var fall = false

  var body: some View {
    RoundedRectangle(cornerRadius: 2)
      .fill(spec.color)
      .frame(width: spec.size, height: spec.size * 1.6)
      .position(x: spec.xFraction * canvas.width, y: fall ? canvas.height + 40 : -40)
      .rotationEffect(.degrees(fall ? 360 : 0))
      .opacity(fall ? 0 : 1)
      .onChange(of: isActive) { _, active in if active { trigger() } }
      .onAppear { if isActive { trigger() } }
  }

  private func trigger() {
    guard !reduceMotion else { return }
    fall = false
    withAnimation(.easeIn(duration: spec.duration).delay(spec.delay)) {
      fall = true
    }
  }
}
