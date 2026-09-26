import Foundation
import AppKit

@MainActor
public class FocusGuardian: ObservableObject {
    public static let shared = FocusGuardian()

    @Published public var isSessionActive: Bool = false
    @Published public var remainingSeconds: Int = 25 * 60
    @Published public var sessionTotalSeconds: Int = 25 * 60
    @Published public var userIsAway: Bool = false

    // Custom configuration inputs
    @Published public var customHours: Int = 0 {
        didSet { syncPendingDuration() }
    }
    @Published public var customMinutes: Int = 25 {
        didSet { syncPendingDuration() }
    }
    @Published public var customSeconds: Int = 0 {
        didSet { syncPendingDuration() }
    }
    @Published public var isCustomDurationActive: Bool = false

    public func adjustHours(_ delta: Int) {
        guard !isSessionActive else { return }
        customHours = max(0, min(23, customHours + delta))
        isCustomDurationActive = true
    }

    public func adjustMinutes(_ delta: Int) {
        guard !isSessionActive else { return }
        customMinutes = max(0, min(59, customMinutes + delta))
        isCustomDurationActive = true
    }

    public func adjustSeconds(_ delta: Int) {
        guard !isSessionActive else { return }
        customSeconds = max(0, min(59, customSeconds + delta))
        isCustomDurationActive = true
    }

    public var selectedDurationSeconds: Int {
        return max(1, (customHours * 3600) + (customMinutes * 60) + customSeconds)
    }

    public var formattedSelectedDuration: String {
        let h = customHours
        let m = customMinutes
        let s = customSeconds
        if h > 0 {
            return String(format: "%dh %02dm %02ds", h, m, s)
        } else if s > 0 {
            return String(format: "%02dm %02ds", m, s)
        } else {
            return "\(m)m"
        }
    }

    public var hours: Int { remainingSeconds / 3600 }
    public var minutes: Int { (remainingSeconds % 3600) / 60 }
    public var seconds: Int { remainingSeconds % 60 }

    public var formattedTime: String {
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    public var progress: Double {
        guard sessionTotalSeconds > 0 else { return 0.0 }
        return max(0.0, min(1.0, 1.0 - (Double(remainingSeconds) / Double(sessionTotalSeconds))))
    }

    public var isPaused: Bool {
        return !isSessionActive && remainingSeconds < sessionTotalSeconds && remainingSeconds > 0
    }

    private var sessionTimer: Timer?
    private var hydrationTimer: Timer?
    private var lastAwayNotificationDate: Date? = nil
    private var lastHydrationNotificationDate: Date? = nil

    public init() {
        startHydrationTimerIfNeeded()
    }

    private func syncPendingDuration() {
        guard !isSessionActive && !isPaused else { return }
        let total = selectedDurationSeconds
        sessionTotalSeconds = total
        remainingSeconds = total
    }

    // MARK: - Focus Session Lifecycle

    public func startFocusSession(totalSeconds: Int? = nil) {
        let secs: Int
        if let s = totalSeconds {
            secs = max(1, s)
            sessionTotalSeconds = secs
            remainingSeconds = secs
            customHours = secs / 3600
            customMinutes = (secs % 3600) / 60
            customSeconds = secs % 60
        } else if !isSessionActive && !isPaused {
            secs = selectedDurationSeconds
            sessionTotalSeconds = secs
            remainingSeconds = secs
        } else {
            secs = remainingSeconds
        }

        isSessionActive = true
        userIsAway = false

        // Start 1-second countdown timer
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }

        // Enable vision camera awareness if user enabled it in settings
        if DataManager.shared.savedData.cameraAwarenessEnabled ?? false {
            VisionGuardian.shared.startSession()
        }

        // Enable screen monitoring if user enabled it in settings
        if DataManager.shared.savedData.screenMonitoringEnabled ?? false {
            ScreenGuardian.shared.startMonitoring()
        }

        // Schedule native notification trigger so it fires even if pet window is closed
        NotificationScheduler.shared.scheduleTimer(
            timerId: "focus-session",
            title: "🎯 Focus Complete",
            body: "You completed your focus session! Take a break.",
            inSeconds: secs
        )

        PetState.shared.showBubble("🎯 Focus session started! Let's do this!", duration: 2.5)
        SoundEffect.wake.play()
    }

    // Convenience method for minutes
    public func startFocusSession(minutes: Int) {
        startFocusSession(totalSeconds: minutes * 60)
    }

    public func pauseFocusSession() {
        isSessionActive = false
        sessionTimer?.invalidate()
        sessionTimer = nil

        NotificationScheduler.shared.cancelTimer(timerId: "focus-session")

        // Release vision and screen monitoring
        VisionGuardian.shared.stopSession()
        ScreenGuardian.shared.stopMonitoring()
    }

    public func resetFocusSession(totalSeconds: Int? = nil) {
        pauseFocusSession()
        let secs: Int
        if let s = totalSeconds {
            secs = max(1, s)
            customHours = secs / 3600
            customMinutes = (secs % 3600) / 60
            customSeconds = secs % 60
        } else {
            secs = selectedDurationSeconds
        }
        sessionTotalSeconds = secs
        remainingSeconds = secs
        userIsAway = false
    }

    public func resetFocusSession(minutes: Int) {
        resetFocusSession(totalSeconds: minutes * 60)
    }

    public func applyPreset(seconds: Int) {
        let secs = max(1, seconds)
        isCustomDurationActive = false
        customHours = secs / 3600
        customMinutes = (secs % 3600) / 60
        customSeconds = secs % 60
        if !isSessionActive {
            sessionTotalSeconds = secs
            remainingSeconds = secs
        }
    }

    private func tick() {
        guard isSessionActive else { return }

        if remainingSeconds > 1 {
            remainingSeconds -= 1
        } else {
            remainingSeconds = 0
            completeSession()
        }
    }

    private func completeSession() {
        isSessionActive = false
        sessionTimer?.invalidate()
        sessionTimer = nil

        VisionGuardian.shared.stopSession()
        ScreenGuardian.shared.stopMonitoring()

        NotificationScheduler.shared.handleFocusCompleted(durationSeconds: sessionTotalSeconds)
    }

    // MARK: - Away & Return Notifications

    public func notifyUserAway() {
        guard isSessionActive else { return }
        userIsAway = true

        let notificationsEnabled = DataManager.shared.savedData.focusNotificationsEnabled ?? true
        guard notificationsEnabled else { return }

        // Cooldown: at most once every 60 seconds
        if let last = lastAwayNotificationDate, Date().timeIntervalSince(last) < 60 {
            return
        }
        lastAwayNotificationDate = Date()

        PetState.shared.showBubble("🚶 You seem to have stepped away.", duration: 3.0)
        DataManager.shared.postNotification(title: "🎯 Focus Check", body: "You seem to have stepped away from your focus session.")
    }

    public func notifyUserReturn() {
        guard isSessionActive, userIsAway else { return }
        userIsAway = false

        let notificationsEnabled = DataManager.shared.savedData.focusNotificationsEnabled ?? true
        if notificationsEnabled {
            PetState.shared.showBubble("👋 Welcome back! Let's keep going!", duration: 3.0)
            SoundEffect.click.play()
        }
    }

    // MARK: - Hydration Reminders

    public func startHydrationTimerIfNeeded() {
        hydrationTimer?.invalidate()
        let enabled = DataManager.shared.savedData.hydrationReminderEnabled ?? true
        guard enabled else { return }

        let intervalMins = DataManager.shared.savedData.hydrationIntervalMinutes ?? 60
        let seconds = Double(intervalMins * 60)

        hydrationTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.triggerHydrationReminder()
            }
        }
    }

    public func triggerHydrationReminder() {
        let enabled = DataManager.shared.savedData.hydrationReminderEnabled ?? true
        guard enabled else { return }

        PetState.shared.showBubble("💧 Hydration reminder! Take a sip of water.", duration: 4.0)
        SoundEffect.alert.play()
        DataManager.shared.postNotification(
            title: "💧 Hydration Reminder",
            body: "You've been working for a while. Take a quick water break."
        )
    }

    public func setConfiguredDuration(seconds: Int) {
        guard !isSessionActive else { return }
        let total = max(1, min(24 * 3600, seconds))
        customHours = total / 3600
        customMinutes = (total % 3600) / 60
        customSeconds = total % 60
        isCustomDurationActive = true
        sessionTotalSeconds = total
        remainingSeconds = total
    }

    deinit {
        sessionTimer?.invalidate()
        hydrationTimer?.invalidate()
    }
}

// MARK: - Centralized Focus Duration Parser (Requirements 25, 26, 27)

public struct FocusDurationParser {
    /// Parses any user-typed or spoken duration string into seconds (e.g. "25", "25m", "90m", "1h", "1h30m", "1:30:00", "00:25:00")
    public static func parse(_ rawInput: String) -> Int? {
        let input = rawInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !input.isEmpty else { return nil }

        // 1. Check for HH:MM:SS or MM:SS
        if input.contains(":") {
            let parts = input.components(separatedBy: ":").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if parts.count == 3 {
                let h = max(0, min(23, parts[0]))
                let m = max(0, min(59, parts[1]))
                let s = max(0, min(59, parts[2]))
                let total = (h * 3600) + (m * 60) + s
                return total > 0 ? total : nil
            } else if parts.count == 2 {
                let m = max(0, parts[0])
                let s = max(0, min(59, parts[1]))
                let total = (m * 60) + s
                return total > 0 ? total : nil
            }
        }

        // 2. Check for pure numeric input (e.g. "25", "90", "45") -> interpreted as minutes!
        if let pureMinutes = Int(input), pureMinutes > 0 {
            return min(24 * 3600, pureMinutes * 60)
        }

        // 3. Compound duration with regex / tokens (e.g. "1h30m", "1h 30m", "90m", "2h", "45s", "1 hour 30 mins")
        var totalSeconds = 0
        var matched = false

        // Extract hours
        if let hMatch = input.range(of: #"(\d+)\s*(?:h|hr|hrs|hour|hours)"#, options: .regularExpression) {
            let sub = String(input[hMatch])
            if let digits = Int(sub.filter { $0.isNumber }) {
                totalSeconds += digits * 3600
                matched = true
            }
        }

        // Extract minutes
        if let mMatch = input.range(of: #"(\d+)\s*(?:m|min|mins|minute|minutes)"#, options: .regularExpression) {
            let sub = String(input[mMatch])
            if let digits = Int(sub.filter { $0.isNumber }) {
                totalSeconds += digits * 60
                matched = true
            }
        }

        // Extract seconds
        if let sMatch = input.range(of: #"(\d+)\s*(?:s|sec|secs|second|seconds)"#, options: .regularExpression) {
            let sub = String(input[sMatch])
            if let digits = Int(sub.filter { $0.isNumber }) {
                totalSeconds += digits
                matched = true
            }
        }

        if matched && totalSeconds > 0 {
            return min(24 * 3600, totalSeconds)
        }

        return nil
    }

    /// Natural language extractor for AI queries (e.g. "Start focus for 25 minutes", "Focus for 90 minutes", "Start a 1 hour 30 minute focus session")
    public static func parseNaturalLanguage(_ text: String) -> Int? {
        let lower = text.lowercased()

        // Check if there is explicit duration mentioned directly
        if let duration = parse(lower) {
            return duration
        }

        // Strip prefix phrases
        var cleaned = lower
        let phrasesToRemove = [
            "start focus session for ", "start a focus session for ", "start focus for ",
            "start focus ", "focus session for ", "focus for ", "pomodoro for ", "take a focus for ",
            "focus session", "focus"
        ]
        for phrase in phrasesToRemove {
            if let range = cleaned.range(of: phrase) {
                cleaned.removeSubrange(range)
            }
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        return parse(cleaned)
    }
}
