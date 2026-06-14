import Foundation

enum InsightTone {
  case positive
  case neutral
  case suggestion
}

struct Insight: Identifiable {
  let id = UUID()
  let icon: String
  let title: String
  let message: String
  let tone: InsightTone
}

/// On-device, privacy-safe pattern/correlation insights derived from the user's
/// own data — no network, no entitlements. Heuristic, not a black box.
enum InsightsEngine {
  static func generate(
    entries: [Entry],
    habitLogs: [HabitLog],
    sleeps: [SleepLog],
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> [Insight] {
    var insights: [Insight] = []
    let completed = entries.filter { $0.isComplete }

    // 1) Consistency over the last 30 days.
    let today = calendar.startOfDay(for: now)
    let recent = entries.filter {
      guard let d = calendar.dateComponents([.day], from: $0.day, to: today).day else { return false }
      return d >= 0 && d < 30
    }
    if !recent.isEmpty {
      let days = Set(recent.map { $0.day }).count
      insights.append(Insight(
        icon: "calendar",
        title: "Consistency",
        message: "You've reflected on \(days) of the last 30 days. \(days >= 20 ? "Outstanding rhythm." : "Keep the loop going.")",
        tone: days >= 20 ? .positive : .suggestion
      ))
    }

    // 2) Best day of week by average mood.
    if completed.count >= 5 {
      var sums: [Int: (total: Int, count: Int)] = [:]
      for e in completed {
        let wd = calendar.component(.weekday, from: e.day)
        let cur = sums[wd] ?? (0, 0)
        sums[wd] = (cur.total + e.moodRaw, cur.count + 1)
      }
      if let best = sums.max(by: { avg($0.value) < avg($1.value) }) {
        let name = calendar.weekdaySymbols[(best.key - 1) % 7]
        insights.append(Insight(
          icon: "sparkles",
          title: "Your best day",
          message: "You tend to feel brightest on \(name)s. Plan something good for the next one.",
          tone: .positive
        ))
      }
    }

    // 3) Habit ↔ mood correlation.
    if completed.count >= 6 {
      let habitDays = Set(habitLogs.filter { $0.completed }.map { calendar.startOfDay(for: $0.date) })
      let withHabit = completed.filter { habitDays.contains($0.day) }.map { $0.moodRaw }
      let withoutHabit = completed.filter { !habitDays.contains($0.day) }.map { $0.moodRaw }
      if withHabit.count >= 2, withoutHabit.count >= 2 {
        let diff = average(withHabit) - average(withoutHabit)
        if diff >= 0.4 {
          insights.append(Insight(
            icon: "checkmark.seal.fill",
            title: "Habits lift you",
            message: String(format: "On days you complete a habit, your mood averages %.1f higher. Small wins compound.", diff),
            tone: .positive
          ))
        }
      }
    }

    // 4) Sleep ↔ mood.
    if sleeps.count >= 4 {
      let byDay = Dictionary(uniqueKeysWithValues: completed.map { ($0.day, $0.moodRaw) })
      var longRested: [Int] = []
      var shortRested: [Int] = []
      for s in sleeps {
        guard let mood = byDay[calendar.startOfDay(for: s.date)] else { continue }
        if s.durationHours >= 7 { longRested.append(mood) } else { shortRested.append(mood) }
      }
      if longRested.count >= 2, shortRested.count >= 2 {
        let diff = average(longRested) - average(shortRested)
        if diff >= 0.3 {
          insights.append(Insight(
            icon: "bed.double.fill",
            title: "Sleep matters",
            message: "After 7+ hours of sleep your mood runs noticeably higher. Protect your bedtime.",
            tone: .suggestion
          ))
        }
      }
      let avgHours = sleeps.map { $0.durationHours }.reduce(0, +) / Double(sleeps.count)
      insights.append(Insight(
        icon: "moon.zzz.fill",
        title: "Average sleep",
        message: String(format: "You're averaging %.1f hours a night across %d logs.", avgHours, sleeps.count),
        tone: avgHours >= 7 ? .positive : .suggestion
      ))
    }

    // 5) Recent mood trend (last 7 vs previous 7 days).
    if completed.count >= 6 {
      let last7 = moodsInWindow(completed, from: 0, to: 7, today: today, calendar: calendar)
      let prev7 = moodsInWindow(completed, from: 7, to: 14, today: today, calendar: calendar)
      if last7.count >= 2, prev7.count >= 2 {
        let delta = average(last7) - average(prev7)
        if abs(delta) >= 0.4 {
          insights.append(Insight(
            icon: delta > 0 ? "arrow.up.right" : "arrow.down.right",
            title: "Mood trend",
            message: delta > 0
              ? "Your mood is trending up versus last week. Whatever you're doing — keep it."
              : "Your mood dipped a little this week. Be gentle with yourself.",
            tone: delta > 0 ? .positive : .suggestion
          ))
        }
      }
    }

    if insights.isEmpty {
      insights.append(Insight(
        icon: "wand.and.stars",
        title: "Building your picture",
        message: "Keep reflecting and logging — personalized patterns unlock as your data grows.",
        tone: .neutral
      ))
    }
    return insights
  }

  // MARK: Helpers

  private static func avg(_ pair: (total: Int, count: Int)) -> Double {
    pair.count == 0 ? 0 : Double(pair.total) / Double(pair.count)
  }

  private static func average(_ values: [Int]) -> Double {
    values.isEmpty ? 0 : Double(values.reduce(0, +)) / Double(values.count)
  }

  private static func moodsInWindow(_ entries: [Entry], from: Int, to: Int, today: Date, calendar: Calendar) -> [Int] {
    entries.compactMap { e in
      guard let d = calendar.dateComponents([.day], from: e.day, to: today).day else { return nil }
      return (d >= from && d < to) ? e.moodRaw : nil
    }
  }
}
