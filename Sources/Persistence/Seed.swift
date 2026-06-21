import Foundation
import SwiftData

@MainActor
enum Seed {
  /// Ensures a single UserProgress row and a starter set of habits exist.
  static func ensure(context: ModelContext) {
    let progressCount = (try? context.fetchCount(FetchDescriptor<UserProgress>())) ?? 0
    if progressCount == 0 {
      context.insert(UserProgress())
    }

    migrateDeprecatedAccent(context: context)

    let habitCount = (try? context.fetchCount(FetchDescriptor<Habit>())) ?? 0
    if habitCount == 0 {
      for (index, def) in defaultHabits.enumerated() {
        context.insert(Habit(name: def.name, emoji: def.emoji, colorHex: def.hex, xpValue: def.xp, sortIndex: index))
      }
    }

    try? context.save()
  }

  /// Reverts the short-lived editorial-preview default accent (terracotta "clay"
  /// / B85C38) back to the app's standard Violet so devices that ran the preview
  /// build don't stay stuck on the retired terracotta tint. Only touches rows
  /// still holding those exact preview-default values — an explicit user choice
  /// of a different colour is never overwritten.
  private static func migrateDeprecatedAccent(context: ModelContext) {
    guard let progress = try? context.fetch(FetchDescriptor<UserProgress>()).first else { return }
    var changed = false
    if progress.gradientThemeID == "clay" {
      progress.gradientThemeID = "teal"
      changed = true
    }
    if progress.accentColorHex.uppercased() == "B85C38" {
      progress.accentColorHex = "7E5BEF"
      changed = true
    }
    if changed { try? context.save() }
  }

  private struct HabitDef {
    let name: String
    let emoji: String
    let hex: String
    let xp: Int
  }

  private static let defaultHabits: [HabitDef] = [
    HabitDef(name: "Move your body", emoji: "🏃", hex: "34C759", xp: 14),
    HabitDef(name: "Read 10 pages", emoji: "📚", hex: "5AC8FA", xp: 12),
    HabitDef(name: "Meditate", emoji: "🧘", hex: "AF8CFF", xp: 12),
    HabitDef(name: "Lights out by 11", emoji: "😴", hex: "FF9F0A", xp: 10),
  ]
}
