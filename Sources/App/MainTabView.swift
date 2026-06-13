import SwiftUI

struct MainTabView: View {
  var body: some View {
    TabView {
      TodayView()
        .tabItem { Label("Today", systemImage: "sun.max.fill") }

      HistoryView()
        .tabItem { Label("History", systemImage: "calendar") }

      InsightsView()
        .tabItem { Label("Insights", systemImage: "chart.line.uptrend.xyaxis") }

      ProfileView()
        .tabItem { Label("Me", systemImage: "person.fill") }
    }
  }
}
