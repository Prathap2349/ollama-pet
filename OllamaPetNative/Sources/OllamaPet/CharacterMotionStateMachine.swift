import Foundation
import SwiftUI
import AppKit

// MARK: - Motion States & Presets

public enum WalkGaitPreset: String, CaseIterable, Codable, Identifiable {
    case bouncyMarch = "Bouncy March"
    case stealthProwl = "Stealth Prowl"
    case hoverGlide = "Hover Glide"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .bouncyMarch: return "🥾"
        case .stealthProwl: return "🐾"
        case .hoverGlide: return "🛸"
        }
    }

    public var description: String {
        switch self {
        case .bouncyMarch: return "Energetic vertical bounce with snappy footsteps"
        case .stealthProwl: return "Low center of gravity with subtle predatory prowl"
        case .hoverGlide: return "Zero-ground contact with inertial dampening float"
        }
    }
}

public enum DancePhase: Int, CaseIterable {
    case hipSway = 0
    case jumpTwist = 1
    case confettiPop = 2
    case audioStep = 3

    public var title: String {
        switch self {
        case .hipSway: return "Hip Sway"
        case .jumpTwist: return "Jumping Twists"
        case .confettiPop: return "Celebratory Confetti"
        case .audioStep: return "Beat-Synced Step"
        }
    }
}

public enum CharacterMotionState: Equatable {
    case idle
    case thinking
    case streamingResponse
    case walking(gait: WalkGaitPreset)
    case dancing(phase: DancePhase)

    public static func == (lhs: CharacterMotionState, rhs: CharacterMotionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.thinking, .thinking), (.streamingResponse, .streamingResponse):
            return true
        case (.walking(let g1), .walking(let g2)):
            return g1 == g2
        case (.dancing(let p1), .dancing(let p2)):
            return p1 == p2
        default:
            return false
        }
    }
}

public enum CharacterStructuralModel: String, CaseIterable, Codable, Identifiable {
    case classicSpecies = "Classic Species"
    case kineticSlime = "Kinetic Slime"
    case cyberSentry = "Cyber Sentry"
    case pixelChibiBeast = "Pixel-Chibi Beast"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .classicSpecies: return "🐾"
        case .kineticSlime: return "🫧"
        case .cyberSentry: return "🛡️"
        case .pixelChibiBeast: return "👾"
        }
    }

    public var subtitle: String {
        switch self {
        case .classicSpecies: return "Authentic 7-species companion art"
        case .kineticSlime: return "Elastic bezier squish physics"
        case .cyberSentry: return "Segmented levitating plates & pulse visors"
        case .pixelChibiBeast: return "Articulated limbs & expressive ears"
        }
    }
}

// MARK: - Procedural Particle Systems

public struct ThoughtSpark: Identifiable {
    public let id = UUID()
    public var x: CGFloat
    public var y: CGFloat
    public var vx: CGFloat
    public var vy: CGFloat
    public var size: CGFloat
    public var alpha: Double
    public var hue: Double
    public var life: Double // 0.0 -> 1.0
}

public struct ConfettiParticle: Identifiable {
    public let id = UUID()
    public var x: CGFloat
    public var y: CGFloat
    public var vx: CGFloat
    public var vy: CGFloat
    public var rotation: Double
    public var vRot: Double
    public var color: Color
    public var size: CGSize
    public var life: Double
}

public struct WeatherAtmosphereParticle: Identifiable {
    public let id = UUID()
    public var x: CGFloat
    public var y: CGFloat
    public var vx: CGFloat
    public var vy: CGFloat
    public var size: CGFloat
    public var alpha: Double
    public var length: CGFloat
}

// MARK: - Motion State Machine

@MainActor
public class CharacterMotionStateMachine: ObservableObject {
    public static let shared = CharacterMotionStateMachine()

    @Published public var state: CharacterMotionState = .idle
    @Published public var structuralModel: CharacterStructuralModel = .classicSpecies
    @Published public var gaitPreset: WalkGaitPreset = .bouncyMarch

    // Kinematic parameters
    @Published public var breathOffset: CGFloat = 0.0
    @Published public var blinkProgress: CGFloat = 0.0 // 0 = open, 1 = fully closed
    @Published public var eyeOffset: CGPoint = .zero
    @Published public var headTiltAngle: Angle = .zero
    @Published public var levitationOffset: CGFloat = 0.0
    @Published public var tailWagAngle: Angle = .zero
    @Published public var squashStretch: CGSize = CGSize(width: 1.0, height: 1.0)
    @Published public var musicPulseAmplitude: CGFloat = 0.0

    // Particle arrays
    @Published public var thoughtSparks: [ThoughtSpark] = []
    @Published public var confettiList: [ConfettiParticle] = []
    @Published public var weatherParticles: [WeatherAtmosphereParticle] = []

    // Internal timing & oscillators
    private var time: Double = 0.0
    private var lastUpdateTime: Double = 0.0
    private var nextBlinkTime: Double = 2.0
    private var blinkDuration: Double = 0.16
    private var isBlinking: Bool = false
    private var blinkStartTime: Double = 0.0

    private var nextGazeShiftTime: Double = 3.0
    private var targetEyeOffset: CGPoint = .zero

    private var dancePhaseTimer: Double = 0.0
    private var currentDancePhase: DancePhase = .hipSway

    // Spring physics accumulator
    private var springY: CGFloat = 0.0
    private var springVelocityY: CGFloat = 0.0
    private let springStiffness: CGFloat = 160.0
    private let springDamping: CGFloat = 12.0

    public init() {
        // Load saved structural model & gait
        if let savedModelStr = DataManager.shared.savedData.structuralModel,
           let model = CharacterStructuralModel(rawValue: savedModelStr) {
            self.structuralModel = model
        }
        if let savedGaitStr = DataManager.shared.savedData.walkGaitPreset,
           let gait = WalkGaitPreset(rawValue: savedGaitStr) {
            self.gaitPreset = gait
        }
    }

    public func setStructuralModel(_ model: CharacterStructuralModel) {
        self.structuralModel = model
        DataManager.shared.savedData.structuralModel = model.rawValue
        DataManager.shared.saveData()
    }

    public func setGaitPreset(_ gait: WalkGaitPreset) {
        self.gaitPreset = gait
        DataManager.shared.savedData.walkGaitPreset = gait.rawValue
        DataManager.shared.saveData()
    }

    public func transitionTo(_ newState: CharacterMotionState) {
        self.state = newState
        switch newState {
        case .thinking:
            spawnThoughtSparks()
        case .dancing:
            currentDancePhase = .hipSway
            dancePhaseTimer = 0.0
            spawnConfettiBurst()
        default:
            break
        }
    }

    // MARK: - Frame Update (Called per animation tick from TimelineView)

    public func update(at currentTime: Double, weatherAtmosphere: WeatherAtmosphere? = nil) {
        let dt = lastUpdateTime > 0 ? min(0.1, max(0.001, currentTime - lastUpdateTime)) : 0.016
        lastUpdateTime = currentTime
        time = currentTime

        // 1. Organic Breathing (Smooth Sinusoidal Oscillation)
        let breathSpeed = state == .thinking ? 1.8 : 2.4
        breathOffset = CGFloat(sin(time * breathSpeed) * 3.5)

        // 2. Micro-Blink Simulation (Random intervals 2.5s - 5.5s with fast eye closure)
        updateMicroBlinks(dt: dt)

        // 3. Eye Gaze Tracking & Conversational Head Tracking
        updateGazeAndHead(dt: dt)

        // 4. Tail & Body Kinematics
        updateTailAndLevitation(dt: dt)

        // 5. State-Specific Motion Kinematics
        switch state {
        case .idle:
            squashStretch = CGSize(
                width: 1.0 - (breathOffset * 0.012),
                height: 1.0 + (breathOffset * 0.015)
            )

        case .thinking:
            // Sinusoidal levitation bobbing
            levitationOffset = CGFloat(sin(time * 3.0) * 8.0)
            headTiltAngle = Angle(degrees: sin(time * 1.5) * 6.0)
            updateThoughtSparks(dt: dt)

        case .streamingResponse:
            // Rapid conversational eye tracking and head bounce
            headTiltAngle = Angle(degrees: sin(time * 12.0) * 4.0)
            levitationOffset = CGFloat(abs(sin(time * 8.0)) * 5.0)
            squashStretch = CGSize(
                width: 1.0 + CGFloat(sin(time * 14.0) * 0.04),
                height: 1.0 - CGFloat(sin(time * 14.0) * 0.04)
            )

        case .walking(let gait):
            updateWalkingKinematics(gait: gait, dt: dt)

        case .dancing(let phase):
            updateDancingKinematics(phase: phase, dt: dt)
        }

        // 6. Weather Atmospheric Particles
        if let wx = weatherAtmosphere {
            updateWeatherParticles(atmosphere: wx, dt: dt)
        }
    }

    // MARK: - Kinematic Subsystems

    private func updateMicroBlinks(dt: Double) {
        if !isBlinking {
            if time >= nextBlinkTime {
                isBlinking = true
                blinkStartTime = time
                nextBlinkTime = time + Double.random(in: 2.2...5.2)
            } else {
                blinkProgress = 0.0
            }
        } else {
            let elapsed = time - blinkStartTime
            if elapsed < blinkDuration {
                let half = blinkDuration / 2.0
                if elapsed < half {
                    blinkProgress = CGFloat(elapsed / half)
                } else {
                    blinkProgress = CGFloat(1.0 - ((elapsed - half) / half))
                }
            } else {
                isBlinking = false
                blinkProgress = 0.0
            }
        }
    }

    private func updateGazeAndHead(dt: Double) {
        if state == .streamingResponse {
            // High frequency conversational micro-saccades
            if time >= nextGazeShiftTime {
                targetEyeOffset = CGPoint(
                    x: CGFloat.random(in: -3.5...3.5),
                    y: CGFloat.random(in: -2.0...2.0)
                )
                nextGazeShiftTime = time + Double.random(in: 0.12...0.35)
            }
        } else {
            // Calm natural gaze shifts
            if time >= nextGazeShiftTime {
                targetEyeOffset = CGPoint(
                    x: CGFloat.random(in: -2.5...2.5),
                    y: CGFloat.random(in: -1.5...1.5)
                )
                nextGazeShiftTime = time + Double.random(in: 1.8...4.5)
            }
        }

        // Smoothly interpolate eye position towards target
        let lerpFactor: CGFloat = CGFloat(dt * 10.0)
        eyeOffset.x += (targetEyeOffset.x - eyeOffset.x) * lerpFactor
        eyeOffset.y += (targetEyeOffset.y - eyeOffset.y) * lerpFactor
    }

    private func updateTailAndLevitation(dt: Double) {
        let wagSpeed = state == .dancing(phase: currentDancePhase) ? 12.0 : (state == .streamingResponse ? 8.0 : 3.2)
        tailWagAngle = Angle(degrees: sin(time * wagSpeed) * 14.0)
    }

    private func updateWalkingKinematics(gait: WalkGaitPreset, dt: Double) {
        switch gait {
        case .bouncyMarch:
            // High vertical pop with snappy footfall
            let cycle = sin(time * 8.0)
            levitationOffset = CGFloat(abs(cycle) * 12.0)
            headTiltAngle = Angle(degrees: cycle * 5.0)
            squashStretch = CGSize(
                width: 1.0 - (cycle * 0.08),
                height: 1.0 + (cycle * 0.10)
            )

        case .stealthProwl:
            // Low horizontal glide with smooth lateral prowl
            levitationOffset = CGFloat(sin(time * 4.0) * 3.0)
            headTiltAngle = Angle(degrees: sin(time * 4.0) * 8.0)
            squashStretch = CGSize(width: 1.08, height: 0.94)

        case .hoverGlide:
            // Inertial suspended floating wave with lag
            levitationOffset = CGFloat(sin(time * 2.5) * 9.0)
            headTiltAngle = Angle(degrees: sin(time * 2.0) * 4.0)
            squashStretch = CGSize(width: 1.02, height: 1.02)
        }
    }

    private func updateDancingKinematics(phase: DancePhase, dt: Double) {
        dancePhaseTimer += dt
        if dancePhaseTimer > 2.5 {
            dancePhaseTimer = 0.0
            let nextIndex = (currentDancePhase.rawValue + 1) % DancePhase.allCases.count
            currentDancePhase = DancePhase(rawValue: nextIndex) ?? .hipSway
            if currentDancePhase == .confettiPop {
                spawnConfettiBurst()
            }
        }

        switch currentDancePhase {
        case .hipSway:
            headTiltAngle = Angle(degrees: sin(time * 7.0) * 16.0)
            levitationOffset = CGFloat(abs(sin(time * 7.0)) * 6.0)
            squashStretch = CGSize(width: 1.0 + CGFloat(sin(time * 7.0) * 0.08), height: 1.0)

        case .jumpTwist:
            let pop = abs(sin(time * 9.0))
            levitationOffset = CGFloat(pop * 16.0)
            headTiltAngle = Angle(degrees: sin(time * 9.0) * 22.0)
            squashStretch = CGSize(width: 1.0 - CGFloat(pop * 0.12), height: 1.0 + CGFloat(pop * 0.18))

        case .confettiPop:
            levitationOffset = CGFloat(sin(time * 6.0) * 8.0)
            headTiltAngle = Angle(degrees: sin(time * 5.0) * 10.0)
            updateConfetti(dt: dt)

        case .audioStep:
            // Rhythmic side-step
            let beat = CGFloat(abs(sin(time * 10.0)))
            levitationOffset = beat * 10.0
            headTiltAngle = Angle(degrees: (sin(time * 5.0) > 0 ? 1 : -1) * 12.0)
            squashStretch = CGSize(width: 1.0 - beat * 0.06, height: 1.0 + beat * 0.10)
        }
    }

    // MARK: - Particles Engine

    public func spawnThoughtSparks() {
        thoughtSparks.removeAll()
        for _ in 0..<7 {
            let spark = ThoughtSpark(
                x: CGFloat.random(in: 40...100),
                y: CGFloat.random(in: 30...70),
                vx: CGFloat.random(in: -10...10),
                vy: CGFloat.random(in: -25 ... -12),
                size: CGFloat.random(in: 3...7),
                alpha: Double.random(in: 0.6...1.0),
                hue: Double.random(in: 0.5...0.85),
                life: Double.random(in: 0.0...0.4)
            )
            thoughtSparks.append(spark)
        }
    }

    private func updateThoughtSparks(dt: Double) {
        for i in thoughtSparks.indices {
            thoughtSparks[i].x += thoughtSparks[i].vx * CGFloat(dt)
            thoughtSparks[i].y += thoughtSparks[i].vy * CGFloat(dt)
            thoughtSparks[i].life += dt * 0.6
            thoughtSparks[i].alpha = max(0, 1.0 - thoughtSparks[i].life)
            if thoughtSparks[i].life >= 1.0 {
                // Respawn spark
                thoughtSparks[i].x = CGFloat.random(in: 45...95)
                thoughtSparks[i].y = CGFloat.random(in: 45...75)
                thoughtSparks[i].life = 0.0
                thoughtSparks[i].alpha = 0.9
            }
        }
    }

    public func spawnConfettiBurst() {
        let colors: [Color] = [.pink, .yellow, .purple, .cyan, .green, .orange]
        confettiList.removeAll()
        for _ in 0..<24 {
            let confetti = ConfettiParticle(
                x: 70 + CGFloat.random(in: -20...20),
                y: 60 + CGFloat.random(in: -10...10),
                vx: CGFloat.random(in: -45...45),
                vy: CGFloat.random(in: -70 ... -25),
                rotation: Double.random(in: 0...360),
                vRot: Double.random(in: -180...180),
                color: colors.randomElement() ?? .yellow,
                size: CGSize(width: CGFloat.random(in: 4...8), height: CGFloat.random(in: 6...12)),
                life: 0.0
            )
            confettiList.append(confetti)
        }
    }

    private func updateConfetti(dt: Double) {
        for i in confettiList.indices {
            confettiList[i].vy += 120.0 * CGFloat(dt) // Gravity
            confettiList[i].x += confettiList[i].vx * CGFloat(dt)
            confettiList[i].y += confettiList[i].vy * CGFloat(dt)
            confettiList[i].rotation += confettiList[i].vRot * dt
            confettiList[i].life += dt * 0.7
        }
        confettiList.removeAll { $0.life >= 1.0 }
    }

    private func updateWeatherParticles(atmosphere: WeatherAtmosphere, dt: Double) {
        switch atmosphere {
        case .rain, .thunderstorm:
            if weatherParticles.count < 20 && Double.random(in: 0...1) < 0.4 {
                weatherParticles.append(
                    WeatherAtmosphereParticle(
                        x: CGFloat.random(in: 0...140),
                        y: -10,
                        vx: -15,
                        vy: CGFloat.random(in: 140...220),
                        size: 1.5,
                        alpha: Double.random(in: 0.4...0.8),
                        length: CGFloat.random(in: 6...14)
                    )
                )
            }

        case .snow:
            if weatherParticles.count < 16 && Double.random(in: 0...1) < 0.3 {
                weatherParticles.append(
                    WeatherAtmosphereParticle(
                        x: CGFloat.random(in: 0...140),
                        y: -8,
                        vx: CGFloat.random(in: -12...12),
                        vy: CGFloat.random(in: 25...55),
                        size: CGFloat.random(in: 2...5),
                        alpha: Double.random(in: 0.5...0.9),
                        length: 0
                    )
                )
            }

        default:
            weatherParticles.removeAll()
            return
        }

        for i in weatherParticles.indices {
            weatherParticles[i].x += weatherParticles[i].vx * CGFloat(dt)
            weatherParticles[i].y += weatherParticles[i].vy * CGFloat(dt)
        }
        weatherParticles.removeAll { $0.y > 150 || $0.x < -20 || $0.x > 160 }
    }
}
