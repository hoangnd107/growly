import Foundation

/// Clears regenerable on-disk caches (temporary files) so the app stays snappy.
///
/// This NEVER touches user data: notes, photos/media (Documents/media), the
/// SwiftData store, and the manual backup (Documents/growly-backup.json) all
/// live in the Documents directory and are left untouched. Only the OS-managed
/// temporary directory is swept, which the system recreates on demand.
@MainActor
enum CacheService {
  /// Removes the exported-PDF temp file and any other stray files in the system
  /// temporary directory. Safe to call any time.
  static func clear() {
    let fm = FileManager.default
    let tmp = fm.temporaryDirectory

    // The one known temp artefact — regenerated on each "Export PDF".
    try? fm.removeItem(at: tmp.appendingPathComponent("Growly-Journal.pdf"))

    // Best-effort sweep of anything else lingering in tmp.
    if let items = try? fm.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil) {
      for item in items {
        try? fm.removeItem(at: item)
      }
    }
  }
}
