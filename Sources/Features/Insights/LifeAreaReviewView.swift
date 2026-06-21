import SwiftUI
import SwiftData
import Charts

// MARK: - Add / edit a life-area review (feature 21)

/// A form to record a 1...10 rating and free-text notes for one life area.
/// Presented as a sheet.
struct LifeAreaReviewView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @Query private var progressList: [UserProgress]

  @State private var area: LifeArea = .health
  @State private var rating = 5
  @State private var notes = ""
  @State private var date = Date()

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          // Menu style: a default-style Picker is a navigation-push row whose
          // single tap collides with the form-wide tap-to-dismiss-keyboard
          // gesture and never fires. A pop-up menu opens on the control itself.
          Picker(L("Life area"), selection: $area) {
            ForEach(LifeArea.allCases) { a in
              Label(L(a.title), systemImage: a.systemIcon).tag(a)
            }
          }
          .pickerStyle(.menu)
          .tint(theme.accent)
          DatePicker(L("Date"), selection: $date, displayedComponents: .date)
            .tint(theme.accent)
        }

        Section {
          VStack(alignment: .leading, spacing: DLSpace.sm) {
            HStack {
              Text(L("Rating"))
                .font(.dl(.body))
                .foregroundStyle(DLColor.textPrimary)
              Spacer()
              Text("\(rating)/10")
                .font(.dl(.headline, weight: .bold))
                .foregroundStyle(area.color)
                .monospacedDigit()
            }
            Slider(
              value: Binding(get: { Double(rating) }, set: { rating = Int($0.rounded()) }),
              in: 1...10,
              step: 1
            )
            .tint(area.color)
          }
        } header: {
          Text(L("How is this area going?"))
        }

        Section {
          TextField(L("What's working, what isn't?"), text: $notes, axis: .vertical)
            .lineLimit(3...10)
            .font(.dl(.body))
        } header: {
          Text(L("Notes"))
        }
      }
      .scrollContentBackground(.hidden)
      .themedBackground(theme)
      .navigationTitle(L("Weekly Review"))
      .navigationBarTitleDisplayMode(.inline)
      .keyboardDismissButton()
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(L("Cancel")) { dismiss() }.tint(theme.accent)
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button(L("Save")) { save() }
            .font(.dl(.body, weight: .semibold))
            .tint(theme.accent)
        }
      }
    }
    .presentationDetents([.large])
  }

  private func save() {
    let review = LifeAreaReview(area: area, rating: rating, notes: notes.trimmingCharacters(in: .whitespacesAndNewlines), date: date)
    context.insert(review)
    try? context.save()
    Haptics.success()
    dismiss()
  }
}

// MARK: - Life-area insights (line chart over time)

/// A line chart of life-area ratings over time, filterable by area and time range,
/// plus a list of recent reviews. Pushed from Insights (feature 21).
struct LifeAreaInsightsView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Query(sort: \LifeAreaReview.date) private var reviews: [LifeAreaReview]
  @Query private var progressList: [UserProgress]

  @State private var areaFilter: LifeArea?
  @State private var range: ReviewRange = .quarter
  @State private var showAdd = false

  private let calendar = Calendar.current
  private var today: Date { calendar.startOfDay(for: Date()) }

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  enum ReviewRange: Int, CaseIterable, Identifiable {
    case week = 7
    case month = 30
    case quarter = 90
    case year = 365
    case all = 0
    var id: Int { rawValue }
    var label: String {
      switch self {
      case .week: return L("7 days")
      case .month: return L("30 days")
      case .quarter: return L("90 days")
      case .year: return L("1 year")
      case .all: return L("All time")
      }
    }
  }

  private var rangeStart: Date? {
    guard range != .all else { return nil }
    return calendar.date(byAdding: .day, value: -(range.rawValue - 1), to: today)
  }

  private var filtered: [LifeAreaReview] {
    reviews.filter { review in
      if let areaFilter, review.area != areaFilter { return false }
      if let start = rangeStart, calendar.startOfDay(for: review.date) < start { return false }
      return true
    }
  }

  var body: some View {
    ZStack {
      ThemedBackground(theme: theme)
      if reviews.isEmpty {
        emptyState
      } else {
        content
      }
    }
    .navigationTitle(L("Life areas"))
    .navigationBarTitleDisplayMode(.inline)
    .tint(theme.accent)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button { showAdd = true } label: { Image(systemName: "plus") }
          .accessibilityLabel(L("Add review"))
      }
    }
    .sheet(isPresented: $showAdd) { LifeAreaReviewView() }
  }

  private var emptyState: some View {
    ContentUnavailableView {
      VStack(spacing: DLSpace.md) {
        EmptyGlyph(systemImage: "chart.xyaxis.line", size: 110, tint: theme.accent)
        Text(L("No reviews yet"))
          .font(.dl(.title3, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)
      }
    } description: {
      Text(L("Rate your life areas to track how they trend over time."))
    } actions: {
      Button(L("Add a review")) { showAdd = true }
        .font(.dl(.subheadline, weight: .semibold))
        .tint(theme.accent)
    }
  }

  private var content: some View {
    ScrollView {
      VStack(spacing: DLSpace.lg) {
        filtersCard
        chartCard
        listCard
      }
      .padding(DLSpace.md)
    }
  }

  private var filtersCard: some View {
    VStack(spacing: DLSpace.sm) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: DLSpace.sm) {
          areaChip(nil)
          ForEach(LifeArea.allCases) { areaChip($0) }
        }
        .padding(.horizontal, 2)
      }
      .scrollClipDisabled()

      Menu {
        Picker(L("Range"), selection: $range) {
          ForEach(ReviewRange.allCases) { Text($0.label).tag($0) }
        }
      } label: {
        HStack(spacing: 4) {
          Image(systemName: "calendar")
          Text(range.label).font(.dl(.subheadline, weight: .semibold))
          Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(theme.accent)
        .padding(.horizontal, DLSpace.md)
        .padding(.vertical, DLSpace.sm)
        .background(theme.accent.opacity(0.12), in: Capsule())
      }
    }
  }

  private func areaChip(_ area: LifeArea?) -> some View {
    let isSelected = areaFilter == area
    let color = area?.color ?? theme.accent
    return Button {
      withAnimation(reduceMotion ? nil : DLAnim.quick) { areaFilter = area }
      Haptics.selection()
    } label: {
      Text(area.map { L($0.title) } ?? L("All"))
        .font(.dl(.subheadline, weight: .semibold))
        .padding(.horizontal, DLSpace.md)
        .padding(.vertical, DLSpace.sm)
        .foregroundStyle(isSelected ? color : DLColor.textSecondary)
        .background(Capsule().fill(isSelected ? color.opacity(0.18) : DLColor.surfaceElevated.opacity(0.5)))
        .overlay(Capsule().strokeBorder(isSelected ? color : DLColor.separator.opacity(0.4), lineWidth: 1.5))
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }

  private var chartCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Label(L("Ratings over time"), systemImage: "chart.xyaxis.line")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(theme.accent)

        if filtered.isEmpty {
          Text(L("No reviews in this range."))
            .font(.dl(.caption))
            .foregroundStyle(DLColor.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DLSpace.sm)
        } else {
          chart
            .frame(height: 220)
        }
      }
    }
  }

  private var chart: some View {
    Chart(filtered) { review in
      LineMark(
        x: .value("Date", review.date, unit: .day),
        y: .value("Rating", review.rating)
      )
      .foregroundStyle(by: .value("Area", L(review.area.title)))
      .interpolationMethod(.catmullRom)
      .symbol(by: .value("Area", L(review.area.title)))
    }
    .chartForegroundStyleScale(domain: areaDomain, range: areaColors)
    .chartYScale(domain: 0...10)
    .chartYAxis {
      AxisMarks(position: .leading, values: [0, 2, 4, 6, 8, 10]) { value in
        AxisGridLine().foregroundStyle(DLColor.separator.opacity(0.4))
        AxisValueLabel {
          if let v = value.as(Int.self) {
            Text("\(v)").font(.dl(.caption2)).foregroundStyle(DLColor.textSecondary)
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
  }

  /// Areas present in the filtered set (so the legend/colors stay stable).
  private var areaDomain: [String] {
    let present = areaFilter.map { [$0] } ?? LifeArea.allCases
    return present.map { L($0.title) }
  }

  private var areaColors: [Color] {
    let present = areaFilter.map { [$0] } ?? LifeArea.allCases
    return present.map(\.color)
  }

  private var listCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Text(L("Recent reviews"))
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)
        ForEach(filtered.reversed()) { review in
          reviewRow(review)
          if review.id != filtered.first?.id {
            Divider().overlay(DLColor.separator.opacity(0.5))
          }
        }
      }
    }
  }

  private func reviewRow(_ review: LifeAreaReview) -> some View {
    HStack(alignment: .top, spacing: DLSpace.sm) {
      Image(systemName: review.area.systemIcon)
        .font(.system(size: 16))
        .foregroundStyle(review.area.color)
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 2) {
        HStack {
          Text(L(review.area.title))
            .font(.dl(.subheadline, weight: .semibold))
            .foregroundStyle(DLColor.textPrimary)
          Spacer()
          Text("\(review.rating)/10")
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
  }

  private func delete(_ review: LifeAreaReview) {
    context.delete(review)
    try? context.save()
    Haptics.warning()
  }
}
