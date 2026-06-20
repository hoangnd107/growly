import SwiftUI
import SwiftData
import Charts

/// A writing/journaling volume report: how many words and notes the user has
/// written within a selectable time window, the volume over time, and the
/// longest pieces. Self-contained — fetches its own DayNotes via `@Query` so it
/// can be pushed as `WritingStatsView()` from any NavigationStack.
struct WritingStatsView: View {
  // Newest first; we filter deleted + by range in-memory so the query stays simple.
  @Query(sort: \DayNote.createdAt, order: .reverse) private var notes: [DayNote]

  @State private var range: StatsRange = .month
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  // MARK: - Derived data

  /// Non-deleted notes that fall within the selected range.
  private var notesInRange: [DayNote] {
    let start = range.startDate()
    return notes.filter { note in
      guard note.deletedAt == nil else { return false }
      if let start { return note.createdAt >= start }
      return true
    }
  }

  private var totalWords: Int { notesInRange.reduce(0) { $0 + $1.wordCount } }
  private var totalNotes: Int { notesInRange.count }
  private var avgWords: Int {
    guard totalNotes > 0 else { return 0 }
    return Int((Double(totalWords) / Double(totalNotes)).rounded())
  }
  private var longestWordCount: Int { notesInRange.map(\.wordCount).max() ?? 0 }

  /// Top 5 notes by word count (ties broken by recency).
  private var longestNotes: [DayNote] {
    Array(
      notesInRange
        .sorted {
          $0.wordCount != $1.wordCount
            ? $0.wordCount > $1.wordCount
            : $0.createdAt > $1.createdAt
        }
        .prefix(5)
    )
  }

  /// Words written per bucket across the range. Short ranges bucket by day,
  /// longer ones by week so the bars stay readable.
  private var volumePoints: [WritingVolumePoint] {
    let calendar = Calendar.current
    let byWeek: Bool
    switch range {
    case .week, .month: byWeek = false
    case .quarter, .year, .all: byWeek = true
    }

    var totals: [Date: Int] = [:]
    for note in notesInRange {
      let bucket: Date
      if byWeek {
        bucket = calendar.dateInterval(of: .weekOfYear, for: note.createdAt)?.start
          ?? calendar.startOfDay(for: note.createdAt)
      } else {
        bucket = calendar.startOfDay(for: note.createdAt)
      }
      totals[bucket, default: 0] += note.wordCount
    }

    return totals
      .map { WritingVolumePoint(day: $0.key, words: $0.value) }
      .sorted { $0.day < $1.day }
  }

  private var isEmpty: Bool { notesInRange.isEmpty }

  private var animate: Bool { !reduceMotion }

  // MARK: - Body

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DLSpace.lg) {
        EditorialHeader(L("WRITING"), L("Volume"))

        SlidingSegmentedControl(
          items: StatsRange.allCases,
          label: { $0.label },
          selection: $range,
          accent: DLColor.accent
        )
        .accessibilityLabel(L("Time range"))

        Hairline()

        if isEmpty {
          emptyState
        } else {
          headlineGrid

          Hairline()

          VStack(alignment: .leading, spacing: DLSpace.md) {
            SectionLabel(L("Words over time"))
            WritingVolumeChart(points: volumePoints, animate: animate)
          }

          Hairline()

          VStack(alignment: .leading, spacing: DLSpace.sm) {
            SectionLabel(L("Longest entries"))
            longestList
          }
        }
      }
      .padding(.horizontal, DLSpace.lg)
      .padding(.vertical, DLSpace.xl)
    }
    .background(ThemedBackground())
    .navigationBarTitleDisplayMode(.inline)
  }

  // MARK: - Sections

  private var headlineGrid: some View {
    StatTileGrid(tiles: [
      StatTileData(
        value: formatted(totalWords),
        label: L("Total words"),
        tint: DLColor.accent
      ),
      StatTileData(
        value: formatted(totalNotes),
        label: L("Total notes")
      ),
      StatTileData(
        value: formatted(avgWords),
        label: L("Avg words / note")
      ),
      StatTileData(
        value: formatted(longestWordCount),
        label: L("Longest note"),
        sublabel: L("words")
      ),
    ])
  }

  private var longestList: some View {
    VStack(spacing: 0) {
      ForEach(Array(longestNotes.enumerated()), id: \.element.id) { index, note in
        if index > 0 { Hairline() }
        HStack(alignment: .firstTextBaseline, spacing: DLSpace.md) {
          Text(rowTitle(for: note))
            .font(.dl(.body, weight: .medium))
            .foregroundStyle(DLColor.textPrimary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
          Text(Lf("%d words", note.wordCount))
            .font(.dl(.caption, weight: .semibold))
            .foregroundStyle(DLColor.textTertiary)
            .monospacedDigit()
        }
        .padding(.vertical, DLSpace.md)
      }
    }
  }

  private var emptyState: some View {
    VStack(spacing: DLSpace.sm) {
      Image(systemName: "text.alignleft")
        .font(.system(size: 32, weight: .light))
        .foregroundStyle(DLColor.textTertiary)
      Text(L("No writing in this range"))
        .font(.serif(.title3, weight: .semibold))
        .foregroundStyle(DLColor.textPrimary)
      Text(L("Notes you write will show up here."))
        .font(.dl(.subheadline))
        .foregroundStyle(DLColor.textSecondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, DLSpace.xl)
  }

  // MARK: - Helpers

  /// A trimmed title, falling back to a single-line preview of the body.
  private func rowTitle(for note: DayNote) -> String {
    let title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
    if !title.isEmpty { return title }
    let preview = note.preview
    if preview.isEmpty { return L("Untitled") }
    return preview.count > 60 ? String(preview.prefix(60)) + "…" : preview
  }

  private func formatted(_ value: Int) -> String {
    value.formatted(.number.grouping(.automatic))
  }
}

// MARK: - Chart data + view

/// Words written within one bucket (a day or a week) on the volume chart.
private struct WritingVolumePoint: Identifiable {
  let id = UUID()
  let day: Date
  let words: Int
}

/// A calm editorial bar chart of words written per bucket over the range.
private struct WritingVolumeChart: View {
  let points: [WritingVolumePoint]
  let animate: Bool

  var body: some View {
    Chart(points) { point in
      BarMark(
        x: .value("Day", point.day, unit: .day),
        y: .value("Words", point.words)
      )
      .cornerRadius(3)
      .foregroundStyle(DLColor.accent)
    }
    .chartYAxis {
      AxisMarks(position: .leading) { value in
        AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.4))
        AxisValueLabel {
          if let words = value.as(Int.self) {
            Text("\(words)")
              .font(.dl(.caption2))
              .foregroundStyle(DLColor.textSecondary)
          }
        }
      }
    }
    .chartXAxis {
      AxisMarks(values: .automatic(desiredCount: 5)) { _ in
        AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.4))
        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textSecondary)
      }
    }
    .frame(height: 190)
    .animation(animate ? DLAnim.standard : nil, value: points.map(\.words))
  }
}
