import Foundation
import SwiftUI
import AppKit

// MARK: - Motion States & Gait Presets

public enum WalkGaitPreset: String, CaseIterable, Codable, Identifiable {
    case bouncyMarch = "Bouncy March"
    case stealthProwl = "Stealth Prowl"
    case hoverGlide = "Hover Glide"

    public var id: String { rawValue }
    public var displayName: String { rawValue }

    public var icon: String {
        switch self {
        case .bouncyMarch: return "🥾"
        case .stealthProwl: return "🐾"
        case .hoverGlide: return "🛸"
        }
    }

    public var description: String {
        switch self {
        case .bouncyMarch: return "Bouncy quadruped/biped march with snappy vertical spring"
        case .stealthProwl: return "Low center-of-gravity stride with lateral body sway"
        case .hoverGlide: return "Suspended floating drift with secondary inertial lag"
        }
    }
}

public enum CharacterMotionState: Equatable {
    case idle
    case thinking
    case streamingResponse
    case walking(gait: WalkGaitPreset)
    case dancing(phase: Int)
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
        case .classicSpecies: return "Species-distinct silhouettes with unique anatomy"
        case .kineticSlime: return "Elastic bezier squish physics & translucent core"
        case .cyberSentry: return "Segmented hovering armor plates & pulse visor"
        case .pixelChibiBeast: return "Articulated chibi beast with physics ears & tail"
        }
    }

    public static func model(for species: PetSpecies) -> CharacterStructuralModel {
        return .classicSpecies
    }
}

// MARK: - Particles (Pure Data)

public struct ThoughtSpark: Identifiable {
    public let id: Int
    public var x: CGFloat
    public var y: CGFloat
    public var size: CGFloat
    public var alpha: Double
    public var hue: Double
}

public struct ConfettiParticle: Identifiable {
    public let id: Int
    public var x: CGFloat
    public var y: CGFloat
    public var rotation: Double
    public var color: Color
    public var size: CGSize
    public var alpha: Double
}

public struct WeatherAtmosphereParticle: Identifiable {
    public let id: Int
    public var x: CGFloat
    public var y: CGFloat
    public var size: CGFloat
    public var alpha: Double
    public var length: CGFloat
}

// MARK: - Pure Immutable Animation Snapshot

public struct AnimationSnapshot {
    public let time: Double
    public let breathOffset: CGFloat
    public let blinkProgress: CGFloat
    public let eyeOffset: CGPoint
    public let headTiltAngle: Angle
    public let levitationOffset: CGFloat
    public let tailWagAngle: Angle
    public let squashStretch: CGSize
    public let walkCyclePhase: Double
    public let hopProgress: Double // 0 = ground, 1 = peak jump
    public let wingFlapAngle: Angle
    public let ghostWaveOffset: CGFloat
    public let earTwitchAngle: Angle
    public let pawOffset: CGFloat
    public let thoughtSparks: [ThoughtSpark]
    public let confettiList: [ConfettiParticle]
    public let weatherParticles: [WeatherAtmosphereParticle]

    public static let zero = AnimationSnapshot(
        time: 0,
        breathOffset: 0,
        blinkProgress: 0,
        eyeOffset: .zero,
        headTiltAngle: .zero,
        levitationOffset: 0,
        tailWagAngle: .zero,
        squashStretch: CGSize(width: 1, height: 1),
        walkCyclePhase: 0,
        hopProgress: 0,
        wingFlapAngle: .zero,
        ghostWaveOffset: 0,
        earTwitchAngle: .zero,
        pawOffset: 0,
        thoughtSparks: [],
        confettiList: [],
        weatherParticles: []
    )
}

// MARK: - Motion State Controller (Pure Evaluator, Never Mutates State in Render Pass)

@MainActor
public class CharacterMotionStateMachine: ObservableObject {
    public static let shared = CharacterMotionStateMachine()

    // Only coarse user-driven states are published to avoid high-frequency render-loop invalidations
    @Published public var state: CharacterMotionState = .idle
    @Published public var structuralModel: CharacterStructuralModel = .classicSpecies
    @Published public var gaitPreset: WalkGaitPreset = .bouncyMarch

    public init() {
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
    }

    // MARK: - Pure Functional Snapshot Evaluation (Zero State Mutation)

    public func evaluateSnapshot(
        at time: Double,
        animState: PetAnimState,
        atmosphere: WeatherAtmosphere? = nil,
        isSafeMode: Bool = false
    ) -> AnimationSnapshot {
        // 1. Organic Breathing
        let breathFrequency = animState == .sleep ? 1.4 : (animState == .thinking ? 1.8 : 2.6)
        let breathAmplitude: CGFloat = animState == .sleep ? 2.0 : 3.2
        let breathOffset = CGFloat(sin(time * breathFrequency) * breathAmplitude)

        // 2. Deterministic Organic Micro-Blink (Cycle every 3.8s, closed for ~0.15s)
        let blinkCycle = time.truncatingRemainder(dividingBy: 3.8)
        let blinkProgress: CGFloat
        if blinkCycle < 0.16 && animState != .sleep {
            let half = 0.08
            if blinkCycle < half {
                blinkProgress = CGFloat(blinkCycle / half)
            } else {
                blinkProgress = CGFloat(1.0 - ((blinkCycle - half) / half))
            }
        } else {
            blinkProgress = animState == .sleep ? 1.0 : 0.0
        }

        // 3. Eye Gaze (Calm saccades or conversational tracking)
        let eyeOffset: CGPoint
        if state == .streamingResponse {
            let saccade = sin(time * 14.0)
            eyeOffset = CGPoint(x: CGFloat(saccade * 3.5), y: CGFloat(cos(time * 8.0) * 1.5))
        } else {
            let gazeCycle = sin(time * 0.8)
            eyeOffset = CGPoint(x: CGFloat(gazeCycle * 2.0), y: CGFloat(sin(time * 0.4) * 1.0))
        }

        // 4. Head Tilt & Levitation
        let headTiltAngle: Angle
        let levitationOffset: CGFloat
        let squashStretch: CGSize

        switch state {
        case .idle:
            headTiltAngle = Angle(degrees: sin(time * 1.2) * 2.5)
            levitationOffset = 0.0
            squashStretch = CGSize(
                width: 1.0 - (breathOffset * 0.008),
                height: 1.0 + (breathOffset * 0.010)
            )

        case .thinking:
            headTiltAngle = Angle(degrees: sin(time * 2.0) * 5.0)
            levitationOffset = CGFloat(sin(time * 3.0) * 6.0)
            squashStretch = CGSize(width: 0.98, height: 1.03)

        case .streamingResponse:
            headTiltAngle = Angle(degrees: sin(time * 10.0) * 4.0)
            levitationOffset = CGFloat(abs(sin(time * 8.0)) * 4.5)
            squashStretch = CGSize(
                width: 1.0 + CGFloat(sin(time * 12.0) * 0.03),
                height: 1.0 - CGFloat(sin(time * 12.0) * 0.03)
            )

        case .walking(let gait):
            switch gait {
            case .bouncyMarch:
                let step = sin(time * 8.0)
                headTiltAngle = Angle(degrees: step * 5.0)
                levitationOffset = CGFloat(abs(step) * 10.0)
                squashStretch = CGSize(width: 1.0 - (step * 0.08), height: 1.0 + (step * 0.10))
            case .stealthProwl:
                let prowl = sin(time * 4.0)
                headTiltAngle = Angle(degrees: prowl * 6.0)
                levitationOffset = CGFloat(prowl * 2.5)
                squashStretch = CGSize(width: 1.06, height: 0.95)
            case .hoverGlide:
                headTiltAngle = Angle(degrees: sin(time * 2.5) * 3.5)
                levitationOffset = CGFloat(sin(time * 2.8) * 8.0)
                squashStretch = CGSize(width: 1.02, height: 1.02)
            }

        case .dancing:
            let beat = sin(time * 7.5)
            headTiltAngle = Angle(degrees: beat * 18.0)
            levitationOffset = CGFloat(abs(beat) * 12.0)
            squashStretch = CGSize(width: 1.0 + CGFloat(beat * 0.10), height: 1.0 - CGFloat(beat * 0.08))
        }

        // 5. Species-Specific Kinematics
        let tailWagAngle = Angle(degrees: sin(time * 3.6) * 12.0)
        let walkCyclePhase = (time * 8.0).truncatingRemainder(dividingBy: 2.0 * .pi)
        let hopProgress = max(0.0, sin(time * 6.0))
        let wingFlapAngle = Angle(degrees: sin(time * 8.0) * 24.0)
        let ghostWaveOffset = CGFloat(sin(time * 3.2) * 5.0)

        // Independent ear twitch: every ~4.2s a quick micro-twitch flick, otherwise subtle sway
        let earCycle = time.truncatingRemainder(dividingBy: 4.2)
        let earTwitchAngle: Angle
        if earCycle < 0.25 {
            let flick = sin(earCycle / 0.25 * .pi * 2.0)
            earTwitchAngle = Angle(degrees: flick * 9.0)
        } else {
            earTwitchAngle = Angle(degrees: sin(time * 1.8) * 1.5)
        }

        // Paw bounce & stride kinematics
        let pawOffset: CGFloat
        switch state {
        case .walking:
            pawOffset = CGFloat(sin(time * 8.0) * 4.0)
        case .dancing:
            pawOffset = CGFloat(abs(sin(time * 7.5)) * 6.0)
        default:
            pawOffset = CGFloat(sin(time * 2.6) * 1.0)
        }

        // 6. Thought Sparks (Only if not in Safe Mode and in thinking state)
        var sparks: [ThoughtSpark] = []
        if !isSafeMode && (state == .thinking || animState == .thinking) {
            for i in 0..<5 {
                let sparkT = (time * 1.5 + Double(i) * 0.7).truncatingRemainder(dividingBy: 2.0)
                let life = sparkT / 2.0
                let x = 60.0 + CGFloat(sin(Double(i) * 1.8 + time * 2.0) * 22.0)
                let y = 50.0 - CGFloat(life * 32.0)
                sparks.append(ThoughtSpark(
                    id: i,
                    x: x,
                    y: y,
                    size: CGFloat(4.0 - life * 2.0),
                    alpha: max(0.0, 1.0 - life),
                    hue: 0.6 + Double(i) * 0.08
                ))
            }
        }

        // 7. Confetti (Only during dancing and if particles enabled)
        var confetti: [ConfettiParticle] = []
        if !isSafeMode && animState == .dance {
            let colors: [Color] = [.pink, .yellow, .cyan, .purple, .green, .orange]
            for i in 0..<12 {
                let confT = (time * 1.8 + Double(i) * 0.35).truncatingRemainder(dividingBy: 2.0)
                let progress = confT / 2.0
                let x = 70.0 + CGFloat(cos(Double(i) * 1.2) * 35.0 * progress)
                let y = 60.0 - CGFloat(sin(Double(i) * 0.8) * 45.0 * progress) + CGFloat(progress * progress * 60.0)
                confetti.append(ConfettiParticle(
                    id: i,
                    x: x,
                    y: y,
                    rotation: Double(i) * 45.0 + time * 180.0,
                    color: colors[i % colors.count],
                    size: CGSize(width: 5, height: 8),
                    alpha: max(0.0, 1.0 - progress)
                ))
            }
        }

        // 8. Weather Overlay (Only if enabled and active)
        var weatherParts: [WeatherAtmosphereParticle] = []
        if !isSafeMode, let atmo = atmosphere, atmo == .rain || atmo == .snow {
            let isRain = atmo == .rain
            for i in 0..<8 {
                let pT = (time * (isRain ? 4.0 : 1.2) + Double(i) * 0.4).truncatingRemainder(dividingBy: 2.0)
                let progress = pT / 2.0
                let x = CGFloat(i * 18 + 5)
                let y = CGFloat(progress * 130.0) - 10.0
                weatherParts.append(WeatherAtmosphereParticle(
                    id: i,
                    x: x,
                    y: y,
                    size: isRain ? 1.5 : 3.0,
                    alpha: Double(0.4 + sin(Double(i)) * 0.3),
                    length: isRain ? 10.0 : 0.0
                ))
            }
        }

        return AnimationSnapshot(
            time: time,
            breathOffset: breathOffset,
            blinkProgress: blinkProgress,
            eyeOffset: eyeOffset,
            headTiltAngle: headTiltAngle,
            levitationOffset: levitationOffset,
            tailWagAngle: tailWagAngle,
            squashStretch: squashStretch,
            walkCyclePhase: walkCyclePhase,
            hopProgress: hopProgress,
            wingFlapAngle: wingFlapAngle,
            ghostWaveOffset: ghostWaveOffset,
            earTwitchAngle: earTwitchAngle,
            pawOffset: pawOffset,
            thoughtSparks: sparks,
            confettiList: confetti,
            weatherParticles: weatherParts
        )
    }
}
