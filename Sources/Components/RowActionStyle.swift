import SwiftUI

/// Canonical color + icon for the common row actions, so edit / delete / bookmark
/// / pin (and the related reuse / archive / date) look identical everywhere they
/// appear — swipe actions, context menus, batch bars, and status badges. The four
/// core actions are deliberately distinct colors (round 6, item 2).
enum RowAction {
  case edit
  case delete
  case bookmark
  case pin
  case reuse
  case archive
  case date

  /// The action's signature color — distinct across the set.
  var color: Color {
    switch self {
    case .edit:     return Color(hex: 0x0A84FF) // blue
    case .delete:   return DLColor.streakEnd    // red
    case .bookmark: return Color(hex: 0xAF52DE) // purple
    case .pin:      return DLColor.xpGold       // gold
    case .reuse:    return DLColor.success      // green
    case .archive:  return Color(hex: 0x30B0C7) // teal
    case .date:     return Color(hex: 0x30B0C7) // teal
    }
  }

  /// The action's default SF Symbol (the "on"/primary state).
  var icon: String {
    switch self {
    case .edit:     return "pencil"
    case .delete:   return "trash"
    case .bookmark: return "bookmark"
    case .pin:      return "pin"
    case .reuse:    return "arrow.counterclockwise"
    case .archive:  return "archivebox"
    case .date:     return "calendar"
    }
  }
}
