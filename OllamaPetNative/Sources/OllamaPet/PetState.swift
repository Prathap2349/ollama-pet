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

    @Published public var animTime: Double = 0.0

    // Pomodoro
    @Published public var pomoSeconds: Int = 25 * 60
    @Published public var pomoRunning: Bool = false
    @Published public var pomoIsBreak: Bool = false

    // RPS & Trivia
    @Published public var rpsScore: Int = 0
    @Published public var rpsResult: String = ""
    @Published public var triviaScore: Int = 0
    @Published public var triviaQuestion: String = ""
    @Published public var triviaAnswers: [String] = []
    @Published public var triviaCorrectAnswer: String = ""
    @Published public var triviaAnswered: Bool = false

    // Companion Mode
    @Published public var companionMode: Bool = false

    private var bubbleTimer: Timer?
    private var dreamTimer: Timer?
    private var sleepTimer: Timer?
    private var animTimer: Timer?
    private var pomoTimer: Timer?

    private let dreams = ["🍕", "🌈", "⭐", "🐟", "🎮", "🏖️", "🚀", "💤", "🌙", "🎵", "🍦", "🦋"]

    public init() {
        loadFromPersistence()
        startAnimationLoop()
        startIdleAndDreamTimers()
    }

    private func loadFromPersistence() {
        let data = DataManager.shared.savedData
        if let sp = PetSpecies(rawValue: data.currentChar) {
            self.currentSpecies = sp
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

    private func updateMoodDynamically() {
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
            currentMood = next
            showBubble("\(next.rawValue.capitalized) \(currentSpecies.moodEmoji(for: next))", duration: 1.2)
            SoundEffect.click.play()
        }
    }

    // MARK: - Pomodoro Logic

    public func togglePomo() {
        if pomoRunning {
            pomoRunning = false
            pomoTimer?.invalidate()
        } else {
            pomoRunning = true
            showBubble(pomoIsBreak ? "Break started! ☕" : "Focus time! 💼")
            pomoTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    if self.pomoSeconds > 0 {
                        self.pomoSeconds -= 1
                    } else {
                        self.pomoTimer?.invalidate()
                        self.pomoRunning = false
                        if self.pomoIsBreak {
                            self.showBubble("Break over! Back to work 💪", duration: 4.0)
                            self.pomoSeconds = 25 * 60
                            self.pomoIsBreak = false
                        } else {
                            self.showBubble("Great work! Take a break 🎉", duration: 4.0)
                            self.pomoSeconds = 5 * 60
                            self.pomoIsBreak = true
                            self.moodPoints = min(100.0, self.moodPoints + 15.0)
                        }
                        DataManager.shared.postNotification(
                            title: "Pomodoro!",
                            body: self.pomoIsBreak ? "Work session done! Take a break." : "Break over, back to work!"
                        )
                    }
                }
            }
        }
    }

    public func resetPomo() {
        pomoTimer?.invalidate()
        pomoRunning = false
        pomoIsBreak = false
        pomoSeconds = 25 * 60
    }

    // MARK: - RPS Logic

    public func playRPS(choice: String) {
        let cpuChoices = ["✊", "✋", "✌️"]
        let cpu = cpuChoices.randomElement() ?? "✊"

        if choice == cpu {
            rpsResult = "Tie! \(choice) vs \(cpu) 🤝"
            showBubble("Tie!", duration: 1.2)
        } else if (choice == "✊" && cpu == "✌️") || (choice == "✋" && cpu == "✊") || (choice == "✌️" && cpu == "✋") {
            rpsScore += 1
            rpsResult = "You win! \(choice) beats \(cpu) 🎉"
            showBubble("You win! 🎉", duration: 1.5)
            moodPoints = min(100.0, moodPoints + 5.0)
        } else {
            rpsResult = "You lose! \(cpu) beats \(choice) 😅"
            showBubble("I win! 😏", duration: 1.5)
        }
        SoundEffect.click.play()
    }

    // MARK: - Trivia Logic

    public func fetchTrivia() async {
        guard let url = URL(string: "https://opentdb.com/api.php?amount=1&type=multiple&difficulty=easy") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            struct TriviaResp: Decodable {
                struct Item: Decodable {
                    let question: String
                    let correct_answer: String
                    let incorrect_answers: [String]
                }
                let results: [Item]
            }

            let resp = try JSONDecoder().decode(TriviaResp.self, from: data)
            if let first = resp.results.first {
                let cleanQ = first.question
                    .replacingOccurrences(of: "&quot;", with: "\"")
                    .replacingOccurrences(of: "&#039;", with: "'")
                    .replacingOccurrences(of: "&amp;", with: "&")
                let cleanCorrect = first.correct_answer
                    .replacingOccurrences(of: "&quot;", with: "\"")
                    .replacingOccurrences(of: "&#039;", with: "'")
                let cleanIncorrect = first.incorrect_answers.map {
                    $0.replacingOccurrences(of: "&quot;", with: "\"")
                      .replacingOccurrences(of: "&#039;", with: "'")
                }

                self.triviaQuestion = cleanQ
                self.triviaCorrectAnswer = cleanCorrect
                var answers = cleanIncorrect
                answers.append(cleanCorrect)
                self.triviaAnswers = answers.shuffled()
                self.triviaAnswered = false
            }
        } catch {
            self.triviaQuestion = "Could not load trivia question (offline?)"
            self.triviaAnswers = []
        }
    }

    public func answerTrivia(_ answer: String) {
        guard !triviaAnswered else { return }
        triviaAnswered = true

        if answer == triviaCorrectAnswer {
            triviaScore += 1
            showBubble("Correct! 🧠", duration: 1.5)
            moodPoints = min(100.0, moodPoints + 5.0)
            SoundEffect.receive.play()
        } else {
            showBubble("Wrong! 😅", duration: 1.5)
            SoundEffect.alert.play()
        }

        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await self.fetchTrivia()
        }
    }
}
