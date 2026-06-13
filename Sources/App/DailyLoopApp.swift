import SwiftUI
import SwiftData

@main
struct DailyLoopApp: App {
  var body: some Scene {
    WindowGroup {
      RootView()
    }
    .modelContainer(AppModelContainer.shared)
  }
}
