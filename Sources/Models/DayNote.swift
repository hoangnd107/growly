import Foundation
import SwiftData

/// A free-form note. Many notes can exist per day; the creation date is
/// user-editable so notes can be backdated.
@Model
final class DayNote {
  var id: UUID
  var title: String
  var text: String
  /// User-editable creation date — also used for day grouping/filtering.
  var createdAt: Date
  var updatedAt: Date
  var pinned: Bool
  /// Optional label color (hex, e.g. "FF9F0A").
  var colorHex: String?
  var tags: [String]
  /// Optional mood (1...5), nil when not set.
  var moodRaw: Int?

  @Relationship(deleteRule: .cascade, inverse: \MediaAttachment.note)
  var attachments: [MediaAttachment]

  init(
    title: String = "",
    text: String = "",
    createdAt: Date = Date(),
    pinned: Bool = false,
    colorHex: String? = nil,
    tags: [String] = [],
    moodRaw: Int? = nil
  ) {
    self.id = UUID()
    self.title = title
    self.text = text
    self.createdAt = createdAt
    self.updatedAt = Date()
    self.pinned = pinned
    self.colorHex = colorHex
    self.tags = tags
    self.moodRaw = moodRaw
    self.attachments = []
  }

  var day: Date { Calendar.current.startOfDay(for: createdAt) }

  var preview: String {
    text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var mood: Mood? { moodRaw.flatMap { Mood(rawValue: $0) } }

  var sortedAttachments: [MediaAttachment] {
    attachments.sorted { $0.order < $1.order }
  }
}
