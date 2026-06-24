import SwiftUI
import SwiftData

// MARK: - Weekly review: all life areas on one page (feature 21)

/// A single-page weekly review: every life area is rated (1...10) and annotated on
/// one screen, so the user fills everything once and saves it all together. Saving
/// upserts one `LifeAreaReview` per area for the chosen date (re-saving the same
/// day updates the existing rows instead of duplicating them). Presented as a sheet.
///
/// The analytics that used to live alongside this form (the former
/// `LifeAreaInsightsView`) were merged into `LifeAreaReportView` during the IA
/// restructure, so life areas now have a single canonical home.
struct LifeAreaReviewView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @Query private var progressList: [UserProgress]
  @Query private var existingReviews: [LifeAreaReview]

  @State private var date = Date()
  /// Reference-type draft so per-area card edits don't re-render the whole form
  /// (keeps typing smooth — feature 10). Cards write into it via `onChange`.
  @State private var draft = WeeklyReviewDraft()

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: DLSpace.md) {
          dateCard
          ForEach(LifeArea.allCases) { area in
            AreaReviewCard(area: area, draft: draft)
          }
          Text(L("Rate every area and add a note, then save them all at once."))
            .font(.dl(.caption))
            .foregroundStyle(DLColor.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DLSpace.xs)
        }
        .padding(DLSpace.md)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
      }
      .scrollContentBackground(.hidden)
      .themedBackground(theme)
      .navigationTitle(L("Weekly Review"))
      .navigationBarTitleDisplayMode(.inline)
      .scrollDismissesKeyboard(.interactively)
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

  private var dateCard: some View {
    GlassCard {
      DatePicker(L("Date"), selection: $date, displayedComponents: .date)
        .tint(theme.accent)
    }
  }

  private func save() {
    let cal = Calendar.current
    let day = cal.startOfDay(for: date)
    for area in LifeArea.allCases {
      let rating = draft.ratings[area] ?? 5
      let note = (draft.notes[area] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      // Upsert: update an existing same-area, same-day review instead of adding a
      // duplicate, so re-saving the weekly review is idempotent.
      if let existing = existingReviews.first(where: {
        $0.area == area && cal.isDate($0.date, inSameDayAs: day)
      }) {
        existing.rating = rating
        existing.notes = note
        existing.date = date
      } else {
        context.insert(LifeAreaReview(area: area, rating: rating, notes: note, date: date))
      }
    }
    try? context.save()
    Haptics.success()
    dismiss()
  }
}

// MARK: - Draft store

/// Plain reference type holding the in-progress ratings/notes. Deliberately NOT
/// observable: cards mutate it without triggering a parent re-render, so typing in
/// one area never reflows the others.
private final class WeeklyReviewDraft {
  var ratings: [LifeArea: Int]
  var notes: [LifeArea: String]
  init() {
    ratings = Dictionary(uniqueKeysWithValues: LifeArea.allCases.map { ($0, 5) })
    notes = Dictionary(uniqueKeysWithValues: LifeArea.allCases.map { ($0, "") })
  }
}

// MARK: - Per-area card

/// One life area's rating + notes. Holds its own local state so edits stay local
/// and write through to the shared draft on change (no cross-card re-renders).
private struct AreaReviewCard: View {
  let area: LifeArea
  let draft: WeeklyReviewDraft

  @State private var rating: Int
  @State private var notes: String

  init(area: LifeArea, draft: WeeklyReviewDraft) {
    self.area = area
    self.draft = draft
    _rating = State(initialValue: draft.ratings[area] ?? 5)
    _notes = State(initialValue: draft.notes[area] ?? "")
  }

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        HStack {
          Label(L(area.title), systemImage: area.systemIcon)
            .font(.dl(.headline, weight: .semibold))
            .foregroundStyle(area.color)
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

        TextField(L("What's working, what isn't?"), text: $notes, axis: .vertical)
          .lineLimit(2...6)
          .font(.dl(.body))
          .textFieldStyle(.plain)
      }
    }
    .onChange(of: rating) { _, newValue in draft.ratings[area] = newValue }
    .onChange(of: notes) { _, newValue in draft.notes[area] = newValue }
  }
}
