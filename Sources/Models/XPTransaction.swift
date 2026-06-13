import Foundation
import SwiftData

@Model
final class XPTransaction {
  var id: UUID
  var date: Date
  var amount: Int
  var reasonRaw: String
  var multiplier: Double

  init(amount: Int, reason: XPReason, multiplier: Double = 1, date: Date = Date()) {
    self.id = UUID()
    self.date = date
    self.amount = amount
    self.reasonRaw = reason.rawValue
    self.multiplier = multiplier
  }

  var reason: XPReason { XPReason(rawValue: reasonRaw) ?? .dailyReview }
}
