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
    public let curiousDriftOffset: CGPoint
    public let armGestureOffset: CGPoint
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
        curiousDriftOffset: .zero,
        armGestureOffset: .zero,
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
        mood: PetMood = .happy,
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
        } else if mood == .concerned {
            eyeOffset = CGPoint(x: CGFloat(sin(time * 1.5) * 1.5), y: -1.0)
        } else if mood == .sad || mood == .crying {
            eyeOffset = CGPoint(x: 0.0, y: 2.0)
        } else {
            let gazeCycle = sin(time * 0.8)
            eyeOffset = CGPoint(x: CGFloat(gazeCycle * 2.0), y: CGFloat(sin(time * 0.4) * 1.0))
        }

        // 4. Head Tilt & Levitation
        let headTiltAngle: Angle
        let levitationOffset: CGFloat
        let squashStretch: CGSize

        // Check music / media reactivity
        let musicActive = MusicManager.shared.isPlaying || (MusicManager.shared.isMediaPlaying && MusicManager.shared.danceWhenMusicDetected)
        let beatAmp = musicActive ? max(0.2, MusicManager.shared.currentBeatAmplitude) : 0.0

        switch state {
        case .idle:
            if musicActive && beatAmp > 0.25 {
                // Beat-level rhythmic reactivity (head bob, bounce, beat drop dance)
                let rhythm = sin(time * (beatAmp > 0.6 ? 7.5 : 5.5))
                let bobAngle = rhythm * Double(beatAmp) * 14.0
                let bounceY = CGFloat(abs(rhythm) * beatAmp * 11.0)
                headTiltAngle = Angle(degrees: bobAngle)
                levitationOffset = bounceY
                squashStretch = CGSize(
                    width: 1.0 + CGFloat(rhythm * beatAmp * 0.08),
                    height: 1.0 - CGFloat(rhythm * beatAmp * 0.08)
                )
            } else {
                switch mood {
                case .proud:
                    headTiltAngle = Angle(degrees: sin(time * 3.5) * 4.0)
                    levitationOffset = CGFloat(abs(sin(time * 4.0)) * 6.0 + 3.0)
                    squashStretch = CGSize(width: 1.05 + CGFloat(sin(time * 4.0) * 0.02), height: 1.06 - CGFloat(sin(time * 4.0) * 0.02))
                case .concerned:
                    headTiltAngle = Angle(degrees: -6.5 + sin(time * 2.0) * 2.5)
                    levitationOffset = -2.0
                    squashStretch = CGSize(width: 0.96, height: 0.98)
                case .angry:
                    headTiltAngle = Angle(degrees: sin(time * 16.0) * 2.0)
                    levitationOffset = 0.0
                    squashStretch = CGSize(width: 1.06, height: 0.94)
                case .sad, .crying:
                    headTiltAngle = Angle(degrees: 5.5 + sin(time * 1.0) * 1.5)
                    levitationOffset = -4.5
                    squashStretch = CGSize(width: 0.97, height: 0.94)
                case .excited:
                    headTiltAngle = Angle(degrees: sin(time * 6.0) * 6.0)
                    levitationOffset = CGFloat(abs(sin(time * 6.0)) * 8.0)
                    squashStretch = CGSize(width: 1.0 + CGFloat(sin(time * 8.0) * 0.06), height: 1.0 - CGFloat(sin(time * 8.0) * 0.06))
                case .love:
                    headTiltAngle = Angle(degrees: sin(time * 1.8) * 5.5)
                    levitationOffset = CGFloat(sin(time * 2.0) * 4.0)
                    squashStretch = CGSize(width: 1.02, height: 1.03)
                case .sleepy:
                    headTiltAngle = Angle(degrees: sin(time * 0.8) * 2.0)
                    levitationOffset = -3.0
                    squashStretch = CGSize(width: 1.02, height: 0.96)
                default:
                    headTiltAngle = Angle(degrees: sin(time * 1.2) * 2.5)
                    levitationOffset = 0.0
                    squashStretch = CGSize(
                        width: 1.0 - (breathOffset * 0.008),
                        height: 1.0 + (breathOffset * 0.010)
                    )
                }
            }

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
            // Natural animal procedural gait (lift, swing, contact, weight transfer, push-off)
            let stepCycle = (time * 8.0).truncatingRemainder(dividingBy: 2.0 * .pi)
            let liftSwing = sin(stepCycle)
            let weightTransfer = cos(stepCycle / 2.0)
            let pushOff = max(0.0, sin(stepCycle * 2.0))

            switch gait {
            case .bouncyMarch:
                headTiltAngle = Angle(degrees: liftSwing * 6.0 + Double(weightTransfer) * 2.5)
                levitationOffset = CGFloat(abs(liftSwing) * 11.0 + pushOff * 3.0)
                squashStretch = CGSize(
                    width: 1.0 - (liftSwing * 0.09) + (CGFloat(pushOff) * 0.04),
                    height: 1.0 + (liftSwing * 0.12) - (CGFloat(pushOff) * 0.04)
                )
            case .stealthProwl:
                headTiltAngle = Angle(degrees: weightTransfer * 7.5 + liftSwing * 3.0)
                levitationOffset = CGFloat(liftSwing * 3.0 - (pushOff * 1.5))
                squashStretch = CGSize(width: 1.07 - CGFloat(abs(liftSwing) * 0.03), height: 0.94 + CGFloat(abs(liftSwing) * 0.03))
            case .hoverGlide:
                let drift = sin(time * 2.8)
                headTiltAngle = Angle(degrees: drift * 4.0)
                levitationOffset = CGFloat(sin(time * 3.2) * 8.0 + (liftSwing * 2.0))
                squashStretch = CGSize(width: 1.02, height: 1.02)
            }

        case .dancing:
            let beat = sin(time * 7.5)
            headTiltAngle = Angle(degrees: beat * 18.0)
            levitationOffset = CGFloat(abs(beat) * 13.0)
            squashStretch = CGSize(width: 1.0 + CGFloat(beat * 0.12), height: 1.0 - CGFloat(beat * 0.10))
        }

        // 5. Species-Specific Kinematics
        let tailWagAngle: Angle
        if mood == .proud || mood == .excited {
            tailWagAngle = Angle(degrees: sin(time * 6.5) * 18.0)
        } else if mood == .concerned || mood == .sad {
            tailWagAngle = Angle(degrees: sin(time * 1.5) * 5.0)
        } else if mood == .angry {
            tailWagAngle = Angle(degrees: sin(time * 10.0) * 16.0)
        } else {
            tailWagAngle = Angle(degrees: sin(time * 3.6) * 12.0)
        }
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

        // 6. Ghost signature curious drift kinematics
        let ghostCycle = time.truncatingRemainder(dividingBy: 7.2)
        let curiousDriftOffset: CGPoint
        if ghostCycle > 1.8 && ghostCycle < 4.8 {
            let t = (ghostCycle - 1.8) / 3.0
            let driftX = CGFloat(sin(t * .pi) * 3.5)
            let driftY = CGFloat(sin(t * .pi * 2.0) * -1.8)
            curiousDriftOffset = CGPoint(x: driftX, y: driftY)
        } else {
            curiousDriftOffset = .zero
        }

        // 7. Arm gesture kinematics
        let armGestureOffset: CGPoint
        var isDancing = animState == .dance
        if case .dancing = state { isDancing = true }

        if animState == .thinking || state == .thinking {
            armGestureOffset = CGPoint(x: 3.5, y: -6.0)
        } else if isDancing {
            armGestureOffset = CGPoint(x: 0, y: CGFloat(sin(time * 6.0) * 3.5 - 3.5))
        } else if animState == .sleep {
            armGestureOffset = CGPoint(x: 0, y: 3.0)
        } else {
            armGestureOffset = .zero
        }

        // 8. Thought Sparks (Only if not in Safe Mode and in thinking state)
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

        // 9. Confetti (Only during dancing and if particles enabled)
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

        // 10. Weather Overlay (Only if enabled and active)
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
            curiousDriftOffset: curiousDriftOffset,
            armGestureOffset: armGestureOffset,
            thoughtSparks: sparks,
            confettiList: confetti,
            weatherParticles: weatherParts
        )
    }
}
