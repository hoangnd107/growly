import SwiftUI
import SwiftData
import UIKit

@main
struct GrowlyApp: App {
  init() { AppAppearance.apply() }

  var body: some Scene {
    WindowGroup {
      // Open straight into the app — no launch splash. Opening the app lands on
      // the Today tab directly. Seeding and first-run onboarding are handled
      // inside `RootView`.
      RootView()
    }
    .modelContainer(AppModelContainer.shared)
  }
}

/// App-wide UIKit chrome: rounded navigation titles on a clean bar (transparent
/// at the large-title edge, paper material once scrolled) so the nav typography
/// matches the rounded body font used everywhere else.
enum AppAppearance {
  static func apply() {
    // Rounded + explicitly weighted nav titles (size 0 keeps Dynamic Type). The
    // large title is bold so it reads as heavy as the editorial report headers,
    // not the lighter default weight (round-3 item 4).
    func roundedFont(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont? {
      let base = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style)
      guard let rounded = base.withDesign(.rounded) else { return nil }
      let weighted = rounded.addingAttributes([
        .traits: [UIFontDescriptor.TraitKey.weight: weight.rawValue]
      ])
      return UIFont(descriptor: weighted, size: 0)
    }

    let scrollEdge = UINavigationBarAppearance()
    scrollEdge.configureWithTransparentBackground()
    let standard = UINavigationBarAppearance()
    standard.configureWithDefaultBackground()

    for appearance in [scrollEdge, standard] {
      if let large = roundedFont(.largeTitle, weight: .bold) {
        appearance.largeTitleTextAttributes[.font] = large
      }
      if let inline = roundedFont(.headline, weight: .semibold) {
        appearance.titleTextAttributes[.font] = inline
      }
    }

    UINavigationBar.appearance().scrollEdgeAppearance = scrollEdge
    UINavigationBar.appearance().standardAppearance = standard
    UINavigationBar.appearance().compactAppearance = standard
  }
}
