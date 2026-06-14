import SwiftUI

struct MainTabView: View {
  var body: some View {
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
