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

  // Testing: unlock all gated content (accents, etc.) without changing progress.
  var debugUnlockAll: Bool = false

  // Localization: "system" | "en" | "vi" | "zh-Hans" | "ko"
  var languageCode: String = "system"

  // Daily reminder
  var reminderEnabled: Bool = false
  var reminderHour: Int = 21
  var reminderMinute: Int = 0

  // Local backup
  var lastBackupAt: Date? = nil

  // Personalization (v3)
  var gradientThemeID: String = "teal"
  var weekStartsMonday: Bool = true
  var miraEnabled: Bool = true

  // Streak freeze: days the streak was protected with XP (so a gap doesn't break it).
  var streakFreezeDates: [Date] = []

  // Optional custom emoji per mood level (empty = use defaults). Index 0 → level 1.
  // Legacy (v7); superseded by `moodCatalogJSON` but still read for migration.
  var moodEmojis: [String] = []

  // Customizable mood scale: JSON-encoded `[MoodOption]` (empty = built-in defaults).
  // Holds re-skinned built-ins plus any user-added custom moods.
  var moodCatalogJSON: String = ""

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
    self.themeRaw = "system"
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

  var gradientTheme: GradientTheme { GradientThemeCatalog.theme(id: gradientThemeID) }

  var levelInfo: LevelInfo { LevelSystem.levelInfo(totalXP: totalXP) }
  var streakMultiplier: Double { StreakEngine.multiplier(for: currentStreak) }
}
