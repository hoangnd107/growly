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

  // Journal (v3)
  var bookmarked: Bool = false
  var folder: String?
  var locationName: String?
  var latitude: Double?
  var longitude: Double?

  /// When set, the note is in the Trash (soft-deleted) — restorable until purged.
  var deletedAt: Date? = nil

  /// When this note came from an external import, the `ImportSource.id` it belongs
  /// to (nil for notes created in the app). Lets a whole import be removed cleanly.
  var importSourceID: UUID? = nil

  @Relationship(deleteRule: .cascade, inverse: \MediaAttachment.note)
  var attachments: [MediaAttachment]

  /// Multiple tagged places (map-picked or current location). Additive — older
  /// notes default to an empty list and may still carry the legacy single fields
  /// above until migrated on edit.
  @Relationship(deleteRule: .cascade, inverse: \NoteLocation.note)
  var locations: [NoteLocation] = []

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

  /// Approximate word count across the title + body (for the Stats view).
  var wordCount: Int {
    (title + " " + text)
      .split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" })
      .count
  }

  /// Character count of the note body (feature 10), shown on each note row.
  var charCount: Int { text.count }

  var mood: Mood? { moodRaw.flatMap { Mood(rawValue: $0) } }

  /// The mood resolved against the user's customizable catalog (nil when unset).
  /// Use this for display; `moodRaw` stays the stored ordinal.
  var moodOption: MoodOption? {
    moodRaw.flatMap { MoodCatalog.shared.option(forValue: $0) }
  }

  var sortedAttachments: [MediaAttachment] {
    attachments.sorted { $0.order < $1.order }
  }

  var sortedLocations: [NoteLocation] {
    locations.sorted { $0.order < $1.order }
  }

  var hasLocation: Bool {
    !locations.isEmpty || locationName != nil || (latitude != nil && longitude != nil)
  }

  /// A short label for the row metadata: the first tagged place, falling back to
  /// the legacy single-location name.
  var primaryLocationName: String? {
    sortedLocations.first?.name ?? locationName
  }
}
