import SwiftUI
import SwiftData
import UIKit

@main
struct GrowlyApp: App {
  init() { AppAppearance.apply() }

  var body: some Scene {
    WindowGroup {
      AppRootView()
    }
    .modelContainer(AppModelContainer.shared)
  }
}

/// Shows the launch animation first, then crossfades into the app.
private struct AppRootView: View {
  @Environment(\.modelContext) private var context
  @Query private var progressList: [UserProgress]
  @State private var launchDone = false

  private var progress: UserProgress? { progressList.first }
  private var theme: GradientTheme {
    GradientThemeCatalog.theme(id: progress?.gradientThemeID ?? "teal")
  }

  var body: some View {
    ZStack {
      if launchDone {
        RootView()
          .transition(.opacity)
      } else {
        LaunchView(theme: theme, streak: progress?.currentStreak ?? 0) {
          withAnimation(.easeInOut(duration: 0.5)) { launchDone = true }
        }
        .transition(.opacity.combined(with: .scale(scale: 1.04)))
      }
    }
    .task { Seed.ensure(context: context) }
  }
}

/// App-wide UIKit chrome: rounded navigation titles on a clean bar (transparent
/// at the large-title edge, paper material once scrolled) so the nav typography
/// matches the rounded body font used everywhere else.
enum AppAppearance {
  static func apply() {
    func roundedFont(_ style: UIFont.TextStyle) -> UIFont? {
      guard let descriptor = UIFontDescriptor
        .preferredFontDescriptor(withTextStyle: style)
        .withDesign(.rounded) else { return nil }
      return UIFont(descriptor: descriptor, size: 0)
    }

    let scrollEdge = UINavigationBarAppearance()
    scrollEdge.configureWithTransparentBackground()
    let standard = UINavigationBarAppearance()
    standard.configureWithDefaultBackground()

    for appearance in [scrollEdge, standard] {
      if let large = roundedFont(.largeTitle) {
        appearance.largeTitleTextAttributes[.font] = large
      }
      if let inline = roundedFont(.headline) {
        appearance.titleTextAttributes[.font] = inline
      }
    }

    UINavigationBar.appearance().scrollEdgeAppearance = scrollEdge
    UINavigationBar.appearance().standardAppearance = standard
    UINavigationBar.appearance().compactAppearance = standard
  }
}
