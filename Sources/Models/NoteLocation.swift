import Foundation
import SwiftData

/// A place tagged on a `DayNote`. A note can have several locations. Stored as a
/// SwiftData relationship so it migrates additively from older stores.
@Model
final class NoteLocation {
  var id: UUID
  var name: String
  var latitude: Double
  var longitude: Double
  var order: Int

  var note: DayNote?

  init(name: String, latitude: Double, longitude: Double, order: Int = 0) {
    self.id = UUID()
    self.name = name
    self.latitude = latitude
    self.longitude = longitude
    self.order = order
  }
}
