import SwiftUI
import SwiftData

/// A full-screen personal manifesto editor (feature 22): a title, a large body
/// with simple markdown-like formatting (bold / italic / highlight via the same
/// markers used in notes), a live preview toggle, and auto-save with a "last
/// updated" stamp. A single `PersonalManifesto` row is maintained.
struct ManifestoView: View {
  @Environment(\.modelContext) private var context
  @Query private var manifestos: [PersonalManifesto]
  @Query private var progressList: [UserProgress]

  @State private var previewing = false

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  private var manifesto: PersonalManifesto? { manifestos.first }

  var body: some View {
    ZStack {
      ThemedBackground(theme: theme)
      if let manifesto {
        editor(manifesto)
      } else {
        ProgressView()
      }
    }
    .navigationTitle(L("Manifesto"))
    .navigationBarTitleDisplayMode(.inline)
    .tint(theme.accent)
    .keyboardDismissButton()
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          withAnimation(DLAnim.quick) { previewing.toggle() }
          if previewing { KeyboardHelper.dismiss() }
        } label: {
          Image(systemName: previewing ? "eye.fill" : "eye")
        }
        .accessibilityLabel(L("Preview"))
      }
    }
    .onAppear(perform: ensureManifesto)
  }

  private func editor(_ manifesto: PersonalManifesto) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DLSpace.lg) {
        GlassCard(padding: DLSpace.lg) {
          VStack(alignment: .leading, spacing: DLSpace.md) {
            TextField(L("Title"), text: title(manifesto))
              .font(.dl(.title, weight: .bold))
              .foregroundStyle(DLColor.textPrimary)
              .textInputAutocapitalization(.sentences)

            Divider().overlay(DLColor.separator)

            if previewing {
              if manifesto.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(L("Nothing to preview yet."))
                  .font(.dl(.body))
                  .foregroundStyle(DLColor.textTertiary)
                  .frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
              } else {
                MarkdownText(raw: manifesto.body)
                  .frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
                  .onTapGesture { withAnimation(DLAnim.quick) { previewing = false } }
              }
            } else {
              TextField(L("Write what you stand for…"), text: body(manifesto), axis: .vertical)
                .font(.dl(.body))
                .foregroundStyle(DLColor.textPrimary)
                .lineLimit(10...60)
                .textInputAutocapitalization(.sentences)
            }
          }
        }

        Text(Lf("Last updated %@", manifesto.updatedAt.formatted(date: .abbreviated, time: .shortened)))
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
          .frame(maxWidth: .infinity, alignment: .center)
      }
      .padding(DLSpace.md)
    }
    .scrollDismissesKeyboard(.interactively)
    .safeAreaInset(edge: .bottom) { formatBar(manifesto) }
  }

  private func formatBar(_ manifesto: PersonalManifesto) -> some View {
    HStack(spacing: DLSpace.lg) {
      formatButton(L("Bold"), systemImage: "bold") { insert("**bold**", into: manifesto) }
      formatButton(L("Italic"), systemImage: "italic") { insert("_italic_", into: manifesto) }
      formatButton(L("Highlight"), systemImage: "highlighter") { insert("==highlight==", into: manifesto) }
      formatButton(L("Bullet"), systemImage: "list.bullet") { insert("\n- ", into: manifesto) }
    }
    .padding(.horizontal, DLSpace.md)
    .padding(.vertical, DLSpace.sm)
    .glass(cornerRadius: DLRadius.pill)
    .padding(.bottom, DLSpace.sm)
    .opacity(previewing ? 0.4 : 1)
    .disabled(previewing)
  }

  private func formatButton(_ label: String, systemImage: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(theme.accent)
        .frame(width: 36, height: 32)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }

  // MARK: - Actions

  private func ensureManifesto() {
    guard manifestos.isEmpty else { return }
    context.insert(PersonalManifesto())
    try? context.save()
  }

  private func title(_ manifesto: PersonalManifesto) -> Binding<String> {
    Binding(
      get: { manifesto.title },
      set: { manifesto.title = $0; manifesto.updatedAt = Date(); try? context.save() }
    )
  }

  private func body(_ manifesto: PersonalManifesto) -> Binding<String> {
    Binding(
      get: { manifesto.body },
      set: { manifesto.body = $0; manifesto.updatedAt = Date(); try? context.save() }
    )
  }

  private func insert(_ marker: String, into manifesto: PersonalManifesto) {
    let needsSpace = !(manifesto.body.isEmpty || manifesto.body.hasSuffix(" ") || manifesto.body.hasSuffix("\n"))
    manifesto.body += (needsSpace ? " " : "") + marker + " "
    manifesto.updatedAt = Date()
    try? context.save()
    Haptics.light()
  }
}
