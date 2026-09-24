import Foundation
import AppKit

@MainActor
public class FocusGuardian: ObservableObject {
    public static let shared = FocusGuardian()

    @Published public var isSessionActive: Bool = false
    @Published public var remainingSeconds: Int = 25 * 60
    @Published public var sessionTotalSeconds: Int = 25 * 60
    @Published public var userIsAway: Bool = false

    private var sessionTimer: Timer?
    private var hydrationTimer: Timer?
    private var lastAwayNotificationDate: Date? = nil
    private var lastHydrationNotificationDate: Date? = nil

    public init() {
        startHydrationTimerIfNeeded()
    }

    public func startFocusSession(minutes: Int = 25) {
        remainingSeconds = minutes * 60
        sessionTotalSeconds = minutes * 60
        isSessionActive = true
        userIsAway = false

        // Start session countdown
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

    public func pauseFocusSession() {
        isSessionActive = false
        sessionTimer?.invalidate()
        sessionTimer = nil

        // Release vision and screen monitoring
        VisionGuardian.shared.stopSession()
        ScreenGuardian.shared.stopMonitoring()
    }

    public func resetFocusSession(minutes: Int = 25) {
        pauseFocusSession()
        remainingSeconds = minutes * 60
        sessionTotalSeconds = minutes * 60
        userIsAway = false
    }

    private func tick() {
        guard isSessionActive else { return }

        if remainingSeconds > 0 {
            remainingSeconds -= 1
        } else {
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
