import Foundation
import UserNotifications

@MainActor
public class DataManager: ObservableObject {
    public static let shared = DataManager()

    @Published public var savedData: PetSavedData = PetSavedData()
    private let filePath: URL

    public init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.filePath = home.appendingPathComponent("ollama-pet-data.json")
        loadData()
        if Bundle.main.bundleIdentifier != nil {
            requestNotificationPermission()
        }
    }

    public func loadData() {
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            savedData = PetSavedData()
            return
        }

        do {
            let data = try Data(contentsOf: filePath)
            let loaded = try JSONDecoder().decode(PetSavedData.self, from: data)
            self.savedData = loaded
        } catch {
            print("Failed to load pet data: \(error.localizedDescription)")
            self.savedData = PetSavedData()
        }
    }

    public func saveData() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(savedData)
            try data.write(to: filePath, options: [.atomic])
        } catch {
            print("Failed to save pet data: \(error.localizedDescription)")
        }
    }

    public func updatePosition(x: Double, y: Double) {
        savedData.position = PetSavedPosition(x: x, y: y)
        saveData()
    }

    public func updateStreak() {
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        if savedData.lastChatDate != today {
            let cal = Calendar.current
            if let yesterday = cal.date(byAdding: .day, value: -1, to: Date()) {
                let yesterdayStr = DateFormatter.localizedString(from: yesterday, dateStyle: .short, timeStyle: .none)
                if savedData.lastChatDate == yesterdayStr {
                    savedData.streak += 1
                } else {
                    savedData.streak = 1
                }
            } else {
                savedData.streak = 1
            }
            savedData.lastChatDate = today
            saveData()
        }
    }

    // MARK: - Reminders & Notifications

    public func requestNotificationPermission() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let err = error {
                print("Notification authorization error: \(err)")
            }
        }
    }

    public func postNotification(title: String, body: String) {
        guard Bundle.main.bundleIdentifier != nil else {
            print("Notification (CLI fallback): [\(title)] \(body)")
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    public func addReminder(text: String, minutes: Int) {
        let due = Date().addingTimeInterval(Double(minutes * 60)).timeIntervalSince1970 * 1000
        let newReminder = PetReminder(text: text, due: due)
        savedData.reminders.append(newReminder)
        saveData()
    }

    public func removeReminder(id: Int64) {
        savedData.reminders.removeAll { $0.id == id }
        saveData()
    }

    public func checkReminders(onTrigger: @escaping (PetReminder, Bool) -> Void) {
        let now = Date().timeIntervalSince1970 * 1000
        var overdue: [PetReminder] = []

        for reminder in savedData.reminders {
            if reminder.due <= now {
                overdue.append(reminder)
            }
        }

        for item in overdue {
            onTrigger(item, true)
            removeReminder(id: item.id)
            postNotification(title: "⏰ Reminder Overdue", body: item.text)
        }
    }
}
