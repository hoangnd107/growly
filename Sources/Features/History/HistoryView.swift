import SwiftUI
import SwiftData

struct HistoryView: View {
  @Query(sort: \Entry.day, order: .reverse) private var entries: [Entry]
  @State private var query = ""

  private var filtered: [Entry] {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !q.isEmpty else { return entries }
    return entries.filter {
      $0.win.lowercased().contains(q) || $0.mistake.lowercased().contains(q) ||
      $0.lesson.lowercased().contains(q) || $0.adjustment.lowercased().contains(q) ||
      $0.tags.contains { $0.lowercased().contains(q) }
    }
  }

  var body: some View {
    NavigationStack {
      ZStack {
        DLColor.background.ignoresSafeArea()
        if entries.isEmpty {
          ContentUnavailableView("No entries yet", systemImage: "calendar",
            description: Text("Your reflections will appear here."))
        } else {
          ScrollView {
            LazyVStack(spacing: DLSpace.md) {
              ForEach(filtered) { entry in
                row(entry)
              }
            }
            .padding(DLSpace.md)
          }
        }
      }
      .navigationTitle("History")
      .searchable(text: $query, prompt: "Search reflections")
    }
  }

  private func row(_ entry: Entry) -> some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        HStack {
          Text(entry.mood.emoji)
          Text(entry.day, format: .dateTime.weekday(.wide).month().day())
            .font(.dl(.subheadline, weight: .semibold))
            .foregroundStyle(DLColor.textPrimary)
          Spacer()
          if entry.xpAwarded > 0 {
            Label("\(entry.xpAwarded)", systemImage: "bolt.fill")
              .font(.dl(.caption2, weight: .semibold))
              .foregroundStyle(DLColor.xpGold)
          }
        }
        if !entry.win.isEmpty {
          Text(entry.win)
            .font(.dl(.subheadline))
            .foregroundStyle(DLColor.textSecondary)
            .lineLimit(2)
        }
      }
    }
  }
}
