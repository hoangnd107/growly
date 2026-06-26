import Foundation
import SwiftData

/// Reset data by category (with a backup warning surfaced in the UI). Personal
/// app — everything is the user's to clear.
@MainActor
enum ResetService {
  enum Kind: String, CaseIterable, Identifiable {
    case entries
    case notes
    case habits
    case sleep
    case goals
    case finance
    case badges
    case progress
    case everything

    var id: String { rawValue }

    var title: String {
      switch self {
      case .entries: return L("Reflections")
      case .notes: return L("Notes")
      case .habits: return L("Habits")
      case .sleep: return L("Sleep logs")
      case .goals: return L("Goals")
      case .finance: return L("Finances")
      case .badges: return L("Badges")
      case .progress: return L("XP & streak")
      case .everything: return L("Everything")
      }
    }

    var systemImage: String {
      switch self {
      case .entries: return "sun.max"
      case .notes: return "note.text"
      case .habits: return "checkmark.circle"
      case .sleep: return "bed.double"
      case .goals: return "target"
      case .finance: return "creditcard"
      case .badges: return "rosette"
      case .progress: return "bolt"
      case .everything: return "trash"
      }
    }
  }

  static func reset(_ kind: Kind, context: ModelContext) {
    switch kind {
    case .entries:
      deleteMediaFiles(for: FetchDescriptor<Entry>(), context: context) { $0.attachments }
      deleteAll(Entry.self, context: context)
    case .notes:
      deleteMediaFiles(for: FetchDescriptor<DayNote>(), context: context) { $0.attachments }
      deleteAll(DayNote.self, context: context)
    case .habits:
      deleteAll(HabitLog.self, context: context)
      deleteAll(Habit.self, context: context)
    case .sleep:
      deleteAll(SleepLog.self, context: context)
    case .goals:
      deleteAll(SmartGoal.self, context: context)
    case .finance:
      deleteMediaFiles(for: FetchDescriptor<FinanceTransaction>(), context: context) { $0.attachments }
      deleteAll(FinanceTransaction.self, context: context)
      deleteAll(FinanceCategory.self, context: context)
    case .badges:
      deleteAll(BadgeRecord.self, context: context)
    case .progress:
      deleteAll(XPTransaction.self, context: context)
      resetProgressCounters(context: context)
    case .everything:
      for k in Kind.allCases where k != .everything { reset(k, context: context) }
    }

    // Badges are derived from entries, habits, streak and level. When any of
    // those are cleared, re-evaluate so milestones that no longer hold (e.g. a
    // 7-day streak badge after resetting the streak) are revoked too.
    switch kind {
    case .entries, .habits, .progress:
      recomputeBadges(context: context)
    default:
      break
    }

    try? context.save()
  }

  /// Removes badge records that are no longer earned given the current data.
  private static func recomputeBadges(context: ModelContext) {
    guard let progress = try? context.fetch(FetchDescriptor<UserProgress>()).first else { return }
    let entries = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
    let level = LevelSystem.levelInfo(totalXP: progress.totalXP).level
    let stats = GamificationService.computeStats(progress: progress, allEntries: entries, level: level)
    let earned = BadgeEngine.earnedBadgeIDs(stats)
    if let records = try? context.fetch(FetchDescriptor<BadgeRecord>()) {
      for record in records where !earned.contains(record.badgeID) {
        context.delete(record)
      }
    }
  }

  private static func deleteAll<T: PersistentModel>(_ type: T.Type, context: ModelContext) {
    if let items = try? context.fetch(FetchDescriptor<T>()) {
      for item in items { context.delete(item) }
    }
  }

  /// Removes media binaries from disk for items being deleted, to avoid orphans.
  private static func deleteMediaFiles<T: PersistentModel>(
    for descriptor: FetchDescriptor<T>,
    context: ModelContext,
    attachments: (T) -> [MediaAttachment]
  ) {
    if let items = try? context.fetch(descriptor) {
      for item in items {
        for media in attachments(item) { MediaStore.delete(media.fileName) }
      }
    }
  }

  private static func resetProgressCounters(context: ModelContext) {
    guard let progress = try? context.fetch(FetchDescriptor<UserProgress>()).first else { return }
    progress.totalXP = 0
    progress.currentStreak = 0
    progress.longestStreak = 0
    progress.growthScore = 0
    progress.earlyReviewCount = 0
    progress.totalHabitCompletions = 0
    progress.lastReviewDay = nil
    progress.streakFreezeDates = []
    // Preferences (theme, language, accent, Face ID, onboarding) are preserved.
  }
}
