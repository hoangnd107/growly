import SwiftUI
import SwiftData
import Charts

// MARK: - Life-area report (radar + trends)

/// An editorial analytics screen for life-area reviews: a custom radar chart of
/// the latest rating per area, a ledger of per-area bars, and a Swift Charts
/// trend of ratings over time. Self-contained — fetches its own data via
/// `@Query` so it can be pushed as `LifeAreaReportView()` from a NavigationLink.
///
/// Distinct from `LifeAreaReviewView` (the add/edit form). Do not confuse.
struct LifeAreaReportView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.modelContext) private var context
  @Query(sort: \LifeAreaReview.date) private var reviews: [LifeAreaReview]

  @State private var range: StatsRange = .quarter
  @State private var showAdd = false

  /// The rating scale max (model uses a 1...10 slider).
  private let ratingMax = 10

  private let calendar = Calendar.current

  // MARK: Derived data

  /// Reviews within the selected range.
  private var filtered: [LifeAreaReview] {
    guard let start = range.startDate(now: Date(), calendar: calendar) else { return reviews }
    let startDay = calendar.startOfDay(for: start)
    return reviews.filter { calendar.startOfDay(for: $0.date) >= startDay }
  }

  /// The most recent review for each area within the range (sorted newest last,
  /// so `last` wins).
  private var latestByArea: [LifeArea: LifeAreaReview] {
    var map: [LifeArea: LifeAreaReview] = [:]
    for review in filtered { map[review.area] = review }
    return map
  }

  /// Areas with at least one review in range, in canonical order.
  private var ratedAreas: [LifeArea] {
    LifeArea.allCases.filter { latestByArea[$0] != nil }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DLSpace.lg) {
        EditorialHeader("LIFE AREAS", L("Balance Report"))

        rangeControl

        if filtered.isEmpty {
          emptyState
        } else {
          Hairline()
          summaryGrid

          Hairline()
          SectionLabel(L("Balance"))
          radarSection

          Hairline()
          SectionLabel(L("By area"))
          perAreaRows

          Hairline()
          SectionLabel(L("Trend"))
          trendSection

          Hairline()
          SectionLabel(L("Recent reviews"))
          recentReviewsSection
        }
      }
      .padding(DLSpace.md)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(ThemedBackground())
    .navigationTitle(L("Life areas"))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button { showAdd = true } label: { Image(systemName: "plus") }
          .accessibilityLabel(L("Add review"))
      }
    }
    .sheet(isPresented: $showAdd) { LifeAreaReviewView() }
  }

  // MARK: Recent reviews (add/manage — merged from the former Life Areas insights view)

  private var recentReviewsSection: some View {
    GlassCard {
      VStack(spacing: DLSpace.md) {
        ForEach(Array(filtered.reversed().enumerated()), id: \.element.id) { index, review in
          if index > 0 { Hairline() }
          recentReviewRow(review)
        }
      }
    }
  }

  private func recentReviewRow(_ review: LifeAreaReview) -> some View {
    HStack(alignment: .top, spacing: DLSpace.md) {
      ZStack {
        Circle().fill(review.area.color.opacity(0.16)).frame(width: 36, height: 36)
        Image(systemName: review.area.systemIcon)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(review.area.color)
      }
      VStack(alignment: .leading, spacing: 2) {
        HStack {
          Text(L(review.area.title))
            .font(.dl(.subheadline, weight: .semibold))
            .foregroundStyle(DLColor.textPrimary)
          Spacer()
          Text("\(review.rating)/\(ratingMax)")
            .font(.dl(.subheadline, weight: .bold))
            .foregroundStyle(review.area.color)
            .monospacedDigit()
          Button { delete(review) } label: {
            Image(systemName: "trash")
              .font(.system(size: 13))
              .foregroundStyle(DLColor.textTertiary)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(L("Delete review"))
        }
        Text(review.date, format: .dateTime.month().day().year())
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
        if !review.notes.isEmpty {
          Text(review.notes)
            .font(.dl(.caption))
            .foregroundStyle(DLColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .padding(.vertical, 2)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(L(review.area.title)): \(review.rating)/\(ratingMax)")
  }

  private func delete(_ review: LifeAreaReview) {
    context.delete(review)
    try? context.save()
    Haptics.warning()
  }

  // MARK: Range filter

  private var rangeControl: some View {
    SlidingSegmentedControl(
      items: StatsRange.allCases,
      label: { $0.label },
      selection: $range,
      accent: DLColor.accent
    )
  }

  // MARK: Summary ledger

  private var summaryGrid: some View {
    let latest = latestByArea.values.map(\.rating)
    let avg = latest.isEmpty ? 0 : Double(latest.reduce(0, +)) / Double(latest.count)
    let top = latestByArea.max { $0.value.rating < $1.value.rating }?.key
    let low = latestByArea.min { $0.value.rating < $1.value.rating }?.key

    let tiles: [StatTileData] = [
      StatTileData(
        value: String(format: "%.1f", avg),
        label: L("Avg rating"),
        sublabel: Lf("of %d", ratingMax)
      ),
      StatTileData(
        value: "\(ratedAreas.count)",
        label: L("Areas rated"),
        sublabel: Lf("of %d", LifeArea.allCases.count)
      ),
      StatTileData(
        value: top.map { "\(latestByArea[$0]!.rating)" } ?? "—",
        label: L("Strongest"),
        sublabel: top.map { L($0.title) },
        tint: top?.color ?? DLColor.textPrimary
      ),
      StatTileData(
        value: low.map { "\(latestByArea[$0]!.rating)" } ?? "—",
        label: L("Needs focus"),
        sublabel: low.map { L($0.title) },
        tint: low?.color ?? DLColor.warning
      )
    ]
    return StatTileGrid(tiles: tiles)
  }

  // MARK: Radar

  private var radarSection: some View {
    GlassCard {
      VStack(spacing: DLSpace.md) {
        RadarChart(
          axes: LifeArea.allCases,
          value: { latestByArea[$0].map { Double($0.rating) } ?? 0 },
          axisLabel: { L($0.title) },
          maxValue: Double(ratingMax)
        )
        .frame(height: 260)
        .frame(maxWidth: .infinity)

        Text(Lf("Latest rating per area, on a %d-point scale.", ratingMax))
          .font(.dl(.caption))
          .foregroundStyle(DLColor.textTertiary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  // MARK: Per-area bars

  private var perAreaRows: some View {
    VStack(spacing: 0) {
      ForEach(Array(LifeArea.allCases.enumerated()), id: \.element.id) { index, area in
        if index > 0 { Hairline() }
        areaRow(area)
      }
    }
  }

  private func areaRow(_ area: LifeArea) -> some View {
    let rating = latestByArea[area]?.rating
    let fraction = rating.map { Double($0) / Double(ratingMax) } ?? 0

    return HStack(spacing: DLSpace.md) {
      Image(systemName: area.systemIcon)
        .font(.system(size: 16))
        .foregroundStyle(area.color)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(L(area.title))
            .font(.dl(.subheadline, weight: .semibold))
            .foregroundStyle(DLColor.textPrimary)
          Spacer()
          Text(rating.map { "\($0)/\(ratingMax)" } ?? L("—"))
            .font(.dl(.subheadline, weight: .bold))
            .foregroundStyle(rating == nil ? DLColor.textTertiary : area.color)
            .monospacedDigit()
        }

        GeometryReader { geo in
          ZStack(alignment: .leading) {
            Capsule()
              .fill(DLColor.track)
              .frame(height: 6)
            Capsule()
              .fill(area.color)
              .frame(width: max(0, geo.size.width * fraction), height: 6)
          }
        }
        .frame(height: 6)
      }
    }
    .padding(.vertical, DLSpace.sm)
  }

  // MARK: Trend

  private var trendSection: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Chart(filtered) { review in
          LineMark(
            x: .value("Date", review.date, unit: .day),
            y: .value("Rating", review.rating)
          )
          .interpolationMethod(.catmullRom)
          .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
          .foregroundStyle(by: .value("Area", L(review.area.title)))
          .symbol(by: .value("Area", L(review.area.title)))
        }
        .chartForegroundStyleScale(
          domain: LifeArea.allCases.map { L($0.title) },
          range: LifeArea.allCases.map(\.color)
        )
        .chartYScale(domain: 0...Double(ratingMax))
        .chartYAxis {
          AxisMarks(position: .leading, values: [0, 2, 4, 6, 8, 10]) { value in
            AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.4))
            AxisValueLabel {
              if let v = value.as(Int.self) {
                Text("\(v)")
                  .font(.dl(.caption2))
                  .foregroundStyle(DLColor.textSecondary)
              }
            }
          }
        }
        .chartXAxis {
          AxisMarks(values: .automatic(desiredCount: 4)) { _ in
            AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.3))
            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
              .font(.dl(.caption2))
              .foregroundStyle(DLColor.textSecondary)
          }
        }
        .chartLegend(position: .bottom, spacing: DLSpace.sm)
        .frame(height: 200)
        .animation(reduceMotion ? nil : DLAnim.standard, value: filtered.count)
      }
    }
  }

  // MARK: Empty state

  private var emptyState: some View {
    VStack(spacing: DLSpace.md) {
      Image(systemName: "chart.dots.scatter")
        .font(.system(size: 52, weight: .light))
        .foregroundStyle(DLColor.accent.opacity(0.7))
      Text(L("No reviews yet"))
        .font(.serif(.title3, weight: .semibold))
        .foregroundStyle(DLColor.textPrimary)
      Text(L("Rate your life areas to see your balance and how it trends over time."))
        .font(.dl(.subheadline))
        .foregroundStyle(DLColor.textSecondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, DLSpace.xl)
  }
}

// MARK: - Radar chart (custom; Swift Charts has no radar mark)

/// A regular-polygon radar plot with one axis per element of `axes`. Values are
/// normalized against `maxValue`. Calm editorial styling: soft accent fill, thin
/// accent stroke, muted grid rings and spokes, caption2 axis labels.
private struct RadarChart<Axis: Hashable & Identifiable>: View {
  let axes: [Axis]
  /// Raw value for an axis (0...maxValue).
  let value: (Axis) -> Double
  let axisLabel: (Axis) -> String
  let maxValue: Double

  /// Concentric grid rings to draw (as fractions of the radius).
  private let rings: [CGFloat] = [0.25, 0.5, 0.75, 1.0]

  var body: some View {
    GeometryReader { geo in
      let count = axes.count
      let size = min(geo.size.width, geo.size.height)
      let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
      // Leave room for the outer labels.
      let radius = (size / 2) - 28

      ZStack {
        if count >= 3 {
          // Grid rings.
          ForEach(Array(rings.enumerated()), id: \.offset) { _, ring in
            polygonPath(count: count, center: center, radius: radius * ring)
              .stroke(DLColor.track, lineWidth: 1)
          }

          // Spokes from center to each vertex.
          Path { path in
            for i in 0..<count {
              path.move(to: center)
              path.addLine(to: vertex(index: i, count: count, center: center, radius: radius))
            }
          }
          .stroke(DLColor.track, lineWidth: 1)

          // Data polygon.
          dataPath(count: count, center: center, radius: radius)
            .fill(DLColor.accent.opacity(0.2))
          dataPath(count: count, center: center, radius: radius)
            .stroke(DLColor.accent, lineWidth: 1.5)

          // Vertex dots.
          ForEach(Array(axes.enumerated()), id: \.element.id) { i, axis in
            let frac = clampedFraction(value(axis))
            let p = vertex(index: i, count: count, center: center, radius: radius * CGFloat(frac))
            Circle()
              .fill(DLColor.accent)
              .frame(width: 5, height: 5)
              .position(p)
          }

          // Axis labels at the outer edge.
          ForEach(Array(axes.enumerated()), id: \.element.id) { i, axis in
            let p = vertex(index: i, count: count, center: center, radius: radius + 16)
            Text(axisLabel(axis))
              .font(.dl(.caption2, weight: .medium))
              .foregroundStyle(DLColor.textSecondary)
              .fixedSize()
              .position(p)
          }
        } else {
          Text(L("Add reviews in at least 3 areas to see the radar."))
            .font(.dl(.caption))
            .foregroundStyle(DLColor.textTertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
  }

  // MARK: Geometry

  /// The point for axis `index`, starting at the top (12 o'clock) and going
  /// clockwise.
  private func vertex(index: Int, count: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
    let angle = (Double(index) / Double(count)) * 2 * .pi - (.pi / 2)
    return CGPoint(
      x: center.x + radius * CGFloat(cos(angle)),
      y: center.y + radius * CGFloat(sin(angle))
    )
  }

  private func clampedFraction(_ raw: Double) -> Double {
    guard maxValue > 0 else { return 0 }
    return min(1, max(0, raw / maxValue))
  }

  private func polygonPath(count: Int, center: CGPoint, radius: CGFloat) -> Path {
    Path { path in
      for i in 0..<count {
        let p = vertex(index: i, count: count, center: center, radius: radius)
        if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
      }
      path.closeSubpath()
    }
  }

  private func dataPath(count: Int, center: CGPoint, radius: CGFloat) -> Path {
    Path { path in
      for (i, axis) in axes.enumerated() {
        let frac = clampedFraction(value(axis))
        let p = vertex(index: i, count: count, center: center, radius: radius * CGFloat(frac))
        if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
      }
      path.closeSubpath()
    }
  }
}
