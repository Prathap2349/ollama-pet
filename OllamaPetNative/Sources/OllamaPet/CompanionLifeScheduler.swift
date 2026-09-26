import Foundation
import SwiftUI

@MainActor
public final class CompanionLifeScheduler: ObservableObject {
    public static let shared = CompanionLifeScheduler()

    @Published public var currentAction: String = "idle"
    private var schedulerTimer: Timer?
    private var sleepCheckTimer: Timer?
    private var lastUserActivity: Date = Date()
    private var activeLifeTask: Task<Void, Never>?

    // Behavior cooldown timestamps to avoid unnatural repetition
    private var lastWalkTime: Date = Date.distantPast
    private var lastSitTime: Date = Date.distantPast
    private var lastWatchUserTime: Date = Date.distantPast
    private var lastSpecialTime: Date = Date.distantPast
    private var isSitting: Bool = false

    private init() {
        startScheduler()
    }

    public func recordUserInteraction() {
        lastUserActivity = Date()
        if PetState.shared.animState == .sleep {
            PetState.shared.wakeUp()
        } else if isSitting {
            standUp()
        }
    }

    public func startScheduler() {
        stopScheduler()
        scheduleNextEvaluation()
        startSleepMonitor()
    }

    public func stopScheduler() {
        schedulerTimer?.invalidate()
        schedulerTimer = nil
        sleepCheckTimer?.invalidate()
        sleepCheckTimer = nil
        activeLifeTask?.cancel()
        activeLifeTask = nil
    }

    public func restartScheduler() {
        startScheduler()
    }

    // MARK: - Inactivity Sleep Monitor (5 min / 300s)

    private func startSleepMonitor() {
        sleepCheckTimer?.invalidate()
        sleepCheckTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.evaluateSleepTransition()
            }
        }
    }

    private func evaluateSleepTransition() {
        let petState = PetState.shared
        guard !petState.isChatOpen && !petState.isThinking else {
            lastUserActivity = Date()
            return
        }
        guard !VoiceAssistant.shared.isSpeaking else {
            lastUserActivity = Date()
            return
        }
        guard !FocusGuardian.shared.isSessionActive else {
            lastUserActivity = Date()
            return
        }
        guard !(MusicManager.shared.isMediaPlaying && MusicManager.shared.danceWhenMusicDetected) else {
            lastUserActivity = Date()
            return
        }

        let idleSeconds = Date().timeIntervalSince(lastUserActivity)
        if idleSeconds >= 300.0 && petState.animState != .sleep && !WalkerManager.shared.isWalking {
            isSitting = false
            petState.animState = .sleep
            petState.currentMood = .sleepy
            petState.showBubble("zZz... 😴", duration: 3.5)
        }
    }

    // MARK: - Autonomous Life Loop

    private func scheduleNextEvaluation() {
        schedulerTimer?.invalidate()
        let setting = PetState.shared.autonomousLifeSetting
        guard setting != .off else { return }

        let range = setting.intervalRangeSeconds
        let interval = Double.random(in: range)

        schedulerTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.evaluateAutonomousAction()
                self.scheduleNextEvaluation()
            }
        }
    }

    private func evaluateAutonomousAction() {
        let petState = PetState.shared
        let now = Date()

        // 1. Guard against busy user contexts
        guard !petState.isChatOpen && !petState.isThinking else { return }
        guard !VoiceAssistant.shared.isSpeaking else { return }
        guard !FocusGuardian.shared.isSessionActive else { return }
        guard !WalkerManager.shared.isWalking else { return }
        guard petState.activeEventPriority <= .autonomousLife else { return }
        guard !(MusicManager.shared.isMediaPlaying && MusicManager.shared.danceWhenMusicDetected) else { return }

        // 2. Handle sleeping state
        if petState.animState == .sleep {
            if Double.random(in: 0...1) < 0.30 {
                petState.showDream()
            }
            return
        }

        // 3. Only evaluate if idle or sitting
        guard petState.animState == .idle || petState.animState == .sit else { return }

        activeLifeTask?.cancel()
        activeLifeTask = Task { @MainActor in
            if self.isSitting {
                // Actions from sitting: stretch & stand, or watch user
                let roll = Double.random(in: 0...1)
                if roll < 0.45 {
                    // Watch user from sitting pose
                    self.executeWatchUser(duration: 4.0)
                } else if roll < 0.75 {
                    // Stretch paws then stand
                    petState.animState = .stretch
                    petState.showBubble("*stretches paws* 🐾", duration: 2.2)
                    try? await Task.sleep(nanoseconds: 2_200_000_000)
                    guard !Task.isCancelled else { return }
                    self.standUp()
                } else {
                    // Stand up
                    self.standUp()
                }
                return
            }

            // Progression weights from standing/idle
            // Cycle: idle -> lookAround -> watchUser -> sit -> stretch -> stand -> walk -> pause -> idle
            let roll = Double.random(in: 0...100)

            if roll < 24 {
                // 1. Watch User (focused forward gaze, pupil dilation, loving/calm connection)
                if now.timeIntervalSince(self.lastWatchUserTime) >= 12.0 {
                    self.executeWatchUser(duration: Double.random(in: 3.5...5.0))
                } else {
                    self.executeLookAround(duration: 2.5)
                }
            } else if roll < 46 {
                // 2. Look Around (inquisitive head yaw & ear/tail movement)
                self.executeLookAround(duration: Double.random(in: 2.2...3.5))
            } else if roll < 62 {
                // 3. Sit Down (settling down comfortably)
                if now.timeIntervalSince(self.lastSitTime) >= 25.0 {
                    self.executeSit(duration: Double.random(in: 5.0...8.0))
                } else {
                    self.executeStretch()
                }
            } else if roll < 78 {
                // 4. Stretch & Yawn
                self.executeStretch()
            } else if roll < 92 {
                // 5. Autonomous Walk across screen
                if now.timeIntervalSince(self.lastWalkTime) >= 35.0 {
                    self.executeWalk()
                } else {
                    self.executeLookAround(duration: 2.0)
                }
            } else {
                // 6. Species Special Emote / Ability
                if now.timeIntervalSince(self.lastSpecialTime) >= 50.0 {
                    self.lastSpecialTime = now
                    petState.triggerSpecialAbility()
                } else {
                    self.executeWatchUser(duration: 3.0)
                }
            }
        }
    }

    private func executeWatchUser(duration: TimeInterval) {
        lastWatchUserTime = Date()
        let petState = PetState.shared
        petState.animState = .watchUser
        petState.setTemporaryMood(.love, duration: duration)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if petState.animState == .watchUser {
                petState.animState = self.isSitting ? .sit : .idle
            }
        }
    }

    private func executeLookAround(duration: TimeInterval) {
        let petState = PetState.shared
        petState.animState = .lookAround
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if petState.animState == .lookAround {
                petState.animState = self.isSitting ? .sit : .idle
            }
        }
    }

    private func executeSit(duration: TimeInterval) {
        lastSitTime = Date()
        isSitting = true
        let petState = PetState.shared
        petState.animState = .sit

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            // After sitting duration, stand up or remain sitting
            if self.isSitting && petState.animState == .sit {
                if Double.random(in: 0...1) < 0.6 {
                    self.standUp()
                }
            }
        }
    }

    private func standUp() {
        let petState = PetState.shared
        isSitting = false
        if petState.animState == .sit {
            petState.animState = .stand
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)
                if petState.animState == .stand {
                    petState.animState = .idle
                }
            }
        }
    }

    private func executeStretch() {
        let petState = PetState.shared
        petState.animState = .stretch
        let emotes = ["*stretches paws* 🐾", "*gentle yawn* 🫧", "*purrs softly* 💤", "*fluffs up warmly* ✨"]
        if let emote = emotes.randomElement() {
            petState.showBubble(emote, duration: 2.4)
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            if petState.animState == .stretch {
                petState.animState = self.isSitting ? .sit : .idle
            }
        }
    }

    private func executeWalk() {
        lastWalkTime = Date()
        if isSitting {
            standUp()
        }
        let petState = PetState.shared

        // Organic preparation: Look around before beginning stroll
        petState.animState = .lookAround
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !petState.isChatOpen && !petState.isThinking && !WalkerManager.shared.isWalking else {
                if petState.animState == .lookAround { petState.animState = .idle }
                return
            }
            WalkerManager.shared.startWalk(species: petState.currentSpecies, isTest: false)
        }
    }

    deinit {
        schedulerTimer?.invalidate()
        sleepCheckTimer?.invalidate()
        activeLifeTask?.cancel()
    }
}
