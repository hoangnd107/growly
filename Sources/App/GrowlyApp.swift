import SwiftUI
import SwiftData

@main
struct GrowlyApp: App {
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
