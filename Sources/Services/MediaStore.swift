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
