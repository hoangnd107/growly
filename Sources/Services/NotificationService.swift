import Foundation
import UserNotifications

/// Local daily reminder notifications. Works on a free sideload build —
/// local notifications only need the user's permission, no entitlement.
enum NotificationService {
  static let reminderID = "daily.reflection.reminder"

  static func requestAuthorization() async -> Bool {
    do {
      return try await UNUserNotificationCenter.current()
        .requestAuthorization(options: [.alert, .sound, .badge])
    } catch {
      return false
    }
  }

  static func authorizationStatus() async -> UNAuthorizationStatus {
    await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
  }

  static func scheduleDailyReminder(hour: Int, minute: Int) {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [reminderID])

    let content = UNMutableNotificationContent()
    content.title = L("Time to reflect")
    content.body = L("Close today's loop — Win, Mistake, Lesson, Adjustment.")
    content.sound = .default

    var components = DateComponents()
    components.hour = hour
    components.minute = minute
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

    center.add(UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger))
  }

  static func cancelDailyReminder() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderID])
  }

  /// Re-applies the schedule from the user's settings (called on launch and on change).
  static func sync(enabled: Bool, hour: Int, minute: Int) {
    if enabled {
      scheduleDailyReminder(hour: hour, minute: minute)
    } else {
      cancelDailyReminder()
    }
  }
}
