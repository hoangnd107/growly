import SwiftUI
import UIKit

extension View {
  /// Adds a keyboard accessory bar with a "Done" button that dismisses the
  /// keyboard. Apply to screens with text input (feedback item: hide-keyboard).
  func keyboardDismissButton() -> some View {
    toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button {
          KeyboardHelper.dismiss()
        } label: {
          Label(L("Done"), systemImage: "keyboard.chevron.compact.down")
            .labelStyle(.titleAndIcon)
            .font(.dl(.subheadline, weight: .semibold))
        }
      }
    }
  }
}

enum KeyboardHelper {
  static func dismiss() {
    UIApplication.shared.sendAction(
      #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
    )
  }
}
