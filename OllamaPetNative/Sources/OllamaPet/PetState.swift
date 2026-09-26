import Foundation
import SwiftUI
import AppKit

@MainActor
public class PetState: ObservableObject {
    public static let shared = PetState()

    @Published public var currentSpecies: PetSpecies = .cat
    @Published public var animState: PetAnimState = .idle
    @Published public var currentMood: PetMood = .happy
    @Published public var moodPoints: Double = 100.0
    @Published public var streak: Int = 0
    @Published public var chatCount: Int = 0

    public var level: Int {
        return max(1, (streak * 2) + (chatCount / 5) + 1)
    }

    @Published public var bubbleText: String = ""
    @Published public var isBubbleVisible: Bool = false
    @Published public var dreamText: String = ""
    @Published public var isDreamVisible: Bool = false

    @Published public var isChatOpen: Bool = false
    @Published public var isThinking: Bool = false
    @Published public var activeTab: String = "chat"
    @Published public var activeAnchor: PanelAnchor = PanelAnchor(isLeft: false, isTop: false)

    @Published public var animTime: Double = 0.0

    // Companion Mode
    @Published public var companionMode: Bool = false

    // Celebration Ring & Pulse
    @Published public var isCelebrationPulsing: Bool = false
    @Published public var celebrationPulseColor: Color = Color.yellow
    private var celebrationTimer: Timer?

    // Autonomous Life Cycle
    @Published public var autonomousLifeMode: String = "normal"
    private var autonomousLifeTimer: Timer?

    // 3D Rendering & Customization
    @Published public var renderEngineMode: RenderEngineMode = .threeD
    @Published public var customHornEnabled: Bool = true
    @Published public var customWingsEnabled: Bool = true
    @Published public var customAccessory: String = "none"

    private var bubbleTimer: Timer?
    private var dreamTimer: Timer?
    private var sleepTimer: Timer?
    private var animTimer: Timer?

    private let dreams = ["🍕", "🌈", "⭐", "🐟", "🎮", "🏖️", "🚀", "💤", "🌙", "🎵", "🍦", "🦋"]

    // Priority Management (Requirement 9)
    @Published public var activeEventPriority: PetEventPriority = .idleBehavior
    private var priorityResetTask: Task<Void, Never>?

    public func setPriority(_ priority: PetEventPriority, duration: TimeInterval? = nil) {
        self.activeEventPriority = priority
        priorityResetTask?.cancel()
        if let d = duration {
            priorityResetTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(d * 1_000_000_000))
                if !Task.isCancelled {
                    self.activeEventPriority = .idleBehavior
                }
            }
        }
    }

    public func triggerCelebration(color: Color = Color(red: 1.0, green: 0.85, blue: 0.2), duration: TimeInterval = 5.0) {
        setPriority(.importantAppEvent, duration: duration)
        celebrationTimer?.invalidate()
        isCelebrationPulsing = true
        celebrationPulseColor = color
        animState = .celebrate
        setTemporaryMood(.celebrating, duration: duration)
        celebrationTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.isCelebrationPulsing = false
                if self?.animState == .celebrate {
                    self?.animState = .idle
                }
            }
        }
    }

    public func wakeUp() {
        if animState == .sleep {
            animState = .wake
            setTemporaryMood(.calm, duration: 2.5)
            showBubble("*wakes up refreshed* ☀️", duration: 2.5)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if self.animState == .wake {
                    self.animState = .idle
                }
            }
        }
        resetSleepTimer()
    }

    public func goToSleep() {
        animState = .sleep
        currentMood = .sleepy
        showBubble("zZz... 😴", duration: 3.0)
    }

    public func startWalking(duration: TimeInterval = 6.0) {
        guard animState != .sleep else { return }
        WalkerManager.shared.startWalk(species: currentSpecies, isTest: false)
    }

    public init() {
        loadFromPersistence()
        startAnimationLoop()
        startIdleAndDreamTimers()
    }

    private func loadFromPersistence() {
        let data = DataManager.shared.savedData

        // Check Random Character Mode
        let mode = data.randomCharMode ?? "fixed"
        if mode == "launch" {
            if let randomSp = PetSpecies.allCases.randomElement() {
                self.currentSpecies = randomSp
                DataManager.shared.savedData.currentChar = randomSp.rawValue
            }
        } else if mode == "daily" {
            let calendar = Calendar.current
            let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 0
            let allCases = PetSpecies.allCases
            let picked = allCases[dayOfYear % allCases.count]
            self.currentSpecies = picked
            DataManager.shared.savedData.currentChar = picked.rawValue
        } else {
            if let sp = PetSpecies(rawValue: data.currentChar) {
                self.currentSpecies = sp
            }
        }

        self.streak = data.streak
        self.moodPoints = data.moodPoints
        self.activeTab = data.activeTab ?? "chat"
        self.autonomousLifeMode = data.autonomousLifeMode ?? "normal"

        if let modeStr = data.renderEngineMode, let mode = RenderEngineMode(rawValue: modeStr) {
            self.renderEngineMode = mode
        } else {
            self.renderEngineMode = .threeD
        }
        self.customHornEnabled = data.customHornEnabled ?? true
        self.customWingsEnabled = data.customWingsEnabled ?? true
        self.customAccessory = data.customAccessory ?? "none"
    }

    public func setRenderEngineMode(_ mode: RenderEngineMode) {
        self.renderEngineMode = mode
        DataManager.shared.savedData.renderEngineMode = mode.rawValue
        DataManager.shared.saveData()
    }

    public func setCustomAccessory(_ acc: String) {
        self.customAccessory = acc
        DataManager.shared.savedData.customAccessory = acc
        DataManager.shared.saveData()
    }

    public func toggleHorns() {
        self.customHornEnabled.toggle()
        DataManager.shared.savedData.customHornEnabled = self.customHornEnabled
        DataManager.shared.saveData()
    }

    public func toggleWings() {
        self.customWingsEnabled.toggle()
        DataManager.shared.savedData.customWingsEnabled = self.customWingsEnabled
        DataManager.shared.saveData()
    }

    public func setSpecies(_ species: PetSpecies) {
        self.currentSpecies = species
        DataManager.shared.savedData.currentChar = species.rawValue
        DataManager.shared.saveData()

        self.animState = .dance
        showBubble(species.greetings.randomElement() ?? "Hello!")
        SoundEffect.wake.play()

        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if self.animState == .dance {
                self.animState = .idle
            }
        }
    }

    public func showBubble(_ text: String, duration: TimeInterval = 2.5) {
        bubbleTimer?.invalidate()
        bubbleText = text
        isBubbleVisible = true

        bubbleTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.isBubbleVisible = false
            }
        }
    }

    public func showDream() {
        guard (animState == .sleep || animState == .idle) && !isChatOpen else { return }
        let picked = (0..<3).compactMap { _ in dreams.randomElement() }.joined(separator: " ")
        dreamText = picked
        isDreamVisible = true

        dreamTimer?.invalidate()
        dreamTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.isDreamVisible = false
            }
        }
    }

    public func resetSleepTimer() {
        sleepTimer?.invalidate()
        if animState == .sleep {
            animState = .idle
        }
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, !self.isChatOpen, !self.isThinking else { return }
                self.animState = .sleep
                self.currentMood = .sleepy
                self.showBubble("zZz... 😴", duration: 3.5)
            }
        }
    }

    private func startAnimationLoop() {
        animTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.animTime += 0.1
                self.updateMoodDynamically()
            }
        }
    }

    private func startIdleAndDreamTimers() {
        resetSleepTimer()
        restartAutonomousLifeTimer()

        Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                if Double.random(in: 0...1) < 0.35 {
                    self?.showDream()
                }
            }
        }
    }

    public func setAutonomousLifeMode(_ mode: String) {
        self.autonomousLifeMode = mode
        DataManager.shared.savedData.autonomousLifeMode = mode
        DataManager.shared.saveData()
        restartAutonomousLifeTimer()
    }

    public func restartAutonomousLifeTimer() {
        autonomousLifeTimer?.invalidate()
        guard autonomousLifeMode != "off" else { return }

        let interval: TimeInterval
        switch autonomousLifeMode {
        case "lively": interval = 22.0
        case "minimal": interval = 75.0
        default: interval = 40.0 // "normal"
        }

        autonomousLifeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performSubtleAutonomousAction()
            }
        }
    }

    private func performSubtleAutonomousAction() {
        // Pauses when user is interacting: chatting, thinking, or during Focus sessions
        guard !isChatOpen, !isThinking, animState == .idle || animState == .sleep else { return }
        guard !FocusGuardian.shared.isSessionActive else { return }

        if animState == .sleep {
            if Double.random(in: 0...1) < 0.4 {
                showDream()
            }
            return
        }

        let roll = Double.random(in: 0...1)
        if roll < 0.28 {
            // 1. Curious look around
            setTemporaryMood(.concerned, duration: 3.5)
        } else if roll < 0.52 {
            // 2. Loving or relaxed gaze at user
            setTemporaryMood(.love, duration: 4.0)
        } else if roll < 0.72 {
            // 3. Gentle stretch / yawn
            let emotes = ["*stretches paws* 🐾", "*curious ear twitch*", "*gentle sigh* 🫧", "*purrs softly*"]
            if let emote = emotes.randomElement() {
                showBubble(emote, duration: 2.2)
            }
        } else if roll < 0.86 {
            // 4. Happy bounce / flutter
            setTemporaryMood(.happy, duration: 3.0)
        } else {
            // 5. Gentle stroll across screen
            if !isChatOpen {
                WalkerManager.shared.startWalk(species: currentSpecies, isTest: false)
            }
        }
    }

    private var temporaryMoodOverrideUntil: Date = Date.distantPast
    private var temporaryMood: PetMood? = nil

    public func setTemporaryMood(_ mood: PetMood, duration: TimeInterval = 4.0) {
        self.temporaryMood = mood
        self.temporaryMoodOverrideUntil = Date().addingTimeInterval(duration)
        self.currentMood = mood
    }

    private func updateMoodDynamically() {
        if Date() < temporaryMoodOverrideUntil, let temp = temporaryMood {
            currentMood = temp
            return
        }
        temporaryMood = nil

        let cpu = SystemMonitor.shared.cpuPercent
        if animState == .sleep {
            currentMood = .sleepy
        } else if isThinking {
            currentMood = .surprised
        } else if cpu > 85 {
            currentMood = .tired
        } else if cpu > 65 {
            currentMood = .angry
        } else if moodPoints > 90 {
            currentMood = .love
        } else if moodPoints > 75 {
            currentMood = .happy
        } else if moodPoints > 60 {
            currentMood = .excited
        } else if moodPoints > 45 {
            currentMood = .hungry
        } else if moodPoints > 25 {
            currentMood = .sad
        } else {
            currentMood = .crying
        }
    }

    public func cycleMood() {
        let all = PetMood.allCases
        if let idx = all.firstIndex(of: currentMood) {
            let next = all[(idx + 1) % all.count]
            setTemporaryMood(next, duration: 4.0)
            showBubble("\(next.rawValue.capitalized) \(currentSpecies.moodEmoji(for: next))", duration: 1.2)
            SoundEffect.click.play()
        }
    }
}
