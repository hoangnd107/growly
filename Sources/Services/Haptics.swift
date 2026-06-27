import UIKit

/// Lightweight haptics.
///
/// Performance (round 8, item 2): the feedback generators are created **once** and
/// reused, and each call `prepare()`s the engine for the *next* tap. The old code
/// allocated a brand-new `UIFeedbackGenerator` on every call and never prepared it,
/// so each tap had to spin the Taptic Engine up from cold — a small but pervasive
/// latency that, because `selection()`/`light()` fire on nearly every tap, scroll
/// press, and selection in the app, made interactions feel sluggish. Reusing warm
/// generators removes both the per-tap allocation and the cold-start delay.
///
/// `UIFeedbackGenerator` must be touched on the main thread; every call site here is
/// already a main-thread UI action, and the calls are dispatched to main defensively
/// so a stray background call can't crash.
enum Haptics {
  private static let selectionGenerator = UISelectionFeedbackGenerator()
  private static let notificationGenerator = UINotificationFeedbackGenerator()
  private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
  private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
  private static let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
  private static let softGenerator = UIImpactFeedbackGenerator(style: .soft)
  private static let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)

  /// Prime the Taptic Engine so the first interaction after launch is instant too.
  /// Called once on app start.
  static func warmUp() {
    onMain {
      selectionGenerator.prepare()
      lightGenerator.prepare()
    }
  }

  static func success() { notify(.success) }
  static func warning() { notify(.warning) }
  static func error() { notify(.error) }

  static func light() { impact(lightGenerator) }
  static func medium() { impact(mediumGenerator) }
  static func heavy() { impact(heavyGenerator) }
  static func soft() { impact(softGenerator) }
  static func rigid() { impact(rigidGenerator) }

  static func selection() {
    onMain {
      selectionGenerator.selectionChanged()
      selectionGenerator.prepare()
    }
  }

  private static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
    onMain {
      notificationGenerator.notificationOccurred(type)
      notificationGenerator.prepare()
    }
  }

  private static func impact(_ generator: UIImpactFeedbackGenerator) {
    onMain {
      generator.impactOccurred()
      generator.prepare()
    }
  }

  /// Run `work` on the main thread now if we're already on it, else hop over.
  private static func onMain(_ work: @escaping () -> Void) {
    if Thread.isMainThread {
      work()
    } else {
      DispatchQueue.main.async(execute: work)
    }
  }
}
