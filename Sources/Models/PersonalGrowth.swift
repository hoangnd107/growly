import SwiftUI
import SwiftData

// MARK: - Life area

/// The five life areas a `LifeAreaReview` can score. Stored as the raw string on
/// the model so the set can grow without a data migration.
enum LifeArea: String, CaseIterable, Identifiable, Codable {
  case health
  case work
  case finance
  case psychology
  case relationships

  var id: String { rawValue }

  var title: String {
    switch self {
    case .health: return "Health"
    case .work: return "Work"
    case .finance: return "Finance"
    case .psychology: return "Psychology"
    case .relationships: return "Relationships"
    }
  }

  var systemIcon: String {
    switch self {
    case .health: return "heart.fill"
    case .work: return "briefcase.fill"
    case .finance: return "dollarsign.circle.fill"
    case .psychology: return "brain.head.profile"
    case .relationships: return "person.2.fill"
    }
  }

  var accentHex: UInt {
    switch self {
    case .health: return 0xFF3D5A
    case .work: return 0x5AC8FA
    case .finance: return 0x34C759
    case .psychology: return 0xAF8CFF
    case .relationships: return 0xFF9F0A
    }
  }

  var color: Color { Color(hex: accentHex) }
}

// MARK: - Identity (the person I want to become)

/// The user's chosen identity: a vision statement, core values, and a detailed
/// description. A single instance is expected (the first row is used).
@Model
final class Identity {
  var id: UUID
  var title: String
  var detail: String
  var coreValues: [String]
  var visionStatement: String
  var createdAt: Date
  var updatedAt: Date

  init(
    title: String = "",
    detail: String = "",
    coreValues: [String] = [],
    visionStatement: String = ""
  ) {
    self.id = UUID()
    self.title = title
    self.detail = detail
    self.coreValues = coreValues
    self.visionStatement = visionStatement
    self.createdAt = Date()
    self.updatedAt = Date()
  }

  /// Whether the user has filled in anything worth showing as a reminder card.
  var hasContent: Bool {
    !visionStatement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !coreValues.isEmpty
      || !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}

// MARK: - Personal manifesto

/// A free-form personal manifesto with simple markdown-like formatting, auto-saved.
@Model
final class PersonalManifesto {
  var id: UUID
  var title: String
  var body: String
  var updatedAt: Date

  init(title: String = "", body: String = "") {
    self.id = UUID()
    self.title = title
    self.body = body
    self.updatedAt = Date()
  }

  var hasContent: Bool {
    !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}

// MARK: - Life area review

/// One periodic review of a single life area: a 1...10 rating plus notes.
@Model
final class LifeAreaReview {
  var id: UUID
  /// Raw value of a `LifeArea`.
  var areaRaw: String
  var rating: Int
  var notes: String
  var date: Date

  init(area: LifeArea, rating: Int = 5, notes: String = "", date: Date = Date()) {
    self.id = UUID()
    self.areaRaw = area.rawValue
    self.rating = rating
    self.notes = notes
    self.date = date
  }

  var area: LifeArea { LifeArea(rawValue: areaRaw) ?? .health }
}
