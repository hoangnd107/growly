import SwiftUI
import SwiftData

/// Edit a past day's reflection: the Win · Mistake · Lesson · Adjustment fields,
/// mood/energy, and the morning intention. Reuses the Today building blocks so
/// editing a back-dated review feels identical to writing today's.
struct EntryEditorSheet: View {
  @Bindable var entry: Entry

  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @Query private var progressList: [UserProgress]

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: DLSpace.lg) {
          ForEach(ReflectionKind.allCases) { kind in
            ReflectionCard(kind: kind, text: bind(for: kind))
          }

          MoodEnergyCard(moodRaw: $entry.moodRaw, energy: $entry.energy)

          GlassCard {
            VStack(alignment: .leading, spacing: DLSpace.sm) {
              Label(L("Morning intention"), systemImage: "target")
                .font(.dl(.subheadline, weight: .semibold))
                .foregroundStyle(theme.accent)
              TextField(L("What's the one thing that matters?"), text: $entry.morningIntention, axis: .vertical)
                .lineLimit(1...4)
                .font(.dl(.body))
                .foregroundStyle(DLColor.textPrimary)
            }
          }
        }
        .padding(DLSpace.md)
      }
      .scrollDismissesKeyboard(.interactively)
      .themedBackground(theme)
      .navigationTitle(entry.day.formatted(.dateTime.weekday(.wide).month().day()))
      .navigationBarTitleDisplayMode(.inline)
      .tint(theme.accent)
      .keyboardDismissButton()
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(L("Cancel")) { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button(L("Save")) { save() }.fontWeight(.semibold)
        }
      }
    }
  }

  private func bind(for kind: ReflectionKind) -> Binding<String> {
    Binding(
      get: { entry.text(for: kind) },
      set: { entry.setText($0, for: kind) }
    )
  }

  private func save() {
    entry.updatedAt = Date()
    try? context.save()
    Haptics.success()
    dismiss()
  }
}
