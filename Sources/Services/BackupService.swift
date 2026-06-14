import Foundation
import SwiftData

// MARK: - Codable snapshot of the whole store

struct BackupAttachment: Codable {
  var fileName: String
  var type: String
  var order: Int
  var createdAt: Date
}

struct BackupEntry: Codable {
  var day: Date
  var createdAt: Date
  var updatedAt: Date
  var win: String
  var mistake: String
  var lesson: String
  var adjustment: String
  var adjustmentDone: Bool
  var moodRaw: Int
  var energy: Int
  var tags: [String]
  var morningIntention: String
  var xpAwarded: Int
  var attachments: [BackupAttachment]
}

struct BackupNote: Codable {
  var title: String
  var text: String
  var createdAt: Date
  var updatedAt: Date
  var pinned: Bool
  var colorHex: String?
  var tags: [String]
  var moodRaw: Int?
  var attachments: [BackupAttachment]
}

struct BackupHabitLog: Codable {
  var date: Date
  var completed: Bool
}

struct BackupHabit: Codable {
  var name: String
  var emoji: String
  var colorHex: String
  var xpValue: Int
  var sortIndex: Int
  var isArchived: Bool
  var logs: [BackupHabitLog]
}

struct BackupBadge: Codable {
  var badgeID: String
  var earnedAt: Date
}

struct BackupXP: Codable {
  var date: Date
  var amount: Int
  var reasonRaw: String
  var multiplier: Double
}

struct BackupProgress: Codable {
  var totalXP: Int
  var currentStreak: Int
  var longestStreak: Int
  var earlyReviewCount: Int
  var totalHabitCompletions: Int
  var lastReviewDay: Date?
  var growthScore: Double
  var accentColorHex: String
  var themeRaw: String
  var faceIDEnabled: Bool
  var onboarded: Bool
  var primaryGoal: String
  var unlockedThemeIDs: [String]
  var unlockedIconIDs: [String]
  var debugUnlockAll: Bool
  var languageCode: String
  var reminderEnabled: Bool
  var reminderHour: Int
  var reminderMinute: Int
}

struct BackupFile: Codable {
  var version: Int
  var exportedAt: Date
  var progress: BackupProgress?
  var entries: [BackupEntry]
  var notes: [BackupNote]
  var habits: [BackupHabit]
  var badges: [BackupBadge]
  var xp: [BackupXP]
}

// MARK: - Service

/// Writes a JSON snapshot of the entire store to Documents and restores from it.
/// SwiftData already persists across launches; this is an extra safety net the
/// user can export/restore manually (or auto-export after key changes).
@MainActor
enum BackupService {
  static var fileURL: URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("growly-backup.json")
  }

  static var backupExists: Bool {
    FileManager.default.fileExists(atPath: fileURL.path)
  }

  static var lastModified: Date? {
    (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate]) as? Date
  }

  private static var encoder: JSONEncoder {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    e.outputFormatting = [.prettyPrinted, .sortedKeys]
    return e
  }

  private static var decoder: JSONDecoder {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
  }

  @discardableResult
  static func export(context: ModelContext) -> Date? {
    do {
      let entries = try context.fetch(FetchDescriptor<Entry>())
      let notes = try context.fetch(FetchDescriptor<DayNote>())
      let habits = try context.fetch(FetchDescriptor<Habit>())
      let badges = try context.fetch(FetchDescriptor<BadgeRecord>())
      let xp = try context.fetch(FetchDescriptor<XPTransaction>())
      let progress = try context.fetch(FetchDescriptor<UserProgress>()).first

      let file = BackupFile(
        version: 1,
        exportedAt: Date(),
        progress: progress.map(snapshot(progress:)),
        entries: entries.map(snapshot(entry:)),
        notes: notes.map(snapshot(note:)),
        habits: habits.map(snapshot(habit:)),
        badges: badges.map { BackupBadge(badgeID: $0.badgeID, earnedAt: $0.earnedAt) },
        xp: xp.map { BackupXP(date: $0.date, amount: $0.amount, reasonRaw: $0.reasonRaw, multiplier: $0.multiplier) }
      )

      try encoder.encode(file).write(to: fileURL, options: .atomic)
      let now = Date()
      progress?.lastBackupAt = now
      try? context.save()
      return now
    } catch {
      return nil
    }
  }

  @discardableResult
  static func restore(context: ModelContext) -> Bool {
    guard
      let data = try? Data(contentsOf: fileURL),
      let file = try? decoder.decode(BackupFile.self, from: data)
    else { return false }

    wipe(context: context)

    for e in file.entries {
      let entry = Entry(
        day: e.day, win: e.win, mistake: e.mistake, lesson: e.lesson,
        adjustment: e.adjustment, moodRaw: e.moodRaw, energy: e.energy,
        tags: e.tags, morningIntention: e.morningIntention
      )
      entry.adjustmentDone = e.adjustmentDone
      entry.xpAwarded = e.xpAwarded
      entry.createdAt = e.createdAt
      entry.updatedAt = e.updatedAt
      context.insert(entry)
      for a in e.attachments {
        let media = MediaAttachment(fileName: a.fileName, type: MediaType(rawValue: a.type) ?? .image, order: a.order, createdAt: a.createdAt)
        media.entry = entry
        context.insert(media)
      }
    }

    for n in file.notes {
      let note = DayNote(title: n.title, text: n.text, createdAt: n.createdAt, pinned: n.pinned, colorHex: n.colorHex, tags: n.tags, moodRaw: n.moodRaw)
      note.updatedAt = n.updatedAt
      context.insert(note)
      for a in n.attachments {
        let media = MediaAttachment(fileName: a.fileName, type: MediaType(rawValue: a.type) ?? .image, order: a.order, createdAt: a.createdAt)
        media.note = note
        context.insert(media)
      }
    }

    for h in file.habits {
      let habit = Habit(name: h.name, emoji: h.emoji, colorHex: h.colorHex, xpValue: h.xpValue, sortIndex: h.sortIndex)
      habit.isArchived = h.isArchived
      context.insert(habit)
      for l in h.logs {
        context.insert(HabitLog(date: l.date, completed: l.completed, habit: habit))
      }
    }

    for b in file.badges { context.insert(BadgeRecord(badgeID: b.badgeID, earnedAt: b.earnedAt)) }
    for x in file.xp {
      context.insert(XPTransaction(amount: x.amount, reason: XPReason(rawValue: x.reasonRaw) ?? .dailyReview, multiplier: x.multiplier, date: x.date))
    }

    let progress = UserProgress()
    if let p = file.progress { apply(p, to: progress) }
    context.insert(progress)

    try? context.save()
    return true
  }

  // MARK: Snapshot helpers

  private static func snapshot(entry e: Entry) -> BackupEntry {
    BackupEntry(
      day: e.day, createdAt: e.createdAt, updatedAt: e.updatedAt,
      win: e.win, mistake: e.mistake, lesson: e.lesson, adjustment: e.adjustment,
      adjustmentDone: e.adjustmentDone, moodRaw: e.moodRaw, energy: e.energy,
      tags: e.tags, morningIntention: e.morningIntention, xpAwarded: e.xpAwarded,
      attachments: e.attachments.map(snapshot(attachment:))
    )
  }

  private static func snapshot(note n: DayNote) -> BackupNote {
    BackupNote(
      title: n.title, text: n.text, createdAt: n.createdAt, updatedAt: n.updatedAt,
      pinned: n.pinned, colorHex: n.colorHex, tags: n.tags, moodRaw: n.moodRaw,
      attachments: n.attachments.map(snapshot(attachment:))
    )
  }

  private static func snapshot(habit h: Habit) -> BackupHabit {
    BackupHabit(
      name: h.name, emoji: h.emoji, colorHex: h.colorHex, xpValue: h.xpValue,
      sortIndex: h.sortIndex, isArchived: h.isArchived,
      logs: h.logs.map { BackupHabitLog(date: $0.date, completed: $0.completed) }
    )
  }

  private static func snapshot(attachment m: MediaAttachment) -> BackupAttachment {
    BackupAttachment(fileName: m.fileName, type: m.typeRaw, order: m.order, createdAt: m.createdAt)
  }

  private static func snapshot(progress p: UserProgress) -> BackupProgress {
    BackupProgress(
      totalXP: p.totalXP, currentStreak: p.currentStreak, longestStreak: p.longestStreak,
      earlyReviewCount: p.earlyReviewCount, totalHabitCompletions: p.totalHabitCompletions,
      lastReviewDay: p.lastReviewDay, growthScore: p.growthScore,
      accentColorHex: p.accentColorHex, themeRaw: p.themeRaw, faceIDEnabled: p.faceIDEnabled,
      onboarded: p.onboarded, primaryGoal: p.primaryGoal,
      unlockedThemeIDs: p.unlockedThemeIDs, unlockedIconIDs: p.unlockedIconIDs,
      debugUnlockAll: p.debugUnlockAll, languageCode: p.languageCode,
      reminderEnabled: p.reminderEnabled, reminderHour: p.reminderHour, reminderMinute: p.reminderMinute
    )
  }

  private static func apply(_ p: BackupProgress, to up: UserProgress) {
    up.totalXP = p.totalXP
    up.currentStreak = p.currentStreak
    up.longestStreak = p.longestStreak
    up.earlyReviewCount = p.earlyReviewCount
    up.totalHabitCompletions = p.totalHabitCompletions
    up.lastReviewDay = p.lastReviewDay
    up.growthScore = p.growthScore
    up.accentColorHex = p.accentColorHex
    up.themeRaw = p.themeRaw
    up.faceIDEnabled = p.faceIDEnabled
    up.onboarded = p.onboarded
    up.primaryGoal = p.primaryGoal
    up.unlockedThemeIDs = p.unlockedThemeIDs
    up.unlockedIconIDs = p.unlockedIconIDs
    up.debugUnlockAll = p.debugUnlockAll
    up.languageCode = p.languageCode
    up.reminderEnabled = p.reminderEnabled
    up.reminderHour = p.reminderHour
    up.reminderMinute = p.reminderMinute
  }

  private static func wipe(context: ModelContext) {
    func deleteAll<T: PersistentModel>(_ type: T.Type) {
      if let items = try? context.fetch(FetchDescriptor<T>()) {
        for item in items { context.delete(item) }
      }
    }
    deleteAll(MediaAttachment.self)
    deleteAll(HabitLog.self)
    deleteAll(Entry.self)
    deleteAll(DayNote.self)
    deleteAll(Habit.self)
    deleteAll(BadgeRecord.self)
    deleteAll(XPTransaction.self)
    deleteAll(UserProgress.self)
  }
}
