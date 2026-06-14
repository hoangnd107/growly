import SwiftUI
import SwiftData

@main
struct GrowlyApp: App {
  var body: some Scene {
    WindowGroup {
      RootView()
    }
    .modelContainer(AppModelContainer.shared)
  }
}
