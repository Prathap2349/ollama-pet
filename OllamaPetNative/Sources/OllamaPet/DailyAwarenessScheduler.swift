import Foundation
import Combine
import SwiftUI

// MARK: - Daily Awareness Morning Scheduler

@MainActor
public final class DailyAwarenessScheduler: ObservableObject {
    public static let shared = DailyAwarenessScheduler()

    @Published public var isRunning: Bool = false
    @Published public var nextScheduledTimeString: String = ""

    private var checkTimer: Timer?
    private var isTriggering: Bool = false

    private init() {}

    public func startScheduler() {
        stopScheduler()
        updateNextScheduledTimeString()

        // Check immediately upon launch/wake
        evaluateSchedule()

        // Periodic evaluation every 45 seconds
        checkTimer = Timer.scheduledTimer(withTimeInterval: 45.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.evaluateSchedule()
            }
        }
        isRunning = true
        NSLog("[DailyAwarenessScheduler] Started morning awareness scheduler")
    }

    public func stopScheduler() {
        checkTimer?.invalidate()
        checkTimer = nil
        isRunning = false
    }

    public func updateNextScheduledTimeString() {
        let data = DataManager.shared.savedData
        guard data.dailyAwarenessEnabled ?? true else {
            nextScheduledTimeString = "Disabled"
            return
        }

        let hour = data.dailyAwarenessHour ?? 8
        let minute = data.dailyAwarenessMinute ?? 30
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        nextScheduledTimeString = String(format: "%d:%02d %@", displayHour, minute, period)
    }

    // MARK: - Schedule Evaluation (Timezone & Sleep Resilient)

    public func evaluateSchedule() {
        guard !isTriggering else { return }
        let dataManager = DataManager.shared
        let data = dataManager.savedData

        // Check if feature is enabled
        guard data.dailyAwarenessEnabled ?? true else { return }

        let cal = Calendar.autoupdatingCurrent
        let now = Date()
        let comp = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)

        guard let currentYear = comp.year,
              let currentMonth = comp.month,
              let currentDay = comp.day,
              let currentHour = comp.hour,
              let currentMinute = comp.minute else {
            return
        }

        let todayKey = String(format: "%04d-%02d-%02d", currentYear, currentMonth, currentDay)

        // 1. Prevent duplicate runs: check if already delivered for today
        if let lastRun = data.lastAwarenessDigestDate, lastRun == todayKey {
            return
        }

        let targetHour = data.dailyAwarenessHour ?? 8
        let targetMinute = data.dailyAwarenessMinute ?? 30

        // 2. Check if current time has reached or passed target time for today
        let hasReachedTime = (currentHour > targetHour) || (currentHour == targetHour && currentMinute >= targetMinute)

        guard hasReachedTime else {
            return
        }

        // 3. Mark as delivered today IMMEDIATELY before async work to prevent double triggers
        dataManager.savedData.lastAwarenessDigestDate = todayKey
        dataManager.saveData()

        isTriggering = true
        NSLog("[DailyAwarenessScheduler] Triggering scheduled morning briefing for date %@", todayKey)

        Task {
            await deliverMorningBriefing()
            self.isTriggering = false
        }
    }

    // MARK: - Delivery of Morning Briefing

    private func deliverMorningBriefing() async {
        // Fetch current snapshot
        let snapshot = await DailyAwarenessService.shared.getOrFetchSnapshot(forceRefresh: true)

        let newsCount = snapshot.news.count
        let calCount = snapshot.calendarEvents.count
        let totalItems = newsCount + calCount

        // 1. Native macOS Notification (Concise teaser only, never full LLM dump)
        let bodyText: String
        if calCount > 0 && newsCount > 0 {
            bodyText = "You have \(calCount) event\(calCount == 1 ? "" : "s") today and \(newsCount) top headlines. Tap to view your briefing."
        } else if calCount > 0 {
            bodyText = "You have \(calCount) event\(calCount == 1 ? "" : "s") scheduled today. Tap to view your schedule."
        } else if newsCount > 0 {
            bodyText = "\(newsCount) things caught my attention today. Tap to view your morning briefing."
        } else {
            bodyText = "Good morning ☀️ Your morning awareness briefing is ready!"
        }

        NotificationScheduler.shared.postImmediate(
            title: "Ollama Pet ☀️",
            body: bodyText
        )

        // 2. Pet character reaction & speech bubble
        PetState.shared.setTemporaryMood(.curious, duration: 6.0)
        PetState.shared.showBubble("☀️ Good morning! Daily briefing is ready.", duration: 5.0)

        // 3. Optional Voice Assistant readout if user configured speakDailyAwareness
        let speakEnabled = DataManager.shared.savedData.dailyAwarenessSpeak ?? false
        let isQuiet = DataManager.shared.savedData.quietModeEnabled ?? false
        if speakEnabled && !isQuiet {
            VoiceAssistant.shared.speak(text: "Good morning! Your daily briefing is ready. I found \(totalItems) updates for today.")
        }
    }

    /// Manually trigger a test morning briefing
    public func triggerManualDigest() {
        Task {
            await deliverMorningBriefing()
        }
    }
}
