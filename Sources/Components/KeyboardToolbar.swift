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

extension View {
  /// Dismisses the keyboard when the user taps an empty area of this view.
  /// Uses a *simultaneous* tap gesture so it never steals taps from buttons,
  /// links, or text fields underneath — those keep working, and tapping blank
  /// space simply resigns the first responder. Safe to layer on scroll views.
  func dismissKeyboardOnTap() -> some View {
    simultaneousGesture(
      TapGesture().onEnded { KeyboardHelper.dismiss() }
    )
  }
}

enum KeyboardHelper {
  static func dismiss() {
    UIApplication.shared.sendAction(
      #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
    )
  }
}
