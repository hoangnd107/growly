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
          // Changing the locale propagates through the tree and re-runs the
          // visible views' bodies (so L("…") re-resolves) WITHOUT tearing down
          // navigation — the user stays exactly where they were.
          .environment(\.locale, locale(for: progress.languageCode))
      } else {
        ProgressView()
      }
    }
    .task { Seed.ensure(context: context) }
  }

  @ViewBuilder
  private func content(for progress: UserProgress) -> some View {
    // Apply the language + mood catalog synchronously before children render.
    let _ = (LocalizationManager.shared.code = progress.languageCode)
    let _ = MoodCatalog.shared.apply(from: progress)

    Group {
      if !progress.onboarded {
        OnboardingView()
      } else if progress.faceIDEnabled && !unlocked {
        AppLockView(unlocked: $unlocked)
      } else {
        MainTabView()
      }
    }
    .onAppear {
      NotificationService.sync(
        enabled: progress.reminderEnabled,
        hour: progress.reminderHour,
        minute: progress.reminderMinute
      )
    }
  }

  private func locale(for code: String) -> Locale {
    code == "system" ? .autoupdatingCurrent : Locale(identifier: code)
  }
}
