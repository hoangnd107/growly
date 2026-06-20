import SwiftUI

// MARK: - Editorial design components
//
// The shared vocabulary of the editorial redesign: a kicker + serif title header,
// serif section labels, hairline rules, ledger-style stat tiles, and tappable
// "report" rows. Built on the DL* tokens so they adapt to light/dark and the
// terracotta accent automatically.

/// A screen header: a small uppercase accent kicker over a large serif title,
/// with an optional trailing control.
struct EditorialHeader: View {
  let kicker: String
  let title: String
  private let trailing: AnyView?

  init(_ kicker: String, _ title: String) {
    self.kicker = kicker
    self.title = title
    self.trailing = nil
  }

  init<Trailing: View>(_ kicker: String, _ title: String, @ViewBuilder trailing: () -> Trailing) {
    self.kicker = kicker
    self.title = title
    self.trailing = AnyView(trailing())
  }

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 4) {
        Text(kicker.uppercased())
          .font(.dl(.caption2, weight: .bold))
          .tracking(1.6)
          .foregroundStyle(DLColor.accent)
        Text(title)
          .font(.serif(.largeTitle, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: DLSpace.sm)
      if let trailing { trailing }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// A serif sub-header for a section within a screen.
struct SectionLabel: View {
  let text: String
  init(_ text: String) { self.text = text }
  var body: some View {
    Text(text)
      .font(.serif(.title3, weight: .semibold))
      .foregroundStyle(DLColor.textPrimary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// A 1px editorial divider.
struct Hairline: View {
  var body: some View {
    Rectangle().fill(DLColor.separator).frame(height: 1)
  }
}

// MARK: - Stat tiles (ledger grid)

struct StatTileData: Identifiable {
  let id = UUID()
  let value: String
  let label: String
  var sublabel: String? = nil
  var tint: Color = DLColor.textPrimary
}

struct StatTile: View {
  let data: StatTileData
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(data.value)
        .font(.serif(.title, weight: .semibold))
        .foregroundStyle(data.tint)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.5)
      Text(data.label)
        .font(.dl(.caption, weight: .medium))
        .foregroundStyle(DLColor.textSecondary)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
      if let sub = data.sublabel {
        Text(sub)
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
          .lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
    .padding(DLSpace.md)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(data.label): \(data.value)")
  }
}

/// A two-column ledger of stat tiles, separated by hairlines and bordered.
struct StatTileGrid: View {
  let tiles: [StatTileData]

  private var rows: [[StatTileData]] {
    stride(from: 0, to: tiles.count, by: 2).map { Array(tiles[$0..<min($0 + 2, tiles.count)]) }
  }

  var body: some View {
    VStack(spacing: 0) {
      ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
        if index > 0 { Hairline() }
        HStack(spacing: 0) {
          ForEach(Array(row.enumerated()), id: \.offset) { col, tile in
            if col > 0 { Rectangle().fill(DLColor.separator).frame(width: 1) }
            StatTile(data: tile)
          }
          if row.count == 1 { Color.clear.frame(maxWidth: .infinity) }
        }
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: DLRadius.card, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: DLRadius.card, style: .continuous)
        .strokeBorder(DLColor.separator, lineWidth: 1)
    )
  }
}

// MARK: - Report row (dashboard link)

/// A tappable list row used in the Progress dashboard to open a detailed report.
struct ReportRow: View {
  var emoji: String? = nil
  var systemImage: String? = nil
  let title: String
  var detail: String? = nil
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: DLSpace.md) {
        if let emoji {
          Text(emoji).font(.system(size: 20)).frame(width: 26)
        } else if let systemImage {
          Image(systemName: systemImage)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(DLColor.accent)
            .frame(width: 26)
        }
        Text(title)
          .font(.dl(.body, weight: .medium))
          .foregroundStyle(DLColor.textPrimary)
        Spacer(minLength: DLSpace.sm)
        if let detail {
          Text(detail)
            .font(.dl(.caption, weight: .medium))
            .foregroundStyle(DLColor.textTertiary)
        }
        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(DLColor.textTertiary)
      }
      .padding(.vertical, DLSpace.md)
      .contentShape(Rectangle())
    }
    .buttonStyle(ScaleButtonStyle())
  }
}

// MARK: - Range filter (shared by the new analytics views)

/// A time window used by the detailed stats reports.
enum StatsRange: String, CaseIterable, Identifiable {
  case week, month, quarter, year, all
  var id: String { rawValue }

  var label: String {
    switch self {
    case .week: return L("7d")
    case .month: return L("30d")
    case .quarter: return L("90d")
    case .year: return L("Year")
    case .all: return L("All")
    }
  }

  /// The earliest day included (nil = all time).
  func startDate(now: Date = Date(), calendar: Calendar = .current) -> Date? {
    switch self {
    case .week: return calendar.date(byAdding: .day, value: -7, to: now)
    case .month: return calendar.date(byAdding: .day, value: -30, to: now)
    case .quarter: return calendar.date(byAdding: .day, value: -90, to: now)
    case .year: return calendar.date(byAdding: .day, value: -365, to: now)
    case .all: return nil
    }
  }
}
