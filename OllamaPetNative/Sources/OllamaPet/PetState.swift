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

    private var bubbleTimer: Timer?
    private var dreamTimer: Timer?
    private var sleepTimer: Timer?
    private var animTimer: Timer?

    private let dreams = ["🍕", "🌈", "⭐", "🐟", "🎮", "🏖️", "🚀", "💤", "🌙", "🎵", "🍦", "🦋"]

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

        Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                if Double.random(in: 0...1) < 0.35 {
                    self?.showDream()
                }
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
