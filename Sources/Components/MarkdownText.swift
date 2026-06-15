import SwiftUI

/// Lightweight inline formatter for note bodies. Renders the simple markers the
/// editor inserts — `**bold**`, `_italic_` / `*italic*`, `==highlight==`, and
/// `- ` bullet lines — into a styled `AttributedString`. Markers are treated as
/// toggles, so they never leak through as raw text the way a plain `TextField`
/// shows them. Pure value logic; no Markdown library dependency.
enum MarkdownFormatter {
  private struct Run {
    var text: String
    var bold = false
    var italic = false
    var highlight = false
  }

  /// Builds a styled `AttributedString` from `raw`, using `base` as the body
  /// font and `highlight` as the highlight background color.
  static func attributed(_ raw: String, base: Font, highlight: Color) -> AttributedString {
    var output = AttributedString()
    let lines = raw.components(separatedBy: "\n")

    for (index, line) in lines.enumerated() {
      var working = line
      var prefix = ""
      if working.hasPrefix("- ") {
        prefix = "•  "
        working.removeFirst(2)
      }

      if !prefix.isEmpty {
        output.append(AttributedString(prefix))
      }

      for run in runs(in: working) {
        var piece = AttributedString(run.text)
        var font = base
        if run.bold { font = font.bold() }
        if run.italic { font = font.italic() }
        piece.font = font
        if run.highlight {
          piece.backgroundColor = highlight
        }
        output.append(piece)
      }

      if index < lines.count - 1 {
        output.append(AttributedString("\n"))
      }
    }
    return output
  }

  /// A plain-text version with all inline markers removed — for list previews.
  static func plain(_ raw: String) -> String {
    var text = raw
    for token in ["**", "==", "__"] {
      text = text.replacingOccurrences(of: token, with: "")
    }
    // Strip leading bullet markers on each line.
    let lines = text.components(separatedBy: "\n").map { line -> String in
      line.hasPrefix("- ") ? String(line.dropFirst(2)) : line
    }
    return lines.joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Splits a single line into styled runs by toggling on each marker.
  private static func runs(in line: String) -> [Run] {
    var result: [Run] = []
    var buffer = ""
    var bold = false, italic = false, highlight = false
    let chars = Array(line)
    var i = 0

    func flush() {
      if !buffer.isEmpty {
        result.append(Run(text: buffer, bold: bold, italic: italic, highlight: highlight))
        buffer = ""
      }
    }

    while i < chars.count {
      if i + 1 < chars.count, chars[i] == "*", chars[i + 1] == "*" {
        flush(); bold.toggle(); i += 2; continue
      }
      if i + 1 < chars.count, chars[i] == "=", chars[i + 1] == "=" {
        flush(); highlight.toggle(); i += 2; continue
      }
      if chars[i] == "_" || chars[i] == "*" {
        flush(); italic.toggle(); i += 1; continue
      }
      buffer.append(chars[i]); i += 1
    }
    flush()
    return result
  }
}

/// Read-only view that renders note text with inline formatting applied.
struct MarkdownText: View {
  let raw: String
  var font: Font = .dl(.body)
  var highlight: Color = DLColor.xpGold.opacity(0.32)

  var body: some View {
    Text(MarkdownFormatter.attributed(raw, base: font, highlight: highlight))
      .font(font)
      .foregroundStyle(DLColor.textPrimary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .multilineTextAlignment(.leading)
  }
}
