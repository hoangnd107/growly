import Foundation
import SwiftData

/// A record of one batch of notes imported from an external source (e.g. an Apple
/// Journal export). Notes created by an import carry this record's `id` in
/// `DayNote.importSourceID`, so an entire import can be removed later without
/// touching the user's own notes or other imports. Surfaced only in Settings —
/// imported notes look like any other note in the timeline.
@Model
final class ImportSource {
  var id: UUID
  /// Display name (the exported folder's name, e.g. "AppleJournalEntries").
  var name: String
  var importedAt: Date
  /// How many notes this import created (snapshot, for display).
  var noteCount: Int

  init(name: String, importedAt: Date = Date(), noteCount: Int = 0) {
    self.id = UUID()
    self.name = name
    self.importedAt = importedAt
    self.noteCount = noteCount
  }
}
