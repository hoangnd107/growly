import UIKit

enum Haptics {
  static func success() {
    UINotificationFeedbackGenerator().notificationOccurred(.success)
  }

  static func light() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
  }

  static func selection() {
    UISelectionFeedbackGenerator().selectionChanged()
  }
}
