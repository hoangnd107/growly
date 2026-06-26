import Foundation
import SwiftData

/// A single money movement — income or expense — with an amount, date, optional
/// category, free-text note, and attached photos/videos. The amount is always
/// stored positive; the sign comes from `isExpense`.
@Model
final class FinanceTransaction {
  var id: UUID
  /// Always positive; the sign is derived from `isExpense`.
  var amount: Double
  var isExpense: Bool
  var date: Date
  var note: String
  var createdAt: Date

  var category: FinanceCategory?

  @Relationship(deleteRule: .cascade, inverse: \MediaAttachment.transaction)
  var attachments: [MediaAttachment] = []

  init(
    amount: Double = 0,
    isExpense: Bool = true,
    date: Date = Date(),
    note: String = "",
    category: FinanceCategory? = nil
  ) {
    self.id = UUID()
    self.amount = amount
    self.isExpense = isExpense
    self.date = date
    self.note = note
    self.createdAt = Date()
    self.category = category
  }

  /// Signed amount for summing: negative for expenses, positive for income.
  var signedAmount: Double { isExpense ? -amount : amount }

  var sortedAttachments: [MediaAttachment] {
    attachments.sorted { $0.order < $1.order }
  }
}

// MARK: - Currency formatting (VND)

/// Formats amounts as Vietnamese đồng, grouping thousands with "." and suffixing
/// "đ" — e.g. 10_000_000 → "10.000.000đ". The app uses VND throughout.
enum CurrencyFormatter {
  private static let formatter: NumberFormatter = {
    let nf = NumberFormatter()
    nf.numberStyle = .decimal
    nf.groupingSeparator = "."
    nf.usesGroupingSeparator = true
    nf.maximumFractionDigits = 0
    return nf
  }()

  /// "10.000.000đ" (no sign), rounding to whole đồng.
  static func vnd(_ amount: Double) -> String {
    let rounded = amount.rounded()
    let negative = rounded < 0
    let absString = formatter.string(from: NSNumber(value: abs(rounded))) ?? "\(Int(abs(rounded)))"
    return (negative ? "-" : "") + absString + "đ"
  }

  /// A signed display string with an explicit "+" for income — e.g. "+5.000.000đ"
  /// or "-120.000đ".
  static func signedVND(_ amount: Double) -> String {
    if amount > 0 { return "+" + vnd(amount) }
    return vnd(amount)
  }
}
