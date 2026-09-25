import Foundation
import UserNotifications
import AppKit

// MARK: - Native macOS Notification Scheduler

public class NotificationScheduler {
    public static let shared = NotificationScheduler()

    private init() {}

    public func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        guard Bundle.main.bundleIdentifier != nil else {
            NSLog("[NotificationScheduler] Running outside an app bundle; notifications skipped.")
            completion?(false)
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let err = error {
                NSLog("[NotificationScheduler] Authorization error: \(err.localizedDescription)")
            }
            completion?(granted)
        }
    }

    public func checkAuthorization(completion: @escaping (UNAuthorizationStatus) -> Void) {
        guard Bundle.main.bundleIdentifier != nil else {
            completion(.notDetermined)
            return
        }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            completion(settings.authorizationStatus)
        }
    }

    // MARK: - Scheduling Reminders

    public func scheduleReminder(id: Int64, text: String, inSeconds: Int, notificationId: String? = nil) {
        guard Bundle.main.bundleIdentifier != nil else { return }
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
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationId])
        NSLog("[NotificationScheduler] Cancelled reminder notification '\(notificationId)'")
    }

    // MARK: - Scheduling Timers

    public func scheduleTimer(timerId: String, title: String, body: String, inSeconds: Int) {
        guard Bundle.main.bundleIdentifier != nil else { return }
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
        guard Bundle.main.bundleIdentifier != nil else { return }
        let identifier = "timer-\(timerId)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
        NSLog("[NotificationScheduler] Cancelled timer notification '\(identifier)'")
    }

    public func getAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        checkAuthorization(completion: completion)
    }

    public func sendTestNotification(completion: ((Bool) -> Void)? = nil) {
        guard Bundle.main.bundleIdentifier != nil else {
            postImmediate(title: "🐾 Ollama Pet Test", body: "Notifications are active and working properly!")
            completion?(true)
            return
        }

        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                self?.postImmediate(title: "🐾 Ollama Pet Test", body: "Notifications are active and working properly!")
                DispatchQueue.main.async {
                    SoundEffect.success.play()
                    completion?(true)
                }
            } else if settings.authorizationStatus == .notDetermined {
                self?.requestAuthorization { granted in
                    if granted {
                        self?.postImmediate(title: "🐾 Ollama Pet Test", body: "Notifications are active and working properly!")
                        DispatchQueue.main.async {
                            SoundEffect.success.play()
                            completion?(true)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion?(false)
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion?(false)
                }
            }
        }
    }

    // MARK: - Authoritative Focus Session Completion

    public func handleFocusCompleted(durationSeconds: Int) {
        // 1. Cancel background fallback timer to eliminate double notifications
        cancelTimer(timerId: "focus-session")

        let mins = max(1, durationSeconds / 60)

        // 2. Trigger Pet expressive emotion, bubble, and audio feedback
        DispatchQueue.main.async {
            PetState.shared.setTemporaryMood(.proud, duration: 8.0)
            PetState.shared.showBubble("🎉 Focus complete! Your \(mins)-minute session is finished. Nice work! ❤️", duration: 5.0)
            SoundEffect.receive.play()
        }

        // 3. Dispatch authoritative native notification exactly once
        postImmediate(
            title: "🎯 Focus Complete",
            body: "Great job! Your \(mins)-minute focus session is finished. Take a well-deserved break!"
        )
    }

    // MARK: - Reminders Persistence & Restart Sync

    public func syncPendingReminders(reminders: [PetReminder], onOverdue: ((PetReminder) -> Void)? = nil) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let nowMs = Date().timeIntervalSince1970 * 1000

        for rem in reminders where rem.status == "pending" {
            let diffSecs = Int((rem.due - nowMs) / 1000)
            if diffSecs > 0 {
                // Reschedule with native notification center
                scheduleReminder(
                    id: rem.id,
                    text: rem.text,
                    inSeconds: diffSecs,
                    notificationId: rem.notificationId
                )
            } else {
                // Reminder matured while app was closed or rebooted
                onOverdue?(rem)
            }
        }
    }

    // MARK: - Immediate Notifications

    public func postImmediate(title: String, body: String) {
        guard Bundle.main.bundleIdentifier != nil else { return }
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
