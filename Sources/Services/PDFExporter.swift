import UIKit
import SwiftUI

/// Renders journal entries into a clean, shareable PDF with a stats cover
/// (level/streak/XP + a mood-distribution bar chart) and one formatted block
/// per entry. Pure Core Graphics — no SwiftUI render dependency.
enum PDFExporter {
  static func export(entries: [Entry], progress: UserProgress?) -> URL? {
    let pageWidth: CGFloat = 612   // US Letter @ 72dpi
    let pageHeight: CGFloat = 792
    let margin: CGFloat = 48
    let contentWidth = pageWidth - margin * 2
    let bounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

    let renderer = UIGraphicsPDFRenderer(bounds: bounds)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("Growly-Journal.pdf")

    let accent = UIColor(progress?.accentColor ?? Color(hex: 0x00B4A6))
    let ink = UIColor(white: 0.10, alpha: 1)
    let subtle = UIColor(white: 0.45, alpha: 1)
    let sorted = entries.sorted { $0.day > $1.day }

    do {
      try renderer.writePDF(to: url) { ctx in
        var y: CGFloat = margin

        func newPage() { ctx.beginPage(); y = margin }
        func ensure(_ height: CGFloat) {
          if y + height > pageHeight - margin { newPage() }
        }

        ctx.beginPage()

        // Cover
        y += draw("Growly", font: .systemFont(ofSize: 34, weight: .bold), color: accent, x: margin, y: y, width: contentWidth)
        y += 4
        y += draw("Reflection Journal", font: .systemFont(ofSize: 16, weight: .semibold), color: subtle, x: margin, y: y, width: contentWidth)
        y += 18

        let df = DateFormatter(); df.dateStyle = .long
        y += draw("Exported \(df.string(from: Date()))", font: .systemFont(ofSize: 11), color: subtle, x: margin, y: y, width: contentWidth)
        y += 24

        if let progress {
          let level = progress.levelInfo.level
          let line = "Level \(level) · \(LevelSystem.title(for: level))    🔥 \(progress.currentStreak)-day streak    ⚡ \(progress.totalXP) XP    📓 \(entries.count) entries"
          y += draw(line, font: .systemFont(ofSize: 12, weight: .medium), color: ink, x: margin, y: y, width: contentWidth)
          y += 20
        }

        // Mood distribution bar chart
        y += draw("Mood distribution", font: .systemFont(ofSize: 13, weight: .semibold), color: ink, x: margin, y: y, width: contentWidth)
        y += 10
        drawMoodChart(entries: entries, in: ctx.cgContext, x: margin, y: y, width: contentWidth)
        y += 110

        // Entries
        for entry in sorted {
          ensure(120)
          let header = entry.day.formatted(.dateTime.weekday(.wide).month().day().year())
          y += draw("\(entry.moodOption.emoji)  \(header)", font: .systemFont(ofSize: 15, weight: .bold), color: ink, x: margin, y: y, width: contentWidth)
          y += 6
          for kind in ReflectionKind.allCases {
            let text = entry.text(for: kind).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            ensure(40)
            y += draw(kind.title.uppercased(), font: .systemFont(ofSize: 9, weight: .heavy), color: accent, x: margin, y: y, width: contentWidth)
            y += 2
            y += draw(text, font: .systemFont(ofSize: 12), color: ink, x: margin, y: y, width: contentWidth)
            y += 8
          }
          // separator
          ctx.cgContext.setStrokeColor(UIColor(white: 0.9, alpha: 1).cgColor)
          ctx.cgContext.setLineWidth(0.5)
          ctx.cgContext.move(to: CGPoint(x: margin, y: y))
          ctx.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: y))
          ctx.cgContext.strokePath()
          y += 16
        }
      }
      return url
    } catch {
      return nil
    }
  }

  @discardableResult
  private static func draw(_ text: String, font: UIFont, color: UIColor, x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
    let style = NSMutableParagraphStyle()
    style.lineBreakMode = .byWordWrapping
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]
    let attributed = NSAttributedString(string: text, attributes: attrs)
    let size = attributed.boundingRect(
      with: CGSize(width: width, height: .greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil
    )
    attributed.draw(
      with: CGRect(x: x, y: y, width: width, height: ceil(size.height)),
      options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil
    )
    return ceil(size.height)
  }

  private static func drawMoodChart(entries: [Entry], in cg: CGContext, x: CGFloat, y: CGFloat, width: CGFloat) {
    var counts: [Int: Int] = [:]
    for e in entries { counts[e.moodRaw, default: 0] += 1 }
    let maxCount = max(1, counts.values.max() ?? 1)
    let moods = MoodCatalog.shared.options
    let gap: CGFloat = 12
    let barWidth = (width - gap * CGFloat(moods.count - 1)) / CGFloat(moods.count)
    let maxBarHeight: CGFloat = 80

    for (index, mood) in moods.enumerated() {
      let count = counts[mood.value] ?? 0
      let barHeight = maxBarHeight * CGFloat(count) / CGFloat(maxCount)
      let bx = x + CGFloat(index) * (barWidth + gap)
      let by = y + (maxBarHeight - barHeight)
      let rect = CGRect(x: bx, y: by, width: barWidth, height: barHeight)
      cg.setFillColor(UIColor(mood.color).cgColor)
      let path = UIBezierPath(roundedRect: rect, cornerRadius: 4)
      cg.addPath(path.cgPath)
      cg.fillPath()
      // label
      let label = NSAttributedString(string: "\(mood.emoji) \(count)", attributes: [
        .font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor(white: 0.3, alpha: 1),
      ])
      label.draw(at: CGPoint(x: bx, y: y + maxBarHeight + 4))
    }
  }
}
