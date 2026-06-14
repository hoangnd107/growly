import Foundation

struct LevelInfo: Equatable {
  let level: Int
  let xpIntoLevel: Int
  let xpForNextLevel: Int

  var progress: Double {
    guard xpForNextLevel > 0 else { return 1 }
    return min(1, max(0, Double(xpIntoLevel) / Double(xpForNextLevel)))
  }
}

/// Maps total XP to a level. Each level costs a little more than the last, so
/// early levels feel fast and later ones feel earned.
enum LevelSystem {
  /// XP required to advance from (level-1) to `level`. Level 1 begins at 0 XP.
  static func requirement(toReach level: Int) -> Int {
    guard level > 1 else { return 0 }
    return 100 + (level - 2) * 25
  }

  static func levelInfo(totalXP: Int) -> LevelInfo {
    var level = 1
    var remaining = max(0, totalXP)
    while true {
      let need = requirement(toReach: level + 1)
      if remaining >= need {
        remaining -= need
        level += 1
      } else {
        return LevelInfo(level: level, xpIntoLevel: remaining, xpForNextLevel: need)
      }
    }
  }

  /// A friendly rank title that changes every few levels.
  static func title(for level: Int) -> String {
    switch level {
    case ..<3: return "Spark"
    case 3..<6: return "Kindling"
    case 6..<10: return "Glow"
    case 10..<15: return "Ember"
    case 15..<25: return "Flame"
    case 25..<40: return "Beacon"
    default: return "Wildfire"
    }
  }
}
