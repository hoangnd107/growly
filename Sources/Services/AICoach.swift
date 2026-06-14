import Foundation

/// On-device, privacy-safe "coach". These are local heuristics + curated copy —
/// no data ever leaves the device.
enum AICoach {
  static func suggestions(for kind: ReflectionKind) -> [String] {
    switch kind {
    case .win:
      return ["A habit I kept", "Someone I helped", "Progress on a goal", "A moment I enjoyed"]
    case .mistake:
      return ["I reacted, not responded", "I overcommitted", "I avoided something", "I lost focus"]
    case .lesson:
      return ["What this taught me", "A pattern I noticed", "What actually mattered", "Next time I'll…"]
    case .adjustment:
      return ["Tomorrow I will…", "One measurable change", "A trigger to remove", "A 1% improvement"]
    }
  }

  private static let morningPrompts = [
    "What would make today a win?",
    "What's the one thing that matters most today?",
    "How do you want to feel by tonight?",
    "What did yesterday teach you to carry forward?",
    "Where will you focus your best energy?",
  ]

  private static let quotes = [
    "Small steps, compounded daily, become transformation.",
    "You don't rise to your goals; you fall to your systems.",
    "Reflection turns experience into wisdom.",
    "Progress, not perfection.",
    "What you track, you improve.",
    "Be kind to the person you were yesterday.",
  ]

  static func morningPrompt(for date: Date = Date(), calendar: Calendar = .current) -> String {
    let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    return morningPrompts[abs(day) % morningPrompts.count]
  }

  static func quote(for date: Date = Date(), calendar: Calendar = .current) -> String {
    let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    return quotes[abs(day) % quotes.count]
  }

  /// A short heuristic weekly summary used by Insights.
  static func weeklySummary(entries: [Entry], calendar: Calendar = .current) -> String {
    guard !entries.isEmpty else {
      return "Start reflecting to unlock your weekly insights."
    }
    let completed = entries.filter { $0.isComplete }.count
    let avgMood = Double(entries.map { $0.moodRaw }.reduce(0, +)) / Double(entries.count)
    let moodWord: String
    switch avgMood {
    case ..<2.0: moodWord = "a tough"
    case 2.0..<3.0: moodWord = "a mixed"
    case 3.0..<4.0: moodWord = "a steady"
    default: moodWord = "a bright"
    }
    return "You completed \(completed) review\(completed == 1 ? "" : "s") in \(moodWord) stretch. Keep closing the loop — consistency is where growth compounds."
  }
}
