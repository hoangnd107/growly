import SwiftUI
import SwiftData

/// The five main tabs, in a standard `TabView` (system tab bar with labels, no
/// page-swipe between tabs — swiping is only used to move between sections
/// within a page). Each tab owns its own `NavigationStack`, so titles sit in
/// their normal position.
struct MainTabView: View {
  @Query private var progressList: [UserProgress]

  var body: some View {
    // Touch `languageCode` so the tab labels re-localize in place when the
    // in-app language changes — without resetting the selected tab / navigation.
    let _ = progressList.first?.languageCode

    TabView {
      TodayView()
        .tabItem { Label(L("Today"), systemImage: "sun.max.fill") }

      NotesView()
        .tabItem { Label(L("Notes"), systemImage: "note.text") }

      HistoryView()
        .tabItem { Label(L("History"), systemImage: "calendar") }

      InsightsView()
        .tabItem { Label(L("Insights"), systemImage: "chart.line.uptrend.xyaxis") }

      ProfileView()
        .tabItem { Label(L("Me"), systemImage: "person.fill") }
    }
  }
}
