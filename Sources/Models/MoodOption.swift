import SwiftUI

// MARK: - Mood option (one mood on the customizable scale)

/// A single mood on the user's customizable mood scale. The five built-in moods
/// are always present (`value` 1...5, worst → best) and can be re-skinned (emoji,
/// name, color); users may append extra custom moods (`value` 6, 7, …).
///
/// `value` is the stable ordinal stored on `Entry.moodRaw` / `DayNote.moodRaw`, so
/// all existing analytics (averages, trend, distribution, heatmap) keep working —
/// adding a custom mood simply extends the ordinal ladder.
struct MoodOption: Identifiable, Hashable, Codable {
  var value: Int
  var emoji: String
  var label: String
  var colorHex: String
  /// Built-in moods localize their `label` through `L(_:)` and cannot be removed.
  /// Custom moods show the user's text verbatim and can be deleted.
  var isBuiltIn: Bool

  var id: Int { value }
  var color: Color { Color(hexString: colorHex) }

  /// Localized for built-ins, verbatim for custom moods.
  var displayName: String { isBuiltIn ? L(label) : label }
}

// MARK: - Mood catalog (app-wide active scale)

/// App-wide source of truth for the active mood scale. Synced from `UserProgress`
/// in `RootView` so a custom catalog shows everywhere a mood is rendered, without
/// threading it through every view.
final class MoodCatalog {
  static let shared = MoodCatalog()

  /// Active moods, ascending by `value` (worst → best). Always contains the five
  /// built-ins (values 1...5).
  private(set) var options: [MoodOption] = MoodCatalog.defaults

  /// The five built-in moods, derived from the `Mood` enum's defaults.
  static var defaults: [MoodOption] {
    Mood.allCases.map {
      MoodOption(
        value: $0.rawValue,
        emoji: $0.defaultEmoji,
        label: $0.label,
        colorHex: $0.defaultColorHex,
        isBuiltIn: true
      )
    }
  }

  /// Highest mood value in the catalog — the chart domain's upper bound.
  var maxValue: Int { options.map(\.value).max() ?? 5 }

  /// The next value to assign when the user adds a custom mood.
  var nextValue: Int { maxValue + 1 }

  /// The option for a stored `moodRaw`, clamped to the nearest existing value so
  /// legacy entries (or ones referencing a since-removed custom mood) still render.
  func option(forValue value: Int) -> MoodOption? {
    if let exact = options.first(where: { $0.value == value }) { return exact }
    guard let minValue = options.map(\.value).min() else { return nil }
    let clamped = min(max(value, minValue), maxValue)
    return options.first(where: { $0.value == clamped }) ?? options.last
  }

  /// Replace the active catalog from the user's stored JSON, falling back to the
  /// legacy per-level `moodEmojis`, then the built-in defaults.
  func apply(from progress: UserProgress) {
    if let decoded = MoodCatalog.decode(progress.moodCatalogJSON), !decoded.isEmpty {
      options = MoodCatalog.normalized(decoded)
      return
    }
    // Legacy migration: overlay any saved per-level emoji onto the defaults.
    var base = MoodCatalog.defaults
    for (index, emoji) in progress.moodEmojis.enumerated() where base.indices.contains(index) {
      let trimmed = emoji.trimmingCharacters(in: .whitespaces)
      if !trimmed.isEmpty { base[index].emoji = trimmed }
    }
    options = base
  }

  /// Persist `options` back onto `progress` (and refresh the live catalog).
  func save(_ newOptions: [MoodOption], to progress: UserProgress) {
    let normalized = MoodCatalog.normalized(newOptions)
    options = normalized
    progress.moodCatalogJSON = MoodCatalog.encode(normalized)
  }

  /// Guarantee the five built-ins exist (re-inserting any the data dropped) and a
  /// stable ascending order by `value`.
  static func normalized(_ list: [MoodOption]) -> [MoodOption] {
    var byValue: [Int: MoodOption] = [:]
    for option in list { byValue[option.value] = option }
    for builtIn in defaults where byValue[builtIn.value] == nil {
      byValue[builtIn.value] = builtIn
    }
    return byValue.values.sorted { $0.value < $1.value }
  }

  static func decode(_ json: String) -> [MoodOption]? {
    guard !json.isEmpty, let data = json.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode([MoodOption].self, from: data)
  }

  static func encode(_ options: [MoodOption]) -> String {
    guard let data = try? JSONEncoder().encode(options),
          let string = String(data: data, encoding: .utf8) else { return "" }
    return string
  }
}
