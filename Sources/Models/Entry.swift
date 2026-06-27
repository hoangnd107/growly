import Foundation
import SwiftData

/// A single day's reflection: the Win · Mistake · Lesson · Adjustment loop,
/// plus mood/energy, optional photo, tags, and the next-morning fields.
@Model
final class Entry {
  /// The neutral mood/energy a day carries when nothing has been logged — also the
  /// value a bulk "clear" resets to before an otherwise-empty Entry is discarded.
  static let neutralMood = 3
  static let neutralEnergy = 3

  var id: UUID
  /// The day this entry belongs to (normalized to start of day).
  var day: Date
  var createdAt: Date
  var updatedAt: Date

  var win: String
  var mistake: String
  var lesson: String
  var adjustment: String

  /// Whether yesterday's adjustment was checked off this morning.
  var adjustmentDone: Bool

  var moodRaw: Int
  var energy: Int

  /// Legacy single photo (kept for backward compatibility); new media uses
  /// `attachments`.
  @Attribute(.externalStorage) var photo: Data?

  var tags: [String]
  var morningIntention: String
  var xpAwarded: Int

  @Relationship(deleteRule: .cascade, inverse: \MediaAttachment.entry)
  var attachments: [MediaAttachment]

  init(
    day: Date = Date(),
    win: String = "",
    mistake: String = "",
    lesson: String = "",
    adjustment: String = "",
    moodRaw: Int = 3,
    energy: Int = 3,
    tags: [String] = [],
    morningIntention: String = ""
  ) {
    self.id = UUID()
    self.day = Calendar.current.startOfDay(for: day)
    self.createdAt = Date()
    self.updatedAt = Date()
    self.win = win
    self.mistake = mistake
    self.lesson = lesson
    self.adjustment = adjustment
    self.adjustmentDone = false
    self.moodRaw = moodRaw
    self.energy = energy
    self.photo = nil
    self.tags = tags
    self.morningIntention = morningIntention
    self.xpAwarded = 0
    self.attachments = []
  }

  var sortedAttachments: [MediaAttachment] {
    attachments.sorted { $0.order < $1.order }
  }

  var mood: Mood { Mood(rawValue: moodRaw) ?? .neutral }

  /// The mood resolved against the user's customizable catalog (clamped so legacy
  /// values always render). Use this for display; `moodRaw` stays the ordinal.
  var moodOption: MoodOption {
    MoodCatalog.shared.option(forValue: moodRaw) ?? MoodCatalog.defaults[2]
  }

  func text(for kind: ReflectionKind) -> String {
    switch kind {
    case .win: return win
    case .mistake: return mistake
    case .lesson: return lesson
    case .adjustment: return adjustment
    }
  }

  func setText(_ value: String, for kind: ReflectionKind) {
    switch kind {
    case .win: win = value
    case .mistake: mistake = value
    case .lesson: lesson = value
    case .adjustment: adjustment = value
    }
  }

  var filledCount: Int {
    [win, mistake, lesson, adjustment]
      .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
      .count
  }

  var isComplete: Bool { filledCount == 4 }

  var wordCount: Int {
    [win, mistake, lesson, adjustment, morningIntention]
      .map { $0.split(whereSeparator: { $0 == " " || $0 == "\n" }).count }
      .reduce(0, +)
  }
}
