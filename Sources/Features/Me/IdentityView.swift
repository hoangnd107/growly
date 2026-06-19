import SwiftUI
import SwiftData

/// Editor for the person the user wants to become (feature 20): a vision
/// statement, core values (chips), and a detailed description. A single `Identity`
/// row is maintained — created lazily on first appearance.
struct IdentityView: View {
  @Environment(\.modelContext) private var context
  @Query private var identities: [Identity]
  @Query private var progressList: [UserProgress]

  @State private var newValue = ""

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  private var identity: Identity? { identities.first }

  var body: some View {
    ZStack {
      ThemedBackground(theme: theme)
      if let identity {
        form(identity)
      } else {
        ProgressView()
      }
    }
    .navigationTitle(L("Identity"))
    .navigationBarTitleDisplayMode(.inline)
    .tint(theme.accent)
    .keyboardDismissButton()
    .onAppear(perform: ensureIdentity)
  }

  private func form(_ identity: Identity) -> some View {
    ScrollView {
      VStack(spacing: DLSpace.lg) {
        visionCard(identity)
        valuesCard(identity)
        detailCard(identity)
      }
      .padding(DLSpace.md)
    }
    .scrollDismissesKeyboard(.interactively)
  }

  private func visionCard(_ identity: Identity) -> some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        Label(L("I want to become…"), systemImage: "sparkles")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(theme.accent)
        TextField(L("e.g. A calm, focused, healthy person"),
                  text: binding(\.visionStatement, on: identity), axis: .vertical)
          .lineLimit(1...4)
          .font(.dl(.body))
          .foregroundStyle(DLColor.textPrimary)
      }
    }
  }

  private func valuesCard(_ identity: Identity) -> some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        Label(L("Core values"), systemImage: "heart.text.square.fill")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(theme.accent)

        if !identity.coreValues.isEmpty {
          FlowChips(values: identity.coreValues, tint: theme.accent) { value in
            removeValue(value, from: identity)
          }
        }

        HStack {
          Image(systemName: "plus.circle").foregroundStyle(DLColor.textTertiary)
          TextField(L("Add a value"), text: $newValue)
            .font(.dl(.body))
            .onSubmit { addValue(to: identity) }
          if !newValue.trimmingCharacters(in: .whitespaces).isEmpty {
            Button(L("Add")) { addValue(to: identity) }
              .font(.dl(.caption, weight: .semibold))
              .foregroundStyle(theme.accent)
          }
        }
      }
    }
  }

  private func detailCard(_ identity: Identity) -> some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        Label(L("Description"), systemImage: "text.alignleft")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(theme.accent)
        TextField(L("Describe this person in detail — how they think, act, and show up."),
                  text: binding(\.detail, on: identity), axis: .vertical)
          .lineLimit(4...20)
          .font(.dl(.body))
          .foregroundStyle(DLColor.textPrimary)
      }
    }
  }

  // MARK: - Actions

  private func ensureIdentity() {
    guard identities.isEmpty else { return }
    context.insert(Identity())
    try? context.save()
  }

  private func binding(_ keyPath: ReferenceWritableKeyPath<Identity, String>, on identity: Identity) -> Binding<String> {
    Binding(
      get: { identity[keyPath: keyPath] },
      set: { identity[keyPath: keyPath] = $0; identity.updatedAt = Date(); try? context.save() }
    )
  }

  private func addValue(to identity: Identity) {
    let value = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty, !identity.coreValues.contains(value) else { newValue = ""; return }
    identity.coreValues.append(value)
    identity.updatedAt = Date()
    newValue = ""
    try? context.save()
    Haptics.light()
  }

  private func removeValue(_ value: String, from identity: Identity) {
    identity.coreValues.removeAll { $0 == value }
    identity.updatedAt = Date()
    try? context.save()
    Haptics.selection()
  }
}

/// A simple wrapping chip row for short string values, each removable.
struct FlowChips: View {
  let values: [String]
  let tint: Color
  let onRemove: (String) -> Void

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: DLSpace.sm) {
        ForEach(values, id: \.self) { value in
          HStack(spacing: 4) {
            Text(value).font(.dl(.caption, weight: .medium))
            Button { onRemove(value) } label: {
              Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(tint.opacity(0.14), in: Capsule())
          .foregroundStyle(tint)
        }
      }
      .padding(.vertical, 2)
    }
    .scrollClipDisabled()
  }
}

/// A compact identity reminder card used at the top of Today / Me. Tapping pushes
/// the editor when wrapped in a `NavigationLink`.
struct IdentityReminderCard: View {
  let identity: Identity
  let accent: Color

  var body: some View {
    GlassCard {
      HStack(spacing: DLSpace.md) {
        ZStack {
          Circle().fill(accent.opacity(0.18)).frame(width: 44, height: 44)
          Image(systemName: "figure.mind.and.body")
            .font(.system(size: 18))
            .foregroundStyle(accent)
        }
        VStack(alignment: .leading, spacing: 2) {
          Text(L("Becoming"))
            .font(.dl(.caption, weight: .medium))
            .foregroundStyle(DLColor.textSecondary)
            .textCase(.uppercase)
          Text(identity.visionStatement)
            .font(.dl(.subheadline, weight: .semibold))
            .foregroundStyle(DLColor.textPrimary)
            .lineLimit(2)
        }
        Spacer(minLength: 0)
      }
    }
  }
}
