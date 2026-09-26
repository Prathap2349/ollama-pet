import Foundation
import AppKit
import SwiftUI

// MARK: - Native Companion Locomotion & Autonomous Life Engine

@MainActor
public class WalkerManager: ObservableObject {
    public static let shared = WalkerManager()

    @Published public var isWalking = false
    private var autonomousLifeTimer: Timer?
    private var currentWalkTask: Task<Void, Never>?

    public init() {
        startAutonomousLifeMonitor()
    }

    public func startWalk(species: PetSpecies, isTest: Bool = false) {
        guard !isWalking else { return }
        isWalking = true

        // If chat panel is currently open, close panel to allow clean locomotion
        if PetState.shared.isChatOpen {
            PetWindowController.shared.closePanel()
        }

        currentWalkTask?.cancel()
        currentWalkTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            await self.executeSmoothLocomotion(species: species, isTest: isTest)
            self.isWalking = false
        }
    }

    public func stopWalk() {
        currentWalkTask?.cancel()
        currentWalkTask = nil
        isWalking = false
        PetState.shared.animState = .idle
        PetState.shared.movementDirection = .forward
    }

    private func executeSmoothLocomotion(species: PetSpecies, isTest: Bool) async {
        let petWin = PetWindowController.shared
        guard let win = petWin.window, let screen = win.screen ?? NSScreen.main else {
            return
        }

        let sFrame = screen.visibleFrame
        let petSize: CGFloat = 140
        let minX = sFrame.minX + 20
        let maxX = sFrame.maxX - petSize - 20
        let currentX = petWin.petOrigin.x
        let currentY = petWin.petOrigin.y

        // Determine destination: opposite side or random distant spot within current screen
        let targetX: CGFloat
        if isTest {
            targetX = currentX > sFrame.midX ? (currentX - 250) : (currentX + 250)
        } else {
            let halfway = sFrame.midX
            if currentX > halfway {
                targetX = CGFloat.random(in: minX...(halfway - 40))
            } else {
                targetX = CGFloat.random(in: (halfway + 40)...maxX)
            }
        }
        let clampedTargetX = max(minX, min(maxX, targetX))
        let movingRight = clampedTargetX > currentX

        // 1. Physical Turn with species-specific delay
        PetState.shared.animState = movingRight ? .turnRight : .turnLeft
        let turnDelay = species.turnDelaySeconds
        try? await Task.sleep(nanoseconds: UInt64(turnDelay * 1_000_000_000))
        if Task.isCancelled { return }

        // 2. Set movement orientation and walk state
        PetState.shared.movementDirection = movingRight ? .right : .left
        PetState.shared.animState = .walk

        // 3. Smooth physics locomotion with ease-in/ease-out acceleration
        let speedMultiplier = max(0.5, min(2.0, DataManager.shared.savedData.walkSpeed ?? 1.0))
        let distance = abs(clampedTargetX - currentX)
        let baseSpeed: CGFloat = 130.0 * CGFloat(speedMultiplier) // pixels per second
        let totalDuration = max(1.8, Double(distance / baseSpeed))
        let frameRate: Double = 60.0
        let totalFrames = Int(totalDuration * frameRate)
        let frameDelayNano = UInt64((1.0 / frameRate) * 1_000_000_000)

        for frame in 0...totalFrames {
            if Task.isCancelled { break }
            let t = Double(frame) / Double(totalFrames)
            // S-Curve ease-in / ease-out
            let smoothT = t < 0.5 ? 2.0 * t * t : -1.0 + (4.0 - 2.0 * t) * t
            let interpolatedX = currentX + (clampedTargetX - currentX) * CGFloat(smoothT)

            petWin.updatePetOriginFromDrag(NSPoint(x: interpolatedX, y: currentY))
            try? await Task.sleep(nanoseconds: frameDelayNano)
        }

        // 4. Brief pause / curious look at arrival destination
        PetState.shared.animState = .pause
        try? await Task.sleep(nanoseconds: 500_000_000)

        // 5. Turn forward and resume idle
        PetState.shared.animState = .idle
        PetState.shared.movementDirection = .forward
        DataManager.shared.updatePosition(x: Double(petWin.petOrigin.x), y: Double(petWin.petOrigin.y))
    }

    // MARK: - Autonomous Life Loop

    private func startAutonomousLifeMonitor() {
        autonomousLifeTimer?.invalidate()
        autonomousLifeTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.evaluateAutonomousTick()
            }
        }
    }

    private func evaluateAutonomousTick() {
        let saved = DataManager.shared.savedData
        guard saved.autonomousLifeEnabled ?? true else { return }
        guard !isWalking else { return }
        guard !PetState.shared.isChatOpen else { return }
        guard !PetState.shared.isThinking else { return }
        guard !FocusGuardian.shared.isSessionActive else { return }
        guard !(MusicManager.shared.isPlaying && MusicManager.shared.danceWhenMusicDetected) else { return }

        let freq = saved.walkFrequency ?? "normal"
        guard freq != "off" else { return }

        // Chance roll based on frequency
        let roll = Int.random(in: 1...100)
        let walkThreshold: Int
        switch freq {
        case "minimal": walkThreshold = 10 // ~every 8-12 min
        case "normal": walkThreshold = 22  // ~every 3-5 min
        case "lively": walkThreshold = 50  // ~every 1-2 min
        default: walkThreshold = 22
        }

        if roll <= walkThreshold {
            // Trigger autonomous sequence: Look around or stretch, then walk
            Task { @MainActor in
                let idleActions: [PetAnimState] = [.lookAround, .stretch, .watchUser, .curious]
                PetState.shared.animState = idleActions.randomElement() ?? .lookAround
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !PetState.shared.isChatOpen && !self.isWalking else { return }
                self.startWalk(species: PetState.shared.currentSpecies)
            }
        } else if roll <= (walkThreshold + 30) {
            // In-place organic behaviors (watch user, groom, stretch, look around)
            let inPlaceBehaviors: [PetAnimState] = [.watchUser, .lookAround, .groom, .stretch]
            let chosen = inPlaceBehaviors.randomElement() ?? .watchUser
            PetState.shared.animState = chosen
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                if PetState.shared.animState == chosen {
                    PetState.shared.animState = .idle
                }
            }
        }
    }

    deinit {
        autonomousLifeTimer?.invalidate()
        currentWalkTask?.cancel()
    }
}
