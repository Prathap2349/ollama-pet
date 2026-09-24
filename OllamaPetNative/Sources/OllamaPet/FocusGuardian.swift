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
    @Published public var customHours: Int = 0
    @Published public var customMinutes: Int = 25
    @Published public var customSeconds: Int = 0

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

    private var sessionTimer: Timer?
    private var hydrationTimer: Timer?
    private var lastAwayNotificationDate: Date? = nil
    private var lastHydrationNotificationDate: Date? = nil

    public init() {
        startHydrationTimerIfNeeded()
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
        } else if !isSessionActive && (remainingSeconds == 0 || remainingSeconds == sessionTotalSeconds) {
            secs = max(1, (customHours * 3600) + (customMinutes * 60) + customSeconds)
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
            secs = max(1, (customHours * 3600) + (customMinutes * 60) + customSeconds)
        }
        sessionTotalSeconds = secs
        remainingSeconds = secs
        userIsAway = false
    }

    public func resetFocusSession(minutes: Int) {
        resetFocusSession(totalSeconds: minutes * 60)
    }

    public func applyPreset(seconds: Int) {
        pauseFocusSession()
        customHours = seconds / 3600
        customMinutes = (seconds % 3600) / 60
        customSeconds = seconds % 60
        sessionTotalSeconds = seconds
        remainingSeconds = seconds
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

        PetState.shared.showBubble("🎉 Focus session completed! Great job!", duration: 5.0)
        SoundEffect.receive.play()
        DataManager.shared.postNotification(title: "🎯 Focus Complete", body: "You completed your focus session! Take a break.")
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

    deinit {
        sessionTimer?.invalidate()
        hydrationTimer?.invalidate()
    }
}
