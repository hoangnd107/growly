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
  static let background = Color(lightHex: 0xF6F6F8, darkHex: 0x0A0A0A)
  static let surface = Color(lightHex: 0xFFFFFF, darkHex: 0x161618)
  static let surfaceElevated = Color(lightHex: 0xFFFFFF, darkHex: 0x202024)
  static let textPrimary = Color(lightHex: 0x0B0B0C, darkHex: 0xF4F4F6)
  static let textSecondary = Color(lightHex: 0x6A6A70, darkHex: 0x9B9BA2)
  static let textTertiary = Color(lightHex: 0x9A9AA0, darkHex: 0x6E6E76)
  static let separator = Color(lightHex: 0xE6E6EB, darkHex: 0x2A2A30)

  // Gamification accents
  static let xpGold = Color(hex: 0xFFC83D)
  static let streakStart = Color(hex: 0xFF9A3D)
  static let streakEnd = Color(hex: 0xFF3D5A)
  static let success = Color(hex: 0x34C759)
  static let warning = Color(hex: 0xFF9F0A)
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
  static let small: CGFloat = 14
  static let card: CGFloat = 24
  static let pill: CGFloat = 999
}

enum DLAnim {
  static let quick = Animation.easeOut(duration: 0.2)
  static let standard = Animation.spring(response: 0.42, dampingFraction: 0.82)
  static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.66)
}

// MARK: - Typography (rounded, premium feel)

extension Font {
  static func dl(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
    .system(style, design: .rounded).weight(weight)
  }
}
