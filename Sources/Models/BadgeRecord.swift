import Foundation
import SwiftData

/// Persisted record that a badge has been earned.
@Model
final class BadgeRecord {
  var id: UUID
  var badgeID: String
  var earnedAt: Date

  init(badgeID: String, earnedAt: Date = Date()) {
    self.id = UUID()
    self.badgeID = badgeID
    self.earnedAt = earnedAt
  }

  var badge: Badge? { BadgeCatalog.badge(id: badgeID) }
}
