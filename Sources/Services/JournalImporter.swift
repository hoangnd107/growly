import Foundation

/// Parses an Apple Journal HTML export into simple notes.
///
/// The export is a folder containing `Entries/<YYYY-MM-DD>.html` files and a
/// `Resources/` folder of media. For each entry: the file name is the date, the
/// first non-empty text line becomes the title, the rest becomes the body, and any
/// referenced photos/videos/audio are returned as file URLs to copy in. The date
/// header and asset markup are stripped; all other fields are left at defaults.
enum JournalImporter {
  struct ParsedEntry {
    let date: Date
    let title: String
    let body: String
    let media: [URL]
  }

  /// Parses every entry in `folder`. `folder` may be the export root (which holds
  /// `Entries/` and `Resources/`) or the `Entries` folder itself.
  static func parse(folder: URL) -> [ParsedEntry] {
    let fm = FileManager.default

    let root: URL
    let entriesDir: URL
    if fm.fileExists(atPath: folder.appendingPathComponent("Entries").path) {
      root = folder
      entriesDir = folder.appendingPathComponent("Entries", isDirectory: true)
    } else if folder.lastPathComponent == "Entries" {
      root = folder.deletingLastPathComponent()
      entriesDir = folder
    } else {
      root = folder
      entriesDir = folder
    }
    let resourcesDir = root.appendingPathComponent("Resources", isDirectory: true)

    guard let files = try? fm.contentsOfDirectory(at: entriesDir, includingPropertiesForKeys: nil) else {
      return []
    }
    let htmlFiles = files
      .filter {
        $0.pathExtension.lowercased() == "html"
          && $0.lastPathComponent.lowercased() != "index.html"
      }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }

    return htmlFiles.compactMap { parseEntry(file: $0, resourcesDir: resourcesDir) }
  }

  private static func parseEntry(file: URL, resourcesDir: URL) -> ParsedEntry? {
    guard let raw = try? String(contentsOf: file, encoding: .utf8) else { return nil }
    let date = self.date(fromFileName: file.deletingPathExtension().lastPathComponent)
      ?? fileModificationDate(file)
      ?? Date()
    let (title, body) = extractText(html: raw)
    let media = extractMedia(html: raw, resourcesDir: resourcesDir)
    // Skip an entry only if it has no text AND no media at all.
    if title.isEmpty, body.isEmpty, media.isEmpty { return nil }
    return ParsedEntry(date: date, title: title, body: body, media: media)
  }

  // MARK: - Date

  /// "2022-06-14" (possibly with a suffix) → that day at noon local time.
  private static func date(fromFileName name: String) -> Date? {
    guard name.count >= 10 else { return nil }
    let prefix = String(name.prefix(10))
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    guard let day = formatter.date(from: prefix) else { return nil }
    return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
  }

  private static func fileModificationDate(_ url: URL) -> Date? {
    (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
  }

  // MARK: - Text

  private static func extractText(html: String) -> (title: String, body: String) {
    var text = substring(of: html, between: "<body>", and: "</body>") ?? html
    // Drop the date header (e.g. "Tuesday, 14 June 2022") — we use the file date.
    text = removingFirstElement(in: text, openTag: "<div class=\"pageHeader\">", closeTag: "</div>")
    // Paragraph / block boundaries become line breaks.
    for token in ["</p>", "</div>", "<br>", "<br/>", "<br />"] {
      text = text.replacingOccurrences(of: token, with: "\n")
    }
    text = stripTags(text)
    text = decodeEntities(text)

    let lines = text
      .components(separatedBy: "\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    guard let first = lines.first else { return ("", "") }
    return (first, lines.dropFirst().joined(separator: "\n"))
  }

  private static func substring(of text: String, between open: String, and close: String) -> String? {
    guard let openRange = text.range(of: open),
          let closeRange = text.range(of: close, range: openRange.upperBound..<text.endIndex) else {
      return nil
    }
    return String(text[openRange.upperBound..<closeRange.lowerBound])
  }

  /// Removes the first `open…close` element (no nested same tags) and its content.
  private static func removingFirstElement(in text: String, openTag: String, closeTag: String) -> String {
    guard let openRange = text.range(of: openTag),
          let closeRange = text.range(of: closeTag, range: openRange.upperBound..<text.endIndex) else {
      return text
    }
    var result = text
    result.removeSubrange(openRange.lowerBound..<closeRange.upperBound)
    return result
  }

  private static func stripTags(_ text: String) -> String {
    text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
  }

  private static func decodeEntities(_ text: String) -> String {
    var result = text
    let map: [(String, String)] = [
      ("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
      ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'")
    ]
    for (entity, replacement) in map {
      result = result.replacingOccurrences(of: entity, with: replacement)
    }
    return result
  }

  // MARK: - Media

  private static func extractMedia(html: String, resourcesDir: URL) -> [URL] {
    let pattern = "(?:src|href)=\"\\.\\./Resources/([^\"]+)\""
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let ns = html as NSString
    let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))

    var urls: [URL] = []
    var seen = Set<String>()
    for match in matches where match.numberOfRanges > 1 {
      let captured = ns.substring(with: match.range(at: 1))
      let fileName = captured.removingPercentEncoding ?? captured
      guard !seen.contains(fileName) else { continue }
      seen.insert(fileName)
      let url = resourcesDir.appendingPathComponent(fileName)
      if MediaStore.mediaType(forExtension: url.pathExtension) != nil,
         FileManager.default.fileExists(atPath: url.path) {
        urls.append(url)
      }
    }
    return urls
  }
}
