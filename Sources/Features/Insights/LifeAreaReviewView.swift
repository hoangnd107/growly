import SwiftUI
import SwiftData

// MARK: - Add / edit a life-area review (feature 21)

/// A form to record a 1...10 rating and free-text notes for one life area.
/// Presented as a sheet.
///
/// The analytics that used to live alongside this form (the former
/// `LifeAreaInsightsView`) were merged into `LifeAreaReportView` during the IA
/// restructure, so life areas now have a single canonical home.
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
