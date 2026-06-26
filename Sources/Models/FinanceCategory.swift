import Foundation
import SwiftData

/// A spending or income category (e.g. "Food", "Salary"). Users can create, edit,
/// and delete categories; each transaction optionally belongs to one. Additive —
/// older stores migrate in with no categories until the defaults are seeded.
@Model
final class FinanceCategory {
  var id: UUID
  var name: String
  var emoji: String
  var colorHex: String
  /// true = an expense (money out) category; false = an income (money in) category.
  var isExpense: Bool
  var sortIndex: Int
  var createdAt: Date

  @Relationship(deleteRule: .nullify, inverse: \FinanceTransaction.category)
  var transactions: [FinanceTransaction] = []

  init(
    name: String,
    emoji: String = "💸",
    colorHex: String = "7E5BEF",
    isExpense: Bool = true,
    sortIndex: Int = 0
  ) {
    self.id = UUID()
    self.name = name
    self.emoji = emoji
    self.colorHex = colorHex
    self.isExpense = isExpense
    self.sortIndex = sortIndex
    self.createdAt = Date()
  }
}

extension FinanceCategory {
  /// The default starter categories, seeded the first time the Finances screen
  /// opens with an empty catalog. Names are localized at display time via `L(_:)`.
  static func defaults() -> [FinanceCategory] {
    let expenses: [(String, String, String)] = [
      ("Food & Drink", "🍜", "FF9F0A"),
      ("Transport", "🚗", "5AC8FA"),
      ("Shopping", "🛍️", "FF5C8A"),
      ("Bills", "🧾", "7E5BEF"),
      ("Entertainment", "🎬", "AF52DE"),
      ("Health", "🏥", "34C759"),
      ("Other", "📦", "8E8E93"),
    ]
    let incomes: [(String, String, String)] = [
      ("Salary", "💰", "34C759"),
      ("Bonus", "🎁", "FFC83D"),
      ("Other", "➕", "30B0C7"),
    ]
    var result: [FinanceCategory] = []
    for (index, item) in expenses.enumerated() {
      result.append(FinanceCategory(name: item.0, emoji: item.1, colorHex: item.2, isExpense: true, sortIndex: index))
    }
    for (index, item) in incomes.enumerated() {
      result.append(FinanceCategory(name: item.0, emoji: item.1, colorHex: item.2, isExpense: false, sortIndex: index))
    }
    return result
  }
}
