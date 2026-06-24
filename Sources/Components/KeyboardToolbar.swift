import SwiftUI
import UIKit

// MARK: - Keyboard visibility

/// Observes the system keyboard and publishes a simple visible/hidden flag.
/// Driven by `UIResponder` notifications, so it is reliable regardless of the
/// navigation / sheet context the text field lives in — unlike a
/// `.toolbar(.keyboard)` accessory, which intermittently fails to appear
/// (feedback item 3: the Done button must ALWAYS show while typing).
final class KeyboardObserver: ObservableObject {
  @Published var isVisible = false

  private var tokens: [NSObjectProtocol] = []

  init() {
    let nc = NotificationCenter.default
    tokens.append(nc.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { [weak self] _ in
      self?.isVisible = true
    })
    tokens.append(nc.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [weak self] _ in
      self?.isVisible = false
    })
  }

  deinit { tokens.forEach { NotificationCenter.default.removeObserver($0) } }
}

// MARK: - Always-visible dismiss accessory

/// A thin bar with a right-aligned "Done" button. Hosted in `.safeAreaInset`, so
/// it rides just above the keyboard and never gets covered by it.
private struct KeyboardDoneBar: View {
  var body: some View {
    HStack(spacing: 0) {
      Spacer(minLength: 0)
      Button {
        KeyboardHelper.dismiss()
        Haptics.light()
      } label: {
        Label(L("Done"), systemImage: "keyboard.chevron.compact.down")
          .labelStyle(.titleAndIcon)
          .font(.dl(.subheadline, weight: .semibold))
          .foregroundStyle(Color.accentColor)
          .padding(.horizontal, DLSpace.md)
          .padding(.vertical, DLSpace.sm)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(L("Hide keyboard"))
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, DLSpace.xs)
    .background(.bar)
    .overlay(alignment: .top) { Divider() }
  }
}

private struct KeyboardAwareModifier: ViewModifier {
  @StateObject private var keyboard = KeyboardObserver()
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
    content
      // Dismissal is via the always-visible "Done" bar only. We deliberately do
      // NOT attach a tap-outside gesture: a global tap recognizer competes with
      // text selection / caret placement and adds input latency while typing.
      .safeAreaInset(edge: .bottom, spacing: 0) {
        if keyboard.isVisible {
          KeyboardDoneBar()
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
      .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: keyboard.isVisible)
  }
}

extension View {
  /// Robust keyboard handling for any screen with text input: an always-visible
  /// "Done" bar above the keyboard PLUS tap-outside-to-dismiss. Replaces the
  /// flaky `.toolbar(.keyboard)` accessory (feedback item 3).
  func keyboardDismissButton() -> some View { modifier(KeyboardAwareModifier()) }

  /// Alias with a clearer name for new call sites.
  func keyboardAware() -> some View { modifier(KeyboardAwareModifier()) }
}

enum KeyboardHelper {
  static func dismiss() {
    UIApplication.shared.sendAction(
      #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
    )
  }
}
