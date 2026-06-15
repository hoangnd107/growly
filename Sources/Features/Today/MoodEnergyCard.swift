import SwiftUI

struct MoodEnergyCard: View {
  @Binding var moodRaw: Int
  @Binding var energy: Int

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Text(L("Mood & Energy"))
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)

        HStack(spacing: DLSpace.xs) {
          ForEach(MoodCatalog.shared.options) { mood in
            Button {
              moodRaw = mood.value
              Haptics.selection()
            } label: {
              VStack(spacing: 2) {
                Text(mood.emoji)
                  .font(.system(size: moodRaw == mood.value ? 30 : 24))
                Text(mood.displayName)
                  .font(.dl(.caption2))
                  .foregroundStyle(moodRaw == mood.value ? mood.color : DLColor.textTertiary)
                  .lineLimit(1)
                  .minimumScaleFactor(0.6)
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 8)
              .background(
                moodRaw == mood.value ? mood.color.opacity(0.16) : Color.clear,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
              )
            }
            .buttonStyle(.plain)
          }
        }
        .animation(DLAnim.quick, value: moodRaw)

        HStack(spacing: DLSpace.sm) {
          Image(systemName: "bolt.fill").foregroundStyle(DLColor.xpGold)
          Slider(
            value: Binding(
              get: { Double(energy) },
              set: { energy = Int($0.rounded()) }
            ),
            in: 1...5,
            step: 1
          )
          Text("\(energy)/5")
            .font(.dl(.caption, weight: .semibold))
            .foregroundStyle(DLColor.textSecondary)
            .monospacedDigit()
        }
      }
    }
  }
}
