import SwiftUI
import SwiftData

struct HistoryView: View {
  @Query(sort: \Entry.day, order: .reverse) private var entries: [Entry]

  @State private var query = ""
  @State private var moodFilter: Mood?
  @State private var visibleMonth = Calendar.current.startOfDay(for: Date())
  @State private var path = NavigationPath()

  private var calendar: Calendar { Calendar.current }

  /// Day-start -> mood color, for the calendar dots (all entries, unfiltered
  /// search but respecting the mood filter so the calendar mirrors the list).
  private var entriesByDay: [Date: Color] {
    var map: [Date: Color] = [:]
    for entry in entries where moodFilter == nil || entry.mood == moodFilter {
      map[calendar.startOfDay(for: entry.day)] = entry.mood.color
    }
    return map
  }

  /// Entries shown in the list, filtered by search text and selected mood.
  private var filtered: [Entry] {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return entries.filter { entry in
      if let moodFilter, entry.mood != moodFilter { return false }
      guard !q.isEmpty else { return true }
      return entry.win.lowercased().contains(q)
        || entry.mistake.lowercased().contains(q)
        || entry.lesson.lowercased().contains(q)
        || entry.adjustment.lowercased().contains(q)
        || entry.morningIntention.lowercased().contains(q)
        || entry.tags.contains { $0.lowercased().contains(q) }
    }
  }

  private func entry(on day: Date) -> Entry? {
    entries.first { calendar.isDate($0.day, inSameDayAs: day) }
  }

  var body: some View {
    NavigationStack(path: $path) {
      ZStack {
        DLColor.background.ignoresSafeArea()

        if entries.isEmpty {
          ContentUnavailableView(
            "No entries yet",
            systemImage: "calendar",
            description: Text("Your reflections will appear here.")
          )
        } else {
          content
        }
      }
      .navigationTitle("History")
      .searchable(text: $query, prompt: "Search reflections")
      .navigationDestination(for: Entry.self) { entry in
        EntryDetailView(entry: entry)
      }
    }
  }

  private var content: some View {
    ScrollView {
      LazyVStack(spacing: DLSpace.md, pinnedViews: []) {
        calendarCard

        moodFilterChips

        if filtered.isEmpty {
          ContentUnavailableView {
            Label("No matches", systemImage: "magnifyingglass")
          } description: {
            Text("Try a different search or clear the mood filter.")
          }
          .padding(.top, DLSpace.xl)
        } else {
          ForEach(filtered) { entry in
            NavigationLink(value: entry) {
              row(entry)
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(DLSpace.md)
    }
  }

  // MARK: - Calendar

  private var calendarCard: some View {
    GlassCard {
      VStack(spacing: DLSpace.sm) {
        HStack {
          Button {
            shiftMonth(by: -1)
          } label: {
            Image(systemName: "chevron.left")
              .font(.system(size: 15, weight: .semibold))
              .frame(width: 44, height: 44)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Previous month")

          Spacer()

          Text(visibleMonth, format: .dateTime.month(.wide).year())
            .font(.dl(.headline, weight: .semibold))
            .foregroundStyle(DLColor.textPrimary)

          Spacer()

          Button {
            shiftMonth(by: 1)
          } label: {
            Image(systemName: "chevron.right")
              .font(.system(size: 15, weight: .semibold))
              .frame(width: 44, height: 44)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Next month")
        }
        .foregroundStyle(DLColor.textSecondary)

        CalendarMonthView(
          month: visibleMonth,
          entriesByDay: entriesByDay,
          onSelect: { day in
            if let entry = entry(on: day) { path.append(entry) }
          }
        )
      }
    }
  }

  private func shiftMonth(by value: Int) {
    if let next = calendar.date(byAdding: .month, value: value, to: visibleMonth) {
      withAnimation(DLAnim.standard) {
        visibleMonth = calendar.startOfDay(for: next)
      }
    }
  }

  // MARK: - Mood filter chips

  private var moodFilterChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: DLSpace.sm) {
        chip(label: "All", emoji: nil, color: Color.accentColor, isSelected: moodFilter == nil) {
          moodFilter = nil
        }
        ForEach(Mood.allCases) { mood in
          chip(label: mood.label, emoji: mood.emoji, color: mood.color, isSelected: moodFilter == mood) {
            moodFilter = (moodFilter == mood) ? nil : mood
          }
        }
      }
      .padding(.horizontal, 2)
    }
  }

  private func chip(label: String, emoji: String?, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
    Button {
      withAnimation(DLAnim.quick) { action() }
      Haptics.selection()
    } label: {
      HStack(spacing: 4) {
        if let emoji { Text(emoji) }
        Text(label)
          .font(.dl(.subheadline, weight: .medium))
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(
        isSelected ? color.opacity(0.22) : DLColor.surfaceElevated,
        in: Capsule()
      )
      .overlay(
        Capsule().strokeBorder(isSelected ? color : Color.clear, lineWidth: 1.5)
      )
      .foregroundStyle(isSelected ? color : DLColor.textSecondary)
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  // MARK: - List row

  private func row(_ entry: Entry) -> some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        HStack(spacing: DLSpace.sm) {
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
        if !entry.win.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Text(entry.win)
            .font(.dl(.subheadline))
            .foregroundStyle(DLColor.textSecondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        if !entry.tags.isEmpty {
          Text(entry.tags.map { "#\($0)" }.joined(separator: " "))
            .font(.dl(.caption))
            .foregroundStyle(DLColor.textTertiary)
            .lineLimit(1)
        }
      }
    }
  }
}
