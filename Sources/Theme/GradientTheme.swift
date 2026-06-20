import SwiftUI

/// A selectable gradient theme: a soft background gradient (light + dark) plus an
/// accent color. Drives the app-wide look (Settings → Themes).
struct GradientTheme: Identifiable, Hashable {
  let id: String
  let name: String
  let accentHex: UInt
  let lightStops: [UInt]
  let darkStops: [UInt]

  var accent: Color { Color(hex: accentHex) }
  var accentHexString: String { String(format: "%06X", UInt32(accentHex)) }

  func stops(_ scheme: ColorScheme) -> [Color] {
    (scheme == .dark ? darkStops : lightStops).map { Color(hex: $0) }
  }

  func background(_ scheme: ColorScheme) -> LinearGradient {
    LinearGradient(colors: stops(scheme), startPoint: .topLeading, endPoint: .bottomTrailing)
  }

  /// A subtle two-color wash for accent chips / mascot glow.
  var accentGradient: LinearGradient {
    LinearGradient(
      colors: [accent, accent.opacity(0.55)],
      startPoint: .topLeading, endPoint: .bottomTrailing
    )
  }
}

enum GradientThemeCatalog {
  static let all: [GradientTheme] = [
    GradientTheme(
      id: "clay", name: "Clay",
      accentHex: 0xB85C38,
      lightStops: [0xFAF9F6, 0xFBFAF7, 0xFFFFFF],
      darkStops: [0x0F0F10, 0x121211, 0x0A0A0A]
    ),
    GradientTheme(
      id: "teal", name: "Teal",
      accentHex: 0x00B4A6,
      lightStops: [0xE7FBF6, 0xF3FBFF, 0xFFFFFF],
      darkStops: [0x07211F, 0x0B1413, 0x0A0A0A]
    ),
    GradientTheme(
      id: "warm", name: "Warm",
      accentHex: 0xFF7849,
      lightStops: [0xFFF0E6, 0xFFF6F1, 0xFFFFFF],
      darkStops: [0x261309, 0x180D0A, 0x0A0A0A]
    ),
    GradientTheme(
      id: "purple", name: "Purple",
      accentHex: 0x7E5BEF,
      lightStops: [0xF0EBFF, 0xF6F3FF, 0xFFFFFF],
      darkStops: [0x191233, 0x100C1E, 0x0A0A0A]
    ),
    GradientTheme(
      id: "forest", name: "Forest",
      accentHex: 0x2FAE60,
      lightStops: [0xE9F8EC, 0xF3FBF4, 0xFFFFFF],
      darkStops: [0x0B2116, 0x0C1510, 0x0A0A0A]
    ),
    GradientTheme(
      id: "ocean", name: "Ocean",
      accentHex: 0x2D9CDB,
      lightStops: [0xE7F3FE, 0xF1F8FF, 0xFFFFFF],
      darkStops: [0x07182B, 0x0A1118, 0x0A0A0A]
    ),
    GradientTheme(
      id: "rose", name: "Rose",
      accentHex: 0xFF5C8A,
      lightStops: [0xFFEDF2, 0xFFF4F7, 0xFFFFFF],
      darkStops: [0x29101A, 0x1A0C12, 0x0A0A0A]
    ),
  ]

  private static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

  static func theme(id: String) -> GradientTheme {
    byID[id] ?? all[0]
  }
}
