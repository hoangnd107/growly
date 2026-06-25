import SwiftUI
import UIKit

// MARK: - Color helpers

extension Color {
  /// Create a Color from a 0xRRGGBB hex value.
  init(hex: UInt) {
    let r = Double((hex >> 16) & 0xFF) / 255.0
    let g = Double((hex >> 8) & 0xFF) / 255.0
    let b = Double(hex & 0xFF) / 255.0
    self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
  }

  /// Create a Color from a hex string like "7E5BEF" (alpha optional "AARRGGBB").
  init(hexString: String, fallback: UInt = 0x7E5BEF) {
    let cleaned = hexString.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
    self.init(hex: UInt(cleaned, radix: 16) ?? fallback)
  }

  /// A color that adapts to light/dark appearance.
  init(lightHex: UInt, darkHex: UInt) {
    self = Color(UIColor { trait in
      trait.userInterfaceStyle == .dark ? UIColor(Color(hex: darkHex)) : UIColor(Color(hex: lightHex))
    })
  }
}

// MARK: - Semantic palette (dark-first)

enum DLColor {
  // Editorial paper palette — warm, low-contrast, adaptive light/dark.
  static let background = Color(lightHex: 0xFAF9F6, darkHex: 0x0F0F10)
  static let surface = Color(lightHex: 0xFFFFFF, darkHex: 0x171716)
  static let surfaceElevated = Color(lightHex: 0xFBFAF7, darkHex: 0x1E1E1C)
  static let textPrimary = Color(lightHex: 0x1A1815, darkHex: 0xF1EEE7)
  static let textSecondary = Color(lightHex: 0x6B665E, darkHex: 0xA8A296)
  static let textTertiary = Color(lightHex: 0xA39C90, darkHex: 0x6E685D)
  static let separator = Color(lightHex: 0xE7E3DB, darkHex: 0x2A2823)
  // Track / "empty" fill for progress rings, bars, grid lines, and unfilled
  // heatmap cells. Deliberately lighter than `separator` in dark mode so these
  // "no data / not reached yet" elements stay clearly visible against the near-
  // black background instead of blending in.
  static let track = Color(lightHex: 0xDCD6CA, darkHex: 0x3C3A33)

  // App accent — the pre-redesign default Violet, matching `progress.accentColor`.
  static let accent = Color(hex: 0x7E5BEF)
  static let accentSoft = Color(lightHex: 0xEFEAFF, darkHex: 0x241B3A)

  // Semantic / gamification — the vibrant v1.12.0 item colors restored (item 1).
  // Only these data/gamification hues return to v1.12.0; the editorial paper
  // neutrals above and the Violet accent stay.
  static let xpGold = Color(hex: 0xFFC83D)
  static let streakStart = Color(hex: 0xFF9A3D)
  static let streakEnd = Color(hex: 0xFF3D5A)
  static let success = Color(hex: 0x34C759)
  static let warning = Color(hex: 0xFF9F0A)
  static let cool = Color(lightHex: 0x3E6587, darkHex: 0x6C9AC4)
}

// MARK: - Spacing / radius / animation tokens

enum DLSpace {
  static let xs: CGFloat = 4
  static let sm: CGFloat = 8
  static let md: CGFloat = 16
  static let lg: CGFloat = 24
  static let xl: CGFloat = 32
  static let xxl: CGFloat = 48
}

enum DLRadius {
  static let small: CGFloat = 12
  static let card: CGFloat = 18
  static let pill: CGFloat = 999
}

enum DLAnim {
  static let quick = Animation.easeOut(duration: 0.2)
  static let standard = Animation.spring(response: 0.42, dampingFraction: 0.82)
  static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.66)
}

// MARK: - Typography (rounded, premium feel)

extension Font {
  /// Body / UI face — rounded system font, unified across the whole app.
  static func dl(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
    .system(style, design: .rounded).weight(weight)
  }

  /// Display face for editorial headers, dates, and big numbers. Unified to the
  /// same rounded system font as `dl` so typography is consistent app-wide.
  static func serif(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
    .system(style, design: .rounded).weight(weight)
  }
}
