import SwiftUI
import SwiftData

/// Read-only detail for a single reflection day: date, mood/energy,
/// the four reflection fields with their ReflectionKind icons/accents,
/// tags, XP earned, and an attached photo if present.
struct EntryDetailView: View {
  let entry: Entry

  var body: some View {
    ScrollView {
      VStack(spacing: DLSpace.lg) {
        moodEnergyCard

        ForEach(ReflectionKind.allCases) { kind in
          let value = entry.text(for: kind).trimmingCharacters(in: .whitespacesAndNewlines)
          if !value.isEmpty {
            reflectionCard(kind, text: value)
          }
        }

        if !entry.morningIntention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          intentionCard
        }

        if !entry.tags.isEmpty {
          tagsCard
        }

        if let data = entry.photo, let uiImage = UIImage(data: data) {
          photoCard(uiImage)
        }

        if entry.xpAwarded > 0 {
          xpCard
        }
      }
      .padding(DLSpace.md)
    }
    .background(DLColor.background.ignoresSafeArea())
    .navigationTitle(entry.day.formatted(.dateTime.weekday(.abbreviated).month().day()))
    .navigationBarTitleDisplayMode(.inline)
  }

  // MARK: - Cards

  private var moodEnergyCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Text(entry.day, format: .dateTime.weekday(.wide).month(.wide).day().year())
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)

        HStack(spacing: DLSpace.lg) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Mood")
              .font(.dl(.caption, weight: .medium))
              .foregroundStyle(DLColor.textTertiary)
            HStack(spacing: DLSpace.sm) {
              Text(entry.mood.emoji)
                .font(.system(size: 28))
              Text(entry.mood.label)
                .font(.dl(.subheadline, weight: .semibold))
                .foregroundStyle(entry.mood.color)
            }
          }

          VStack(alignment: .leading, spacing: 4) {
            Text("Energy")
              .font(.dl(.caption, weight: .medium))
              .foregroundStyle(DLColor.textTertiary)
            HStack(spacing: 4) {
              ForEach(1...5, id: \.self) { level in
                Image(systemName: level <= entry.energy ? "bolt.fill" : "bolt")
                  .font(.system(size: 13))
                  .foregroundStyle(level <= entry.energy ? DLColor.xpGold : DLColor.textTertiary)
              }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Energy \(entry.energy) of 5")
          }
        }
      }
    }
  }

  private func reflectionCard(_ kind: ReflectionKind, text: String) -> some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        HStack(spacing: DLSpace.sm) {
          ZStack {
            Circle().fill(kind.accent.opacity(0.18)).frame(width: 34, height: 34)
            Image(systemName: kind.systemIcon)
              .font(.system(size: 15, weight: .semibold))
              .foregroundStyle(kind.accent)
          }
          Text(kind.title)
            .font(.dl(.headline, weight: .semibold))
            .foregroundStyle(DLColor.textPrimary)
        }
        Text(text)
          .font(.dl(.body))
          .foregroundStyle(DLColor.textSecondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  private var intentionCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        Label("Morning intention", systemImage: "target")
          .font(.dl(.subheadline, weight: .semibold))
          .foregroundStyle(Color.accentColor)
        Text(entry.morningIntention)
          .font(.dl(.body))
          .foregroundStyle(DLColor.textSecondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  private var tagsCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        Text("Tags")
          .font(.dl(.subheadline, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)
        FlowTags(tags: entry.tags)
      }
    }
  }

  private func photoCard(_ uiImage: UIImage) -> some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        Text("Photo")
          .font(.dl(.subheadline, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)
        Image(uiImage: uiImage)
          .resizable()
          .scaledToFit()
          .frame(maxWidth: .infinity)
          .clipShape(RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous))
          .accessibilityLabel("Attached photo")
      }
    }
  }

  private var xpCard: some View {
    Label("+\(entry.xpAwarded) XP earned", systemImage: "bolt.fill")
      .font(.dl(.headline, weight: .semibold))
      .foregroundStyle(DLColor.xpGold)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 14)
      .background(DLColor.xpGold.opacity(0.12), in: RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous))
  }
}

/// A simple wrapping tag layout that lays out pill chips across available width.
private struct FlowTags: View {
  let tags: [String]

  var body: some View {
    FlowLayout(spacing: DLSpace.sm) {
      ForEach(tags, id: \.self) { tag in
        Text(tag)
          .font(.dl(.caption, weight: .medium))
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(DLColor.surfaceElevated, in: Capsule())
          .foregroundStyle(DLColor.textSecondary)
      }
    }
  }
}

/// Minimal wrapping layout (iOS 16+ `Layout`); keeps the detail screen
/// dependency-free while supporting variable-width tag chips.
private struct FlowLayout: Layout {
  var spacing: CGFloat = DLSpace.sm

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
    let maxWidth = proposal.width ?? .infinity
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    var totalWidth: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x + size.width > maxWidth, x > 0 {
        x = 0
        y += rowHeight + spacing
        rowHeight = 0
      }
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
      totalWidth = max(totalWidth, x - spacing)
    }
    return CGSize(width: min(totalWidth, maxWidth), height: y + rowHeight)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
    let maxWidth = bounds.width
    var x: CGFloat = bounds.minX
    var y: CGFloat = bounds.minY
    var rowHeight: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
        x = bounds.minX
        y += rowHeight + spacing
        rowHeight = 0
      }
      subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
  }
}
