import Foundation
import SwiftData
import SwiftUI

/// Single-row progress/state for the user (XP, streaks, unlocks, preferences).
@Model
final class UserProgress {
  var id: UUID
  var totalXP: Int
  var currentStreak: Int
  var longestStreak: Int
  var lastReviewDay: Date?
  var earlyReviewCount: Int
  var totalHabitCompletions: Int
  var growthScore: Double

  // Preferences / unlocks
  var accentColorHex: String
  var themeRaw: String
  var faceIDEnabled: Bool
  var onboarded: Bool
  var primaryGoal: String
  var unlockedThemeIDs: [String]
  var unlockedIconIDs: [String]

  init() {
    self.id = UUID()
    self.totalXP = 0
    self.currentStreak = 0
    self.longestStreak = 0
    self.lastReviewDay = nil
    self.earlyReviewCount = 0
    self.totalHabitCompletions = 0
    self.growthScore = 0
    self.accentColorHex = "7E5BEF"
    self.themeRaw = "dark"
    self.faceIDEnabled = false
    self.onboarded = false
    self.primaryGoal = ""
    self.unlockedThemeIDs = []
    self.unlockedIconIDs = []
  }

  var theme: ThemePreference {
    get { ThemePreference(rawValue: themeRaw) ?? .dark }
    set { themeRaw = newValue.rawValue }
  }

  var accentColor: Color { Color(hexString: accentColorHex) }

  var levelInfo: LevelInfo { LevelSystem.levelInfo(totalXP: totalXP) }
  var streakMultiplier: Double { StreakEngine.multiplier(for: currentStreak) }
}
