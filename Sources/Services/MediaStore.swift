import Foundation
import UIKit

/// Stores attachment binaries on disk (Documents/media) so the SwiftData store
/// stays small. SwiftData only keeps the file name + metadata.
enum MediaStore {
  private static var folderURL: URL {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let url = docs.appendingPathComponent("media", isDirectory: true)
    if !FileManager.default.fileExists(atPath: url.path) {
      try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    return url
  }

  static func url(for fileName: String) -> URL {
    folderURL.appendingPathComponent(fileName)
  }

  /// Writes `data` to a new uniquely-named file and returns the file name.
  static func save(_ data: Data, ext: String) -> String? {
    let name = "\(UUID().uuidString).\(ext)"
    do {
      try data.write(to: url(for: name), options: .atomic)
      return name
    } catch {
      return nil
    }
  }

  /// Copies an existing file into the media store under a fresh, unique name
  /// (preserving its lowercased extension). Returns the new file name, or nil.
  static func copyFile(at sourceURL: URL) -> String? {
    let ext = sourceURL.pathExtension.isEmpty ? "dat" : sourceURL.pathExtension.lowercased()
    let name = "\(UUID().uuidString).\(ext)"
    let dest = url(for: name)
    do {
      if FileManager.default.fileExists(atPath: dest.path) {
        try FileManager.default.removeItem(at: dest)
      }
      try FileManager.default.copyItem(at: sourceURL, to: dest)
      return name
    } catch {
      // Fallback: read + write the bytes (handles some security-scoped quirks).
      if let data = try? Data(contentsOf: sourceURL) {
        return save(data, ext: ext)
      }
      return nil
    }
  }

  /// Best-effort `MediaType` from a file extension (nil for non-media files).
  static func mediaType(forExtension ext: String) -> MediaType? {
    switch ext.lowercased() {
    case "jpg", "jpeg", "png", "heic", "heif", "gif", "tiff", "tif", "webp", "bmp":
      return .image
    case "mp4", "mov", "m4v", "avi", "mpg", "mpeg":
      return .video
    case "m4a", "mp3", "wav", "aac", "caf", "aiff", "aif":
      return .audio
    default:
      return nil
    }
  }

  static func loadData(_ fileName: String) -> Data? {
    try? Data(contentsOf: url(for: fileName))
  }

  static func loadImage(_ fileName: String) -> UIImage? {
    guard let data = loadData(fileName) else { return nil }
    return UIImage(data: data)
  }

  static func delete(_ fileName: String) {
    try? FileManager.default.removeItem(at: url(for: fileName))
  }
}
