import Foundation
import SwiftData

enum AppModelContainer {
  static let schema = Schema([
    Entry.self,
    Habit.self,
    HabitLog.self,
    UserProgress.self,
    XPTransaction.self,
    BadgeRecord.self,
    DayNote.self,
    MediaAttachment.self,
    NoteLocation.self,
    SleepLog.self,
    SmartGoal.self,
    ImportSource.self,
    Identity.self,
    PersonalManifesto.self,
    LifeAreaReview.self,
  ])

  static let shared: ModelContainer = {
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    do {
      return try ModelContainer(for: schema, configurations: [configuration])
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()
}
