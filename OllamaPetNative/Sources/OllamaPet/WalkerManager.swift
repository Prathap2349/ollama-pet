import Foundation
import AppKit
import SwiftUI

// MARK: - Walk Styles

/// How far and how fast the pet moves when it goes for a walk.
public enum WalkStyle: String, CaseIterable {
    /// Short, relaxed walk: roughly one to three pet-widths at a slightly slower pace.
    case stroll
    /// Long walk to the far side of the screen (the original behaviour).
    case crossing
    /// Fast dash across most of the available room, using the `.run` animation state.
    case run
}

// MARK: - Native Companion Locomotion & Autonomous Life Engine

@MainActor
public class WalkerManager: ObservableObject {
    public static let shared = WalkerManager()

    // Gait tuning shared with Pet3DSceneView so the feet stay matched to the window's real movement.
    /// Window speed (points/second) of a walk at walk-speed setting 1.0.
    public static let nominalWalkSpeed: CGFloat = 130.0
    /// A run is this many times faster than a walk.
    public static let runSpeedFactor: CGFloat = 2.1
    /// Gait phase rate (radians/second) the legs were designed around at `nominalWalkSpeed`.
    public static let nominalGaitRate: Double = 3.8
    /// Running uses longer strides, so the legs turn over less than proportionally faster.
    public static let runStrideFactor: Double = 0.7
    /// Pet stage size (points) that `nominalGaitRate` was tuned for.
    public static let referencePetSize: CGFloat = PetWindowLayout.basePetSize

    private static let edgeMargin: CGFloat = 20.0
    private static let strollSpeedFactor: CGFloat = 0.8
    private static let maxRampSeconds: Double = 0.9
    private static let minWalkDistance: CGFloat = 24.0
    private static let frameIntervalNanos: UInt64 = 16_000_000
    private static let strideFadeOutNanos: UInt64 = 350_000_000

    @Published public var isWalking = false
    private var currentWalkTask: Task<Void, Never>?

    public init() {}

    /// Starts a walk. With no `style`, an autonomous walk picks one at random (mostly strolls);
    /// `isTest` keeps the fixed 250 pt test distance.
    public func startWalk(species: PetSpecies, isTest: Bool = false, style: WalkStyle? = nil) {
        guard !isWalking else { return }
        isWalking = true

        // If chat panel is currently open, close panel to allow clean locomotion
        if PetState.shared.isChatOpen {
            PetWindowController.shared.closePanel()
        }

        currentWalkTask?.cancel()
        currentWalkTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            await self.executeSmoothLocomotion(species: species, isTest: isTest, requestedStyle: style)
            // A cancelled walk was already reset by stopWalk(); don't clobber a newer walk's flag.
            if !Task.isCancelled {
                self.isWalking = false
            }
        }
    }

    public func stopWalk() {
        currentWalkTask?.cancel()
        currentWalkTask = nil
        isWalking = false
        PetState.shared.animState = .idle
        PetState.shared.movementDirection = .forward
    }

    // MARK: - Planning

    private struct WalkPlan {
        let targetX: CGFloat
        let speed: CGFloat   // cruise speed, points/second
        let isRun: Bool
    }

    /// Time-based motion profile: smooth speed ramp up, constant cruise, smooth ramp down.
    /// Position is a pure function of elapsed time, so frame rate and scheduling jitter never
    /// change where the pet is, only how often it is redrawn.
    private struct MotionProfile {
        let distance: Double
        let cruiseSpeed: Double
        let ramp: Double
        let duration: Double

        init(distance: CGFloat, cruiseSpeed: CGFloat) {
            self.distance = Double(distance)
            self.cruiseSpeed = Double(cruiseSpeed)
            let travelTime = Double(distance / cruiseSpeed)
            self.ramp = min(WalkerManager.maxRampSeconds, travelTime)
            self.duration = travelTime + ramp
        }

        /// Distance travelled `t` seconds after the start (0...distance).
        func travelled(at t: Double) -> Double {
            guard ramp > 0 else { return distance }
            let t = min(max(t, 0.0), duration)

            // Distance covered while the speed ramps 0 -> cruise with a smoothstep curve.
            func rampDistance(_ u: Double) -> Double {
                let x = u / ramp
                return cruiseSpeed * ramp * (x * x * x - 0.5 * x * x * x * x)
            }

            if t < ramp {
                return rampDistance(t)
            } else if t > duration - ramp {
                return distance - rampDistance(duration - t)
            } else {
                return cruiseSpeed * ramp * 0.5 + cruiseSpeed * (t - ramp)
            }
        }
    }

    private func randomStyle() -> WalkStyle {
        let roll = Double.random(in: 0..<1)
        if roll < 0.55 { return .stroll }
        if roll < 0.80 { return .crossing }
        return .run
    }

    /// Screen the pet is actually on, chosen by how much of the pet stage each screen contains.
    private func screenContaining(_ petRect: NSRect, window: NSWindow?) -> NSScreen? {
        var best: (screen: NSScreen, area: CGFloat)?
        for screen in NSScreen.screens {
            let overlap = screen.frame.intersection(petRect)
            guard !overlap.isNull else { continue }
            let area = overlap.width * overlap.height
            if area > (best?.area ?? 0) {
                best = (screen, area)
            }
        }
        return best?.screen ?? window?.screen ?? NSScreen.main
    }

    /// Range of allowed pet-origin X values on the pet's current screen (Dock and menu bar excluded).
    private func walkBounds(petOrigin: NSPoint, petSize: CGSize, window: NSWindow?) -> ClosedRange<CGFloat>? {
        let petRect = NSRect(origin: petOrigin, size: petSize)
        guard let screen = screenContaining(petRect, window: window) else { return nil }
        let frame = screen.visibleFrame
        let lower = frame.minX + WalkerManager.edgeMargin
        let upper = frame.maxX - petSize.width - WalkerManager.edgeMargin
        guard upper > lower else { return nil }
        return lower...upper
    }

    private func makePlan(
        style: WalkStyle,
        isTest: Bool,
        currentX: CGFloat,
        bounds: ClosedRange<CGFloat>,
        petWidth: CGFloat,
        baseSpeed: CGFloat
    ) -> WalkPlan? {
        let minX = bounds.lowerBound
        let maxX = bounds.upperBound
        let roomLeft = max(0, currentX - minX)
        let roomRight = max(0, maxX - currentX)

        var target: CGFloat
        if isTest {
            let middle = (minX + maxX) / 2
            target = currentX > middle ? (currentX - 250) : (currentX + 250)
        } else {
            switch style {
            case .stroll:
                let minStroll = petWidth * 0.8
                var directions: [CGFloat] = []
                if roomLeft >= minStroll { directions.append(-1) }
                if roomRight >= minStroll { directions.append(1) }
                guard let direction = directions.randomElement() else { return nil }
                let room = direction < 0 ? roomLeft : roomRight
                let distance = min(room, petWidth * CGFloat.random(in: 1.0...3.0))
                target = currentX + direction * distance

            case .crossing:
                // Head for the far half of the screen.
                let halfway = (minX + maxX) / 2
                if currentX > halfway {
                    target = CGFloat.random(in: minX...max(minX, halfway - 40))
                } else {
                    target = CGFloat.random(in: min(maxX, halfway + 40)...maxX)
                }

            case .run:
                let minRun = petWidth * 2.5
                var directions: [CGFloat] = []
                if roomLeft >= minRun { directions.append(-1) }
                if roomRight >= minRun { directions.append(1) }
                let direction = directions.randomElement() ?? (roomRight >= roomLeft ? 1 : -1)
                let room = direction < 0 ? roomLeft : roomRight
                let distance = max(min(room, minRun), room * CGFloat.random(in: 0.5...0.95))
                target = currentX + direction * distance
            }
        }

        target = max(minX, min(maxX, target))
        guard abs(target - currentX) >= WalkerManager.minWalkDistance else { return nil }

        let speed: CGFloat
        switch style {
        case .stroll: speed = baseSpeed * WalkerManager.strollSpeedFactor
        case .crossing: speed = baseSpeed
        case .run: speed = baseSpeed * WalkerManager.runSpeedFactor
        }
        return WalkPlan(targetX: target, speed: speed, isRun: style == .run)
    }

    // MARK: - Locomotion

    private func executeSmoothLocomotion(species: PetSpecies, isTest: Bool, requestedStyle: WalkStyle?) async {
        let petWin = PetWindowController.shared
        guard let win = petWin.window else { return }

        // Real pet size as the window lays it out, and the screen the pet is actually on.
        let petSize = petWin.petStageSize
        let startOrigin = petWin.petOrigin
        guard let startBounds = walkBounds(petOrigin: startOrigin, petSize: petSize, window: win) else { return }

        let style = requestedStyle ?? (isTest ? .crossing : randomStyle())
        let speedMultiplier = max(0.5, min(2.0, DataManager.shared.savedData.walkSpeed ?? 1.0))
        let baseSpeed = WalkerManager.nominalWalkSpeed * CGFloat(speedMultiplier)

        guard let plan = makePlan(
            style: style,
            isTest: isTest,
            currentX: startOrigin.x,
            bounds: startBounds,
            petWidth: petSize.width,
            baseSpeed: baseSpeed
        ) else { return }

        let startX = startOrigin.x
        let movingRight = plan.targetX > startX

        // 1. One continuous turn. The facing direction is set now, and Pet3DSceneView eases its
        // yaw (currentMovementYaw) toward it through the turn, the walk and the pause that follow.
        PetState.shared.movementDirection = movingRight ? .right : .left
        PetState.shared.animState = movingRight ? .turnRight : .turnLeft
        try? await Task.sleep(nanoseconds: UInt64(species.turnDelaySeconds * 1_000_000_000))
        if Task.isCancelled { return }

        // 2. Walk or run
        PetState.shared.animState = plan.isRun ? .run : .walk

        // 3. Time-based locomotion: the position comes from elapsed time, never from a frame count.
        let profile = MotionProfile(distance: abs(plan.targetX - startX), cruiseSpeed: plan.speed)
        let direction: CGFloat = movingRight ? 1 : -1
        let backingScale = max(1.0, win.backingScaleFactor)
        let startTime = ProcessInfo.processInfo.systemUptime

        while !Task.isCancelled {
            let elapsed = ProcessInfo.processInfo.systemUptime - startTime
            var x = startX + direction * CGFloat(profile.travelled(at: elapsed))

            // Stay inside the pet's current screen (it may change if displays are rearranged mid-walk).
            let liveOrigin = petWin.petOrigin
            if let liveBounds = walkBounds(petOrigin: liveOrigin, petSize: petSize, window: win) {
                x = max(liveBounds.lowerBound, min(liveBounds.upperBound, x))
            }
            // Land on whole device pixels so slow movement does not shimmer.
            x = (x * backingScale).rounded() / backingScale

            // Y is read every frame so a drag in the other axis is not undone.
            petWin.updatePetOriginFromDrag(NSPoint(x: x, y: liveOrigin.y))

            if elapsed >= profile.duration { break }
            try? await Task.sleep(nanoseconds: WalkerManager.frameIntervalNanos)
        }
        if Task.isCancelled { return }

        // 4. Keep the walk pose briefly while the stride fades out, then stop.
        try? await Task.sleep(nanoseconds: WalkerManager.strideFadeOutNanos)
        if Task.isCancelled { return }
        PetState.shared.animState = .pause
        try? await Task.sleep(nanoseconds: 500_000_000)
        if Task.isCancelled { return }

        // 5. Inquisitive look around at arrival spot
        PetState.shared.animState = .lookAround
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        if Task.isCancelled { return }

        // 6. Turn forward and resume idle
        PetState.shared.animState = .idle
        PetState.shared.movementDirection = .forward
        DataManager.shared.updatePosition(x: Double(petWin.petOrigin.x), y: Double(petWin.petOrigin.y))
    }

    deinit {
        currentWalkTask?.cancel()
    }
}
