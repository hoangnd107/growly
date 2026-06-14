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
          .environment(\.locale, locale(for: progress.languageCode))
          // Force a full rebuild when the in-app language changes so every
          // L("…") string re-resolves against the new bundle.
          .id(progress.languageCode)
      } else {
        ProgressView()
      }
    }
    .task { Seed.ensure(context: context) }
  }

  @ViewBuilder
  private func content(for progress: UserProgress) -> some View {
    // Apply the language synchronously before children read L(...).
    let _ = (LocalizationManager.shared.code = progress.languageCode)

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
