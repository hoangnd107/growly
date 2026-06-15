import SwiftUI
import Foundation

/// Premium opening animation (~2s): a streak flame scales up and glows with
/// rising fire particles, the streak number fades in, and Ember (the flame
/// mascot) hops up to greet you — then it hands off to the app. Honors Reduce
/// Motion (quick fade).
struct LaunchView: View {
  let theme: GradientTheme
  let streak: Int
  var onFinish: () -> Void

  @Environment(\.colorScheme) private var scheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var flameScale: CGFloat = 0.35
  @State private var flameGlow: CGFloat = 0
  @State private var showText = false
  @State private var miraIn = false
  @State private var particlesOn = false

  var body: some View {
    ZStack {
      theme.background(scheme).ignoresSafeArea()

      if particlesOn && !reduceMotion {
        FireParticles(color: Color(hex: 0xFF8A3D))
          .ignoresSafeArea()
          .opacity(0.9)
      }

      VStack(spacing: DLSpace.lg) {
        Spacer()

        ZStack {
          Circle()
            .fill(
              RadialGradient(
                colors: [Color(hex: 0xFF9A3D).opacity(0.5), .clear],
                center: .center, startRadius: 0, endRadius: 150
              )
            )
            .frame(width: 300, height: 300)
            .opacity(flameGlow)

          Image(systemName: "flame.fill")
            .font(.system(size: 100))
            .foregroundStyle(
              LinearGradient(
                colors: [Color(hex: 0xFFC83D), Color(hex: 0xFF6B3D), Color(hex: 0xFF3D5A)],
                startPoint: .top, endPoint: .bottom
              )
            )
            .scaleEffect(flameScale)
            .shadow(color: Color(hex: 0xFF6B3D).opacity(0.6), radius: 26 * flameGlow)
        }

        if showText {
          Group {
            if streak > 0 {
              VStack(spacing: 2) {
                Text("\(streak)")
                  .font(.system(size: 46, weight: .bold, design: .rounded))
                  .foregroundStyle(DLColor.textPrimary)
                  .monospacedDigit()
                Text(L("day streak"))
                  .font(.dl(.subheadline, weight: .medium))
                  .foregroundStyle(DLColor.textSecondary)
              }
            } else {
              Text("Growly")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(DLColor.textPrimary)
            }
          }
          .transition(.opacity.combined(with: .move(edge: .bottom)))
        }

        Spacer()

        FlameMascot(size: 116)
          .offset(y: miraIn ? 0 : 240)
          .opacity(miraIn ? 1 : 0)
          .padding(.bottom, DLSpace.xxl)
          .allowsHitTesting(false)
      }
    }
    .onAppear(perform: run)
  }

  private func run() {
    if reduceMotion {
      flameScale = 1; flameGlow = 1; showText = true; miraIn = true
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { onFinish() }
      return
    }

    particlesOn = true
    withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) { flameScale = 1.0 }
    withAnimation(.easeOut(duration: 0.9)) { flameGlow = 1 }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
      withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { showText = true }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
      Haptics.medium()
      withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { miraIn = true }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
      withAnimation(.easeInOut(duration: 0.55).repeatCount(2, autoreverses: true)) {
        flameScale = 1.08
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) { onFinish() }
  }
}

// MARK: - Fire particles (Canvas)

private struct FireParticle {
  let x: Double
  let size: CGFloat
  let speed: Double
  let offset: Double
  let life: Double

  static func random() -> FireParticle {
    FireParticle(
      x: .random(in: 0.32...0.68),
      size: .random(in: 3...8),
      speed: .random(in: 0.4...0.9),
      offset: .random(in: 0...6),
      life: .random(in: 1.4...2.6)
    )
  }
}

private struct FireParticles: View {
  var color: Color
  private let particles: [FireParticle] = (0..<28).map { _ in FireParticle.random() }

  var body: some View {
    TimelineView(.animation) { timeline in
      Canvas { context, size in
        let t = timeline.date.timeIntervalSinceReferenceDate
        for p in particles {
          let phase = ((t * p.speed + p.offset).truncatingRemainder(dividingBy: p.life)) / p.life
          let y = size.height * (0.60 - CGFloat(phase) * 0.5)
          let x = size.width * CGFloat(p.x) + CGFloat(sin(phase * .pi * 2 + p.offset)) * 14
          let radius = p.size * (1 - CGFloat(phase) * 0.6)
          context.opacity = (1.0 - phase) * 0.7
          context.fill(
            Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
            with: .color(color)
          )
        }
      }
    }
  }
}
