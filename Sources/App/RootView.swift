import SwiftUI
import SwiftData

struct RootView: View {
  @Environment(\.modelContext) private var context
  @Query private var progressList: [UserProgress]
  @State private var unlocked = false

  private var progress: UserProgress? { progressList.first }

  var body: some View {
    ZStack {
      DLColor.background.ignoresSafeArea()

      if let progress {
        content(for: progress)
          .tint(progress.accentColor)
          .preferredColorScheme(progress.theme.colorScheme)
      } else {
        ProgressView()
      }
    }
    .task { Seed.ensure(context: context) }
  }

  @ViewBuilder
  private func content(for progress: UserProgress) -> some View {
    if !progress.onboarded {
      OnboardingView()
    } else if progress.faceIDEnabled && !unlocked {
      AppLockView(unlocked: $unlocked)
    } else {
      MainTabView()
    }
  }
}
