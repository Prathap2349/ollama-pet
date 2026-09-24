import Foundation
import UserNotifications
import AppKit

// MARK: - Native macOS Notification Scheduler

public class NotificationScheduler {
    public static let shared = NotificationScheduler()

    private init() {}

    public func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let err = error {
                NSLog("[NotificationScheduler] Authorization error: \(err.localizedDescription)")
            }
            completion?(granted)
        }
    }

    public func checkAuthorization(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            completion(settings.authorizationStatus)
        }
    }

    // MARK: - Scheduling Reminders

    public func scheduleReminder(id: Int64, text: String, inSeconds: Int, notificationId: String? = nil) {
        let identifier = notificationId ?? "reminder-\(id)"
        let secs = max(1, inSeconds)

        let content = UNMutableNotificationContent()
        content.title = "Ollama Pet"
        content.body = text
        content.sound = .default
        content.userInfo = ["type": "reminder", "id": id]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(secs), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let err = error {
                NSLog("[NotificationScheduler] Failed to schedule reminder notification: \(err.localizedDescription)")
            } else {
                NSLog("[NotificationScheduler] Scheduled reminder notification '\(identifier)' for in \(secs)s")
            }
        }
    }

    public func cancelReminder(notificationId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationId])
        NSLog("[NotificationScheduler] Cancelled reminder notification '\(notificationId)'")
    }

    // MARK: - Scheduling Timers

    public func scheduleTimer(timerId: String, title: String, body: String, inSeconds: Int) {
        let identifier = "timer-\(timerId)"
        let secs = max(1, inSeconds)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["type": "timer", "timerId": timerId]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(secs), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let err = error {
                NSLog("[NotificationScheduler] Failed to schedule timer notification: \(err.localizedDescription)")
            } else {
                NSLog("[NotificationScheduler] Scheduled timer notification '\(identifier)' for in \(secs)s")
            }
        }
    }

    public func cancelTimer(timerId: String) {
        let identifier = "timer-\(timerId)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
        NSLog("[NotificationScheduler] Cancelled timer notification '\(identifier)'")
    }

    // MARK: - Immediate Notifications

    public func postImmediate(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let err = error {
                NSLog("[NotificationScheduler] Failed to post immediate notification: \(err.localizedDescription)")
            }
        }
    }
}
