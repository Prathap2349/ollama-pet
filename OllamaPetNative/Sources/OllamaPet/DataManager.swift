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
        // Defer notification requests and reminder sync so init is completely non-blocking
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if Bundle.main.bundleIdentifier != nil {
                self.requestNotificationPermission()
            }
            NotificationScheduler.shared.syncPendingReminders(reminders: self.savedData.reminders)
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
            NSLog("[DataManager] Failed to load saved data: %@", error.localizedDescription)
            // Safely preserve corrupted file for diagnostic inspection instead of silent overwrite
            let backupPath = filePath.deletingLastPathComponent().appendingPathComponent("ollama-pet-data.corrupted.json")
            try? FileManager.default.copyItem(at: filePath, to: backupPath)
            NSLog("[DataManager] Preserved corrupted file at %@ for diagnostic review", backupPath.path)
            NSLog("[DataManager] Starting with safe defaults")
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
            NSLog("[DataManager] Failed to save pet data: %@", error.localizedDescription)
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
        NotificationScheduler.shared.postImmediate(title: title, body: body)
    }

    public func addReminder(text: String, minutes: Int, isRecurring: Bool = false) {
        addReminder(text: text, seconds: minutes * 60, isRecurring: isRecurring, repeatIntervalSeconds: isRecurring ? (minutes * 60) : nil)
    }

    public func addReminder(text: String, seconds: Int, isRecurring: Bool = false, repeatIntervalSeconds: Int? = nil) {
        let secs = max(1, seconds)
        let due = Date().addingTimeInterval(Double(secs)).timeIntervalSince1970 * 1000
        let interval = repeatIntervalSeconds ?? (isRecurring ? secs : nil)
        let newReminder = PetReminder(
            text: text,
            due: due,
            isRecurring: isRecurring,
            repeatIntervalSeconds: interval,
            isPaused: false
        )
        savedData.reminders.append(newReminder)
        saveData()

        // Schedule native macOS UserNotification trigger immediately
        NotificationScheduler.shared.scheduleReminder(
            id: newReminder.id,
            text: text,
            inSeconds: secs,
            notificationId: newReminder.notificationId
        )
    }

    public func toggleReminderPause(id: Int64) {
        guard let index = savedData.reminders.firstIndex(where: { $0.id == id }) else { return }
        let currentPaused = savedData.reminders[index].isPaused ?? false
        let isNowPaused = !currentPaused
        savedData.reminders[index].isPaused = isNowPaused

        let rem = savedData.reminders[index]
        let notifId = rem.notificationId ?? "reminder-\(id)"

        if isNowPaused {
            // Cancel pending system notification while paused
            NotificationScheduler.shared.cancelReminder(notificationId: notifId)
        } else {
            // Resumed: recalculate due date from now using interval
            let interval = rem.repeatIntervalSeconds ?? 300
            let newDue = Date().addingTimeInterval(Double(interval)).timeIntervalSince1970 * 1000
            savedData.reminders[index].due = newDue
            NotificationScheduler.shared.scheduleReminder(
                id: rem.id,
                text: rem.text,
                inSeconds: interval,
                notificationId: notifId
            )
        }
        saveData()
    }

    public func removeReminder(id: Int64) {
        if let reminder = savedData.reminders.first(where: { $0.id == id }) {
            NotificationScheduler.shared.cancelReminder(notificationId: reminder.notificationId ?? "reminder-\(id)")
        }
        savedData.reminders.removeAll { $0.id == id }
        saveData()
    }

    public func updateReminder(id: Int64, text: String, minutes: Int, isRecurring: Bool) {
        guard let index = savedData.reminders.firstIndex(where: { $0.id == id }) else { return }
        let secs = max(60, minutes * 60)
        let due = Date().addingTimeInterval(Double(secs)).timeIntervalSince1970 * 1000
        savedData.reminders[index].text = text
        savedData.reminders[index].due = due
        savedData.reminders[index].isRecurring = isRecurring
        savedData.reminders[index].repeatIntervalSeconds = isRecurring ? secs : nil
        savedData.reminders[index].isPaused = false
        saveData()

        let notifId = savedData.reminders[index].notificationId ?? "reminder-\(id)"
        NotificationScheduler.shared.cancelReminder(notificationId: notifId)
        NotificationScheduler.shared.scheduleReminder(
            id: id,
            text: text,
            inSeconds: secs,
            notificationId: notifId
        )
    }

    public func checkReminders(onTrigger: @escaping (PetReminder, Bool) -> Void) {
        let now = Date().timeIntervalSince1970 * 1000
        var triggered: [PetReminder] = []

        for reminder in savedData.reminders {
            if (reminder.isPaused ?? false) {
                continue
            }
            if reminder.due <= now {
                triggered.append(reminder)
            }
        }

        for item in triggered {
            onTrigger(item, true)

            if item.isRecurring == true {
                // Auto-reschedule recurring reminder
                let interval = max(60, item.repeatIntervalSeconds ?? 300)
                let nextDue = now + Double(interval * 1000)
                if let idx = savedData.reminders.firstIndex(where: { $0.id == item.id }) {
                    savedData.reminders[idx].due = nextDue
                    NotificationScheduler.shared.scheduleReminder(
                        id: item.id,
                        text: item.text,
                        inSeconds: interval,
                        notificationId: item.notificationId
                    )
                }
                saveData()
            } else {
                removeReminder(id: item.id)
            }
        }
    }

    // MARK: - Feature Visibility & Settings Persistence

    public func isFeatureVisible(_ id: String) -> Bool {
        if let map = savedData.featureVisibility, let val = map[id] {
            return val
        }
        return true
    }

    public func setFeatureVisible(_ id: String, visible: Bool) {
        if savedData.featureVisibility == nil {
            savedData.featureVisibility = [:]
        }
        savedData.featureVisibility?[id] = visible
        saveData()
    }

    public func setRandomCharMode(_ mode: String) {
        savedData.randomCharMode = mode
        saveData()
    }

    public func setThemeMode(_ mode: String) {
        savedData.themeMode = mode
        saveData()
    }

    public func setAccentColorChoice(_ choice: String) {
        savedData.accentColorChoice = choice
        saveData()
    }

    public func setPetScale(_ scale: Double) {
        savedData.petScale = scale
        saveData()
    }

    public func setIdleAnimationsEnabled(_ enabled: Bool) {
        savedData.idleAnimationsEnabled = enabled
        saveData()
    }

    public func setSpeechBubblesEnabled(_ enabled: Bool) {
        savedData.speechBubblesEnabled = enabled
        saveData()
    }

    public func setSoundEffectsEnabled(_ enabled: Bool) {
        savedData.soundEffectsEnabled = enabled
        saveData()
    }

    public func setVoiceAssistantEnabled(_ enabled: Bool) {
        savedData.voiceAssistantEnabled = enabled
        saveData()
    }

    public func setSelectedVoiceId(_ voiceId: String) {
        savedData.selectedVoiceId = voiceId
        saveData()
    }

    public func setVoicePreset(_ preset: String) {
        savedData.voicePreset = preset
        saveData()
    }

    public func setSpeechSpeed(_ speed: Double) {
        savedData.speechSpeed = speed
        saveData()
    }

    public func setSpeechVolume(_ volume: Double) {
        savedData.speechVolume = volume
        saveData()
    }

    public func setSpeechPitch(_ pitch: Double) {
        savedData.speechPitch = pitch
        saveData()
    }

    public func setSpeakAiResponses(_ enabled: Bool) {
        savedData.speakAiResponses = enabled
        saveData()
    }

    public func setWalkSpeed(_ speed: Double) {
        savedData.walkSpeed = speed
        saveData()
    }

    public func setShortcutVoice(_ shortcut: String) {
        savedData.shortcutVoice = shortcut
        saveData()
    }

    public func setShortcutTogglePet(_ shortcut: String) {
        savedData.shortcutTogglePet = shortcut
        saveData()
    }

    public func setShortcutSettings(_ shortcut: String) {
        savedData.shortcutSettings = shortcut
        saveData()
    }

    public func setCameraAwarenessEnabled(_ enabled: Bool) {
        savedData.cameraAwarenessEnabled = enabled
        saveData()
    }

    public func setCameraIntervalSeconds(_ sec: Int) {
        savedData.cameraIntervalSeconds = sec
        saveData()
    }

    public func setStillnessAlertEnabled(_ enabled: Bool) {
        savedData.stillnessAlertEnabled = enabled
        saveData()
    }

    public func setScreenMonitoringEnabled(_ enabled: Bool) {
        savedData.screenMonitoringEnabled = enabled
        saveData()
    }

    public func setFocusNotificationsEnabled(_ enabled: Bool) {
        savedData.focusNotificationsEnabled = enabled
        saveData()
    }

    public func setHydrationReminderEnabled(_ enabled: Bool) {
        savedData.hydrationReminderEnabled = enabled
        saveData()
    }

    public func setHydrationIntervalMinutes(_ mins: Int) {
        savedData.hydrationIntervalMinutes = mins
        saveData()
    }

    public func updateMacControlSettings(_ settings: MacControlSettings) {
        savedData.macControlSettings = settings
        saveData()
    }

    public func setQuietModeEnabled(_ enabled: Bool) {
        savedData.quietModeEnabled = enabled
        saveData()
    }

    public func setWalkFrequency(_ freq: String) {
        savedData.walkFrequency = freq
        saveData()
    }
}
