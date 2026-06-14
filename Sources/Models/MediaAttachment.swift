import Foundation
import SwiftData

enum MediaType: String, Codable {
  case image
  case video
}

/// A photo or video attached to an `Entry` or a `DayNote`. The binary lives on
/// disk (Documents/media/<fileName>) via `MediaStore`; only metadata is stored
/// in SwiftData so the database stays small.
@Model
final class MediaAttachment {
  var id: UUID
  var fileName: String
  var typeRaw: String
  var createdAt: Date
  var order: Int

  var entry: Entry?
  var note: DayNote?

  init(fileName: String, type: MediaType, order: Int = 0, createdAt: Date = Date()) {
    self.id = UUID()
    self.fileName = fileName
    self.typeRaw = type.rawValue
    self.createdAt = createdAt
    self.order = order
    self.entry = nil
    self.note = nil
  }

  var type: MediaType { MediaType(rawValue: typeRaw) ?? .image }
}
