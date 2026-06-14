import SwiftUI

/// One of the four core fields (Win / Mistake / Lesson / Adjustment).
struct ReflectionCard: View {
  let kind: ReflectionKind
  @Binding var text: String

  private var isFilled: Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        HStack(spacing: DLSpace.sm) {
          ZStack {
            Circle().fill(kind.accent.opacity(0.18)).frame(width: 34, height: 34)
            Image(systemName: kind.systemIcon)
              .font(.system(size: 15, weight: .semibold))
              .foregroundStyle(kind.accent)
          }
          VStack(alignment: .leading, spacing: 1) {
            Text(L(kind.title))
              .font(.dl(.headline, weight: .semibold))
              .foregroundStyle(DLColor.textPrimary)
            Text(L(kind.prompt))
              .font(.dl(.caption))
              .foregroundStyle(DLColor.textSecondary)
          }
          Spacer()
          if isFilled {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(kind.accent)
              .transition(.scale.combined(with: .opacity))
          }
        }

        TextField(L(kind.prompt), text: $text, axis: .vertical)
          .lineLimit(2...6)
          .font(.dl(.body))
          .foregroundStyle(DLColor.textPrimary)
          .textInputAutocapitalization(.sentences)

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: DLSpace.sm) {
            ForEach(AICoach.suggestions(for: kind), id: \.self) { suggestion in
              Button { append(suggestion) } label: {
                Text(suggestion)
                  .font(.dl(.caption, weight: .medium))
                  .padding(.horizontal, 10)
                  .padding(.vertical, 6)
                  .background(kind.accent.opacity(0.14), in: Capsule())
                  .foregroundStyle(kind.accent)
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.vertical, 2)
        }
      }
    }
    .animation(DLAnim.quick, value: isFilled)
  }

  private func append(_ suggestion: String) {
    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      text = suggestion + " "
    } else {
      text += (text.hasSuffix(" ") ? "" : " ") + suggestion + " "
    }
    Haptics.light()
  }
}
