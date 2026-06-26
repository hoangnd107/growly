import Foundation
import SwiftData

/// A place tagged on a `DayNote`. A note can have several locations. Stored as a
/// SwiftData relationship so it migrates additively from older stores.
///
/// Coordinates are optional: a place can be a map-picked pin (with lat/long) OR a
/// free-typed name with no coordinate at all, so users can tag a place by name
/// without knowing — or wanting to look up — its position.
@Model
final class NoteLocation {
  var id: UUID
  var name: String
  var latitude: Double?
  var longitude: Double?
  var order: Int

  var note: DayNote?

  init(name: String, latitude: Double? = nil, longitude: Double? = nil, order: Int = 0) {
    self.id = UUID()
    self.name = name
    self.latitude = latitude
    self.longitude = longitude
    self.order = order
  }

  /// Whether this place carries a real map coordinate (vs. a name-only tag).
  var hasCoordinate: Bool { latitude != nil && longitude != nil }
}
