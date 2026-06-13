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

    let habitCount = (try? context.fetchCount(FetchDescriptor<Habit>())) ?? 0
    if habitCount == 0 {
      for (index, def) in defaultHabits.enumerated() {
        context.insert(Habit(name: def.name, emoji: def.emoji, colorHex: def.hex, xpValue: def.xp, sortIndex: index))
      }
    }

    try? context.save()
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
