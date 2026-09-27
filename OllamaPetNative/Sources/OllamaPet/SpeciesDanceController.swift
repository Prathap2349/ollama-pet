import Foundation
import SceneKit
import SwiftUI

// MARK: - Dance Pattern Definition

public enum DancePattern: String, CaseIterable {
    case patternA = "A" // Signature species groove
    case patternB = "B" // Dynamic variation & footwork/wings/floating
    case patternC = "C" // High-energy accent & beat-drop showcase

    public var name: String { rawValue }
}

// MARK: - Species Dance Controller

public final class SpeciesDanceController {
    public static let shared = SpeciesDanceController()

    // State Tracking
    private var danceStartTime: TimeInterval?
    private var lastPhraseIndex: Int = -1
    private var currentPattern: DancePattern = .patternA
    private var lastSpecies: PetSpecies?
    private var lastBeatCount: Int = -1

    // 8-Count Pattern Rotation Sequence (musically natural phrasing)
    private let patternSequence: [DancePattern] = [
        .patternA, .patternA, .patternB, .patternA, .patternC, .patternB
    ]

    public init() {}

    public func reset(rig: Pet3DRig?) {
        guard let rig = rig else { return }
        danceStartTime = nil
        lastPhraseIndex = -1
        lastBeatCount = -1

        // Smoothly restore neutral limb rotations
        rig.rootNode.eulerAngles = SCNVector3Zero
        rig.rootNode.position = SCNVector3Zero
        rig.bodyNode.eulerAngles = SCNVector3Zero

        rig.leftWingNode?.eulerAngles = SCNVector3Zero
        rig.rightWingNode?.eulerAngles = SCNVector3Zero

        rig.frontLeftLeg?.eulerAngles = SCNVector3Zero
        rig.frontLeftShin?.eulerAngles = SCNVector3Zero
        rig.frontLeftPaw?.eulerAngles = SCNVector3Zero
        rig.frontRightLeg?.eulerAngles = SCNVector3Zero
        rig.frontRightShin?.eulerAngles = SCNVector3Zero
        rig.frontRightPaw?.eulerAngles = SCNVector3Zero

        rig.backLeftLeg?.eulerAngles = SCNVector3Zero
        rig.backLeftShin?.eulerAngles = SCNVector3Zero
        rig.backLeftPaw?.eulerAngles = SCNVector3Zero
        rig.backRightLeg?.eulerAngles = SCNVector3Zero
        rig.backRightShin?.eulerAngles = SCNVector3Zero
        rig.backRightPaw?.eulerAngles = SCNVector3Zero

        rig.leftShoulderNode?.eulerAngles = SCNVector3Zero
        rig.leftArmNode?.eulerAngles = SCNVector3Zero
        rig.leftElbowNode?.eulerAngles = SCNVector3Zero
        rig.leftWristNode?.eulerAngles = SCNVector3Zero
        rig.leftHandNode?.eulerAngles = SCNVector3Zero

        rig.rightShoulderNode?.eulerAngles = SCNVector3Zero
        rig.rightArmNode?.eulerAngles = SCNVector3Zero
        rig.rightElbowNode?.eulerAngles = SCNVector3Zero
        rig.rightWristNode?.eulerAngles = SCNVector3Zero
        rig.rightHandNode?.eulerAngles = SCNVector3Zero

        rig.leftEarNode?.eulerAngles = SCNVector3Zero
        rig.rightEarNode?.eulerAngles = SCNVector3Zero
        rig.tailNode?.eulerAngles = SCNVector3Zero
        for seg in rig.tailSegments {
            seg.eulerAngles = SCNVector3Zero
        }
    }

    public func update(
        rig: Pet3DRig,
        species: PetSpecies,
        time t: TimeInterval,
        beatAmplitude: CGFloat,
        beatIntensity: BeatIntensity,
        energyLevel: MediaEnergyLevel,
        isMusicActive: Bool,
        bobY: inout CGFloat,
        scaleY: inout CGFloat,
        scaleXZ: inout CGFloat,
        targetHeadPitch: inout CGFloat,
        targetHeadRoll: inout CGFloat,
        targetHeadYaw: inout CGFloat
    ) {
        guard isMusicActive else {
            reset(rig: rig)
            return
        }

        if danceStartTime == nil || lastSpecies != species {
            danceStartTime = t
            lastSpecies = species
            lastPhraseIndex = 0
            currentPattern = .patternA
            print("[Dance] Species = \(species.rawValue), Pattern = A")
        }

        let elapsed = t - (danceStartTime ?? t)

        // Standard 118 BPM beat timing (~0.5085s per beat, 4.068s per 8-count phrase)
        let beatDuration: Double = 60.0 / 118.0
        let phraseDuration: Double = beatDuration * 8.0

        let phraseIndex = Int(elapsed / phraseDuration)
        if phraseIndex != lastPhraseIndex {
            lastPhraseIndex = phraseIndex
            currentPattern = patternSequence[phraseIndex % patternSequence.count]
            print("[Dance] Species = \(species.rawValue), Pattern = \(currentPattern.name)")
        }

        let phraseProgress = (elapsed / phraseDuration).truncatingRemainder(dividingBy: 1.0)
        let count = Int(phraseProgress * 8.0) // 0...7 representing counts 1...8
        let subPhase = (phraseProgress * 8.0).truncatingRemainder(dividingBy: 1.0) // 0.0...1.0 within beat

        // Beat Intensity Multiplier
        let intensity: CGFloat
        switch beatIntensity {
        case .low:
            intensity = 0.65
        case .medium:
            intensity = 1.0
        case .strong:
            intensity = 1.45
        case .beatDrop:
            intensity = 1.90
        }

        // Music Start Transition (Requirements: IDLE -> notices music -> small reaction -> enters dance)
        let introDuration = 1.8
        let isIntro = elapsed < introDuration
        let introProgress = min(1.0, elapsed / introDuration)

        if isIntro {
            applyIntroReaction(
                species: species,
                rig: rig,
                introProgress: introProgress,
                intensity: intensity,
                bobY: &bobY,
                targetHeadPitch: &targetHeadPitch,
                targetHeadRoll: &targetHeadRoll,
                targetHeadYaw: &targetHeadYaw
            )
            if introProgress < 0.65 {
                // In early intro, notice reaction dominates
                return
            }
        }

        // Blend factor from intro into full dance choreography
        let choreoWeight: CGFloat = isIntro ? CGFloat((introProgress - 0.65) / 0.35) : 1.0

        // 8-Count Choreography Execution per Species
        switch species {
        case .cat:
            animateCatDance(
                rig: rig,
                pattern: currentPattern,
                count: count,
                subPhase: subPhase,
                intensity: intensity * choreoWeight,
                isBeatDrop: beatIntensity == .beatDrop,
                bobY: &bobY,
                scaleY: &scaleY,
                targetHeadPitch: &targetHeadPitch,
                targetHeadRoll: &targetHeadRoll,
                targetHeadYaw: &targetHeadYaw
            )

        case .dragon:
            animateDragonDance(
                rig: rig,
                pattern: currentPattern,
                count: count,
                subPhase: subPhase,
                intensity: intensity * choreoWeight,
                isBeatDrop: beatIntensity == .beatDrop,
                bobY: &bobY,
                scaleY: &scaleY,
                targetHeadPitch: &targetHeadPitch,
                targetHeadRoll: &targetHeadRoll,
                targetHeadYaw: &targetHeadYaw
            )

        case .robot:
            animateRobotDance(
                rig: rig,
                pattern: currentPattern,
                count: count,
                subPhase: subPhase,
                intensity: intensity * choreoWeight,
                isBeatDrop: beatIntensity == .beatDrop,
                bobY: &bobY,
                scaleY: &scaleY,
                targetHeadPitch: &targetHeadPitch,
                targetHeadRoll: &targetHeadRoll,
                targetHeadYaw: &targetHeadYaw
            )

        case .robotcat:
            animateRobotCatDance(
                rig: rig,
                pattern: currentPattern,
                count: count,
                subPhase: subPhase,
                intensity: intensity * choreoWeight,
                isBeatDrop: beatIntensity == .beatDrop,
                bobY: &bobY,
                scaleY: &scaleY,
                targetHeadPitch: &targetHeadPitch,
                targetHeadRoll: &targetHeadRoll,
                targetHeadYaw: &targetHeadYaw
            )

        case .ghost:
            animateGhostDance(
                rig: rig,
                pattern: currentPattern,
                count: count,
                subPhase: subPhase,
                intensity: intensity * choreoWeight,
                isBeatDrop: beatIntensity == .beatDrop,
                bobY: &bobY,
                scaleY: &scaleY,
                scaleXZ: &scaleXZ,
                targetHeadPitch: &targetHeadPitch,
                targetHeadRoll: &targetHeadRoll,
                targetHeadYaw: &targetHeadYaw
            )

        case .fox:
            animateFoxDance(
                rig: rig,
                pattern: currentPattern,
                count: count,
                subPhase: subPhase,
                intensity: intensity * choreoWeight,
                isBeatDrop: beatIntensity == .beatDrop,
                bobY: &bobY,
                scaleY: &scaleY,
                targetHeadPitch: &targetHeadPitch,
                targetHeadRoll: &targetHeadRoll,
                targetHeadYaw: &targetHeadYaw
            )

        case .bunny:
            animateBunnyDance(
                rig: rig,
                pattern: currentPattern,
                count: count,
                subPhase: subPhase,
                intensity: intensity * choreoWeight,
                isBeatDrop: beatIntensity == .beatDrop,
                bobY: &bobY,
                scaleY: &scaleY,
                scaleXZ: &scaleXZ,
                targetHeadPitch: &targetHeadPitch,
                targetHeadRoll: &targetHeadRoll,
                targetHeadYaw: &targetHeadYaw
            )
        }
    }

    // MARK: - Music Start Intro Transition (Requirement: IDLE -> notices music -> small reaction -> enters dance)

    private func applyIntroReaction(
        species: PetSpecies,
        rig: Pet3DRig,
        introProgress: Double,
        intensity: CGFloat,
        bobY: inout CGFloat,
        targetHeadPitch: inout CGFloat,
        targetHeadRoll: inout CGFloat,
        targetHeadYaw: inout CGFloat
    ) {
        if introProgress < 0.40 {
            // Stage 1: Notices music (curious ear flick, head cocked, eyes widen)
            switch species {
            case .cat, .fox:
                rig.leftEarNode?.eulerAngles.z = -0.15 * intensity
                rig.rightEarNode?.eulerAngles.z = 0.25 * intensity
                targetHeadRoll = 0.22 * intensity
                targetHeadPitch = 0.08
            case .robot, .robotcat:
                targetHeadYaw = 0.28 * intensity
                targetHeadPitch = -0.05
            case .dragon:
                targetHeadPitch = 0.20 * intensity
                rig.leftWingNode?.eulerAngles.z = 0.18 * intensity
                rig.rightWingNode?.eulerAngles.z = -0.18 * intensity
            case .bunny:
                rig.leftEarNode?.eulerAngles.x = 0.35 * intensity
                rig.rightEarNode?.eulerAngles.x = 0.35 * intensity
                bobY -= 0.03
            case .ghost:
                bobY += 0.06 * intensity
                rig.rootNode.eulerAngles.z = 0.12 * intensity
            }
        } else {
            // Stage 2: Small species reaction before entering full groove
            switch species {
            case .cat:
                // Head turn + first front paw tap
                targetHeadYaw = -0.20
                rig.frontLeftLeg?.eulerAngles.x = 0.28 * intensity
                rig.frontLeftPaw?.eulerAngles.x = -0.30
                rig.tailNode?.eulerAngles.y = 0.35 * intensity
            case .robot:
                // Visor snap + shoulder lock
                targetHeadYaw = -0.35
                rig.leftShoulderNode?.eulerAngles.x = 0.45 * intensity
                rig.rightElbowNode?.eulerAngles.x = 0.90
            case .robotcat:
                targetHeadYaw = -0.25
                rig.frontLeftLeg?.eulerAngles.x = 0.30
                rig.tailNode?.eulerAngles.y = 0.30
            case .dragon:
                // Head/wing reaction -> slight hover
                bobY += 0.08 * intensity
                rig.leftWingNode?.eulerAngles.z = 0.45 * intensity
                rig.rightWingNode?.eulerAngles.z = -0.45 * intensity
            case .ghost:
                // Float upward + slight turn
                bobY += 0.10 * intensity
                rig.rootNode.eulerAngles.y = 0.20 * intensity
            case .fox:
                // Ear perk + weight shift
                rig.frontRightLeg?.eulerAngles.x = 0.30 * intensity
                rig.tailNode?.eulerAngles.y = 0.50 * intensity
            case .bunny:
                // Ear bounce -> crouch -> first test hop
                bobY += 0.07 * intensity
                rig.leftEarNode?.eulerAngles.x = -0.25
                rig.rightEarNode?.eulerAngles.x = -0.25
            }
        }
    }

    // MARK: - 1. CAT CHOREOGRAPHY
    // Feline weight shifting, alternating front-paw taps, small hip/body sway,
    // tail rhythm, head nods, occasional crouch->rise, playful paw gesture, no constant jumping

    private func animateCatDance(
        rig: Pet3DRig,
        pattern: DancePattern,
        count: Int,
        subPhase: Double,
        intensity: CGFloat,
        isBeatDrop: Bool,
        bobY: inout CGFloat,
        scaleY: inout CGFloat,
        targetHeadPitch: inout CGFloat,
        targetHeadRoll: inout CGFloat,
        targetHeadYaw: inout CGFloat
    ) {
        let smoothSub = CGFloat(sin(subPhase * .pi))
        let sideSign: CGFloat = (count % 4 < 2) ? 1.0 : -1.0

        // Feline Weight Shifting: Lateral body & root sway
        rig.rootNode.eulerAngles.z = sideSign * 0.07 * intensity
        rig.bodyNode.eulerAngles.y = sideSign * 0.06 * intensity

        // Smooth non-jarring vertical groove (avoid constant jumping)
        bobY += smoothSub * 0.025 * intensity

        // Tail following rhythm with multi-segment wave lag
        let tailBase = CGFloat(sin(Double(count) * 0.8 + subPhase * .pi * 2.0)) * 0.55 * intensity
        rig.tailNode?.eulerAngles.y = tailBase
        for (i, seg) in rig.tailSegments.enumerated() {
            let lag = Double(i) * 0.25
            seg.eulerAngles.y = CGFloat(sin(Double(count) * 0.8 + subPhase * .pi * 2.0 - lag)) * 0.35 * intensity
        }

        // Head nods with the beat
        targetHeadPitch += (smoothSub * 0.07 - 0.02) * intensity
        targetHeadRoll += sideSign * 0.04 * intensity

        // Alternating Front-Paw Taps across the 8-count phrase
        switch count {
        case 0, 1: // Count 1, 2: Left paw tap and follow-through
            let tapLift = CGFloat(sin(subPhase * .pi)) * 0.28 * intensity
            rig.frontLeftLeg?.eulerAngles.x = tapLift
            rig.frontLeftShin?.eulerAngles.x = -tapLift * 0.8
            rig.frontLeftPaw?.eulerAngles.x = -tapLift * 0.5
            rig.frontRightLeg?.eulerAngles.x = 0.0

        case 2, 3: // Count 3, 4: Right paw tap & accent
            let tapLift = CGFloat(sin(subPhase * .pi)) * 0.28 * intensity
            rig.frontRightLeg?.eulerAngles.x = tapLift
            rig.frontRightShin?.eulerAngles.x = -tapLift * 0.8
            rig.frontRightPaw?.eulerAngles.x = -tapLift * 0.5
            rig.frontLeftLeg?.eulerAngles.x = 0.0

            if count == 3 && pattern == .patternC {
                // Playful paw gesture on count 4 accent
                rig.frontRightLeg?.eulerAngles.x = 0.60 * intensity
                rig.frontRightPaw?.eulerAngles.x = 0.30
                targetHeadYaw = 0.15
            }

        case 4, 5: // Count 5, 6: Variation - Crouch -> Rise
            if pattern == .patternB || pattern == .patternC {
                let crouch = CGFloat(sin(subPhase * .pi)) * 0.05 * intensity
                bobY -= crouch
                scaleY -= crouch * 0.8
                rig.frontLeftLeg?.eulerAngles.x = -0.15 * intensity
                rig.frontRightLeg?.eulerAngles.x = -0.15 * intensity
                rig.backLeftLeg?.eulerAngles.x = -0.22 * intensity
                rig.backRightLeg?.eulerAngles.x = -0.22 * intensity
            } else {
                let tapLift = CGFloat(sin(subPhase * .pi)) * 0.22 * intensity
                rig.frontLeftLeg?.eulerAngles.x = tapLift
                rig.frontRightLeg?.eulerAngles.x = 0.0
            }

        case 6: // Count 7: Preparation
            rig.frontLeftLeg?.eulerAngles.x = 0.08
            rig.frontRightLeg?.eulerAngles.x = 0.08
            targetHeadPitch = -0.05

        case 7: // Count 8: Stronger accent / Playful paw gesture
            let accentPaw = CGFloat(sin(subPhase * .pi)) * 0.65 * intensity
            rig.frontLeftLeg?.eulerAngles.x = accentPaw
            rig.frontLeftShin?.eulerAngles.x = -accentPaw * 0.7
            rig.frontLeftPaw?.eulerAngles.x = 0.35
            targetHeadYaw = -0.20 * intensity
            if isBeatDrop {
                bobY += 0.05 * intensity
            }

        default:
            break
        }
    }

    // MARK: - 2. DRAGON CHOREOGRAPHY
    // Wing sweeps, body rise/hover, tail arcs, torso lean/rotation, wing spread on strong beats,
    // occasional larger wing accent on beat drops, feels aerial rather than ground jumping

    private func animateDragonDance(
        rig: Pet3DRig,
        pattern: DancePattern,
        count: Int,
        subPhase: Double,
        intensity: CGFloat,
        isBeatDrop: Bool,
        bobY: inout CGFloat,
        scaleY: inout CGFloat,
        targetHeadPitch: inout CGFloat,
        targetHeadRoll: inout CGFloat,
        targetHeadYaw: inout CGFloat
    ) {
        // Body rise/hover: elevated suspended aerial posture
        let hoverBaseline: CGFloat = 0.07 * intensity
        let hoverWave = CGFloat(sin(Double(count) * 0.75 + subPhase * .pi)) * 0.04 * intensity
        bobY += hoverBaseline + hoverWave

        // Torso lean & rotation
        let torsoRoll = CGFloat(sin(Double(count) * 0.78 + subPhase * .pi)) * 0.12 * intensity
        rig.bodyNode.eulerAngles.z = torsoRoll
        rig.bodyNode.eulerAngles.y = CGFloat(cos(Double(count) * 0.78)) * 0.08 * intensity

        // Legs hang naturally during aerial hover with gentle stabilizing sway
        rig.frontLeftLeg?.eulerAngles.x = 0.10 + CGFloat(sin(subPhase * .pi)) * 0.06
        rig.frontRightLeg?.eulerAngles.x = 0.10 - CGFloat(sin(subPhase * .pi)) * 0.06
        rig.backLeftLeg?.eulerAngles.x = -0.15
        rig.backRightLeg?.eulerAngles.x = -0.15

        // Tail Arcs: majestic undulating wave
        rig.tailNode?.eulerAngles.y = CGFloat(sin(Double(count) * 0.8 + subPhase * .pi)) * 0.65 * intensity
        rig.tailNode?.eulerAngles.x = 0.18 + CGFloat(cos(Double(count) * 0.8)) * 0.20 * intensity
        for (i, seg) in rig.tailSegments.enumerated() {
            let lag = Double(i) * 0.20
            seg.eulerAngles.y = CGFloat(sin(Double(count) * 0.8 + subPhase * .pi - lag)) * 0.40 * intensity
        }

        // Wing Choreography across 8 counts
        let baseWingSpread: CGFloat = 0.35 + (intensity > 1.2 ? 0.25 : 0.0)
        let wingSweep = CGFloat(sin(subPhase * .pi * 2.0)) * 0.42 * intensity

        switch count {
        case 0, 1: // Count 1, 2: Majestic wing downsweep & follow-through
            rig.leftWingNode?.eulerAngles.z = baseWingSpread + wingSweep
            rig.rightWingNode?.eulerAngles.z = -baseWingSpread - wingSweep
            rig.leftWingNode?.eulerAngles.y = 0.15 * intensity
            rig.rightWingNode?.eulerAngles.y = -0.15 * intensity
            targetHeadPitch = 0.08

        case 2, 3: // Count 3, 4: Wing upsweep & accent
            rig.leftWingNode?.eulerAngles.z = baseWingSpread - wingSweep * 0.8
            rig.rightWingNode?.eulerAngles.z = -baseWingSpread + wingSweep * 0.8
            if count == 3 {
                // Accent wing spread
                rig.leftWingNode?.eulerAngles.z += 0.30 * intensity
                rig.rightWingNode?.eulerAngles.z -= 0.30 * intensity
                targetHeadPitch = 0.18 * intensity
            }

        case 4, 5: // Count 5, 6: Wing soar variation
            let soarRoll = CGFloat(sin(subPhase * .pi)) * 0.25 * intensity
            rig.leftWingNode?.eulerAngles.z = baseWingSpread + soarRoll
            rig.rightWingNode?.eulerAngles.z = -baseWingSpread + soarRoll
            rig.rootNode.eulerAngles.z = soarRoll * 0.5
            targetHeadRoll = soarRoll * 0.4

        case 6: // Count 7: Preparation for beat accent
            rig.leftWingNode?.eulerAngles.z = 0.15
            rig.rightWingNode?.eulerAngles.z = -0.15
            bobY -= 0.03

        case 7: // Count 8: Stronger accent / Full Wing Spread + Body Rise (Beat drop)
            if isBeatDrop || pattern == .patternC {
                let fullSpread: CGFloat = 1.15 * intensity
                rig.leftWingNode?.eulerAngles.z = fullSpread
                rig.rightWingNode?.eulerAngles.z = -fullSpread
                bobY += 0.14 * intensity // Body rises high into aerial glory
                targetHeadPitch = 0.28 * intensity
                scaleY += 0.06
            } else {
                rig.leftWingNode?.eulerAngles.z = 0.85 * intensity
                rig.rightWingNode?.eulerAngles.z = -0.85 * intensity
                bobY += 0.08 * intensity
            }

        default:
            break
        }
    }

    // MARK: - 3. ROBOT CHOREOGRAPHY
    // Robotic popping/locking, sharp shoulder movements, alternating arm positions, elbow locking,
    // mechanical head turns, torso rotation, alternating foot steps, freeze/lock accents

    private func animateRobotDance(
        rig: Pet3DRig,
        pattern: DancePattern,
        count: Int,
        subPhase: Double,
        intensity: CGFloat,
        isBeatDrop: Bool,
        bobY: inout CGFloat,
        scaleY: inout CGFloat,
        targetHeadPitch: inout CGFloat,
        targetHeadRoll: inout CGFloat,
        targetHeadYaw: inout CGFloat
    ) {
        // Robotic Stepped Quantization: Fast snap on beat start, hold steady
        let snapFactor: CGFloat = subPhase < 0.25 ? CGFloat(subPhase / 0.25) : 1.0

        // Mechanical foot march: alternating crisp steps
        let leftStep: CGFloat = (count % 2 == 0) ? 0.32 * intensity * snapFactor : 0.0
        let rightStep: CGFloat = (count % 2 == 1) ? 0.32 * intensity * snapFactor : 0.0
        rig.frontLeftLeg?.eulerAngles.x = leftStep
        rig.frontRightLeg?.eulerAngles.x = rightStep

        // Mechanical torso rotation stepping in discrete notches
        let torsoAngles: [CGFloat] = [0.0, 0.18, 0.18, 0.0, -0.18, -0.18, 0.0, 0.0]
        rig.bodyNode.eulerAngles.y = torsoAngles[count % 8] * intensity

        // Discrete mechanical head turns
        let headYaws: [CGFloat] = [0.0, 0.38, 0.38, 0.0, -0.38, -0.38, 0.0, 0.0]
        targetHeadYaw = headYaws[count % 8] * intensity
        targetHeadPitch = (count % 2 == 0 ? 0.08 : -0.04) * intensity

        // Sharp robotic shoulder moves & 90-degree arm poses (Tutting / Robot disco)
        switch count {
        case 0, 1: // Count 1, 2: Left arm raised horizontal (90 deg), right down
            rig.leftShoulderNode?.eulerAngles.x = 1.45 * intensity
            rig.leftElbowNode?.eulerAngles.x = 1.57 * intensity
            rig.rightShoulderNode?.eulerAngles.x = 0.10
            rig.rightElbowNode?.eulerAngles.x = 0.20

        case 2, 3: // Count 3, 4: Right arm raised horizontal, left arm down
            rig.rightShoulderNode?.eulerAngles.x = 1.45 * intensity
            rig.rightElbowNode?.eulerAngles.x = 1.57 * intensity
            rig.leftShoulderNode?.eulerAngles.x = 0.10
            rig.leftElbowNode?.eulerAngles.x = 0.20

        case 4, 5: // Count 5, 6: Robot Arm Cross / Wave
            rig.leftShoulderNode?.eulerAngles.x = 0.90 * intensity
            rig.rightShoulderNode?.eulerAngles.x = -0.50 * intensity
            rig.leftElbowNode?.eulerAngles.x = 1.40
            rig.rightElbowNode?.eulerAngles.x = 1.40

        case 6: // Count 7: Windup
            rig.leftShoulderNode?.eulerAngles.x = 0.40
            rig.rightShoulderNode?.eulerAngles.x = 0.40
            rig.leftElbowNode?.eulerAngles.x = 0.60
            rig.rightElbowNode?.eulerAngles.x = 0.60

        case 7: // Count 8: Short freeze/lock accent (Full-body lock on beat drop)
            if isBeatDrop || pattern == .patternC {
                // Cyber lock pose: arms locked at right angles, completely motionless
                rig.leftShoulderNode?.eulerAngles.x = 1.57 * intensity
                rig.rightShoulderNode?.eulerAngles.x = -1.57 * intensity
                rig.leftElbowNode?.eulerAngles.x = 1.57
                rig.rightElbowNode?.eulerAngles.x = 1.57
                targetHeadYaw = 0.45 * intensity
                bobY += 0.03
            } else {
                rig.leftShoulderNode?.eulerAngles.x = 1.20 * intensity
                rig.rightShoulderNode?.eulerAngles.x = 1.20 * intensity
                rig.leftElbowNode?.eulerAngles.x = 1.20
                rig.rightElbowNode?.eulerAngles.x = 1.20
            }

        default:
            break
        }
    }

    // MARK: - 4. ROBOTCAT CHOREOGRAPHY
    // Combine feline movement with mechanical movement: robotic paw taps, tail movement,
    // visor/head movement, shoulder rotation, alternating mechanical steps, cybernetic freeze

    private func animateRobotCatDance(
        rig: Pet3DRig,
        pattern: DancePattern,
        count: Int,
        subPhase: Double,
        intensity: CGFloat,
        isBeatDrop: Bool,
        bobY: inout CGFloat,
        scaleY: inout CGFloat,
        targetHeadPitch: inout CGFloat,
        targetHeadRoll: inout CGFloat,
        targetHeadYaw: inout CGFloat
    ) {
        let snap = subPhase < 0.28 ? CGFloat(subPhase / 0.28) : 1.0

        // Mechanical paw steps with feline placement
        let leftStep: CGFloat = (count % 2 == 0) ? 0.28 * intensity * snap : 0.0
        let rightStep: CGFloat = (count % 2 == 1) ? 0.28 * intensity * snap : 0.0
        rig.frontLeftLeg?.eulerAngles.x = leftStep
        rig.frontRightLeg?.eulerAngles.x = rightStep

        // Segmented tail movement with robotic twitch
        let tailStep = CGFloat(count % 4 - 2) * 0.25 * intensity
        rig.tailNode?.eulerAngles.y = tailStep
        for seg in rig.tailSegments {
            seg.eulerAngles.y = tailStep * 0.7
        }

        // Visor & Head snap
        let yaws: [CGFloat] = [0.0, 0.32, 0.32, 0.0, -0.32, -0.32, 0.0, 0.0]
        targetHeadYaw = yaws[count % 8] * intensity
        targetHeadPitch = (count % 2 == 0 ? 0.06 : -0.04) * intensity

        // Ears twitch mechanically
        rig.leftEarNode?.eulerAngles.z = (count % 2 == 0 ? -0.15 : 0.05) * intensity
        rig.rightEarNode?.eulerAngles.z = (count % 2 == 1 ? 0.15 : -0.05) * intensity

        // Count 8: Cybernetic freeze pose
        if count == 7 && (isBeatDrop || pattern == .patternC) {
            rig.frontLeftLeg?.eulerAngles.x = 0.40 * intensity
            rig.frontRightLeg?.eulerAngles.x = 0.0
            targetHeadYaw = -0.40 * intensity
            bobY += 0.04 * intensity
        }
    }

    // MARK: - 5. GHOST CHOREOGRAPHY
    // NO leg-based dance! Floating side-to-side, vertical drift, body tilt, arm/wisp movement,
    // slow rotation, spectral stretch/compression, faster floating accent

    private func animateGhostDance(
        rig: Pet3DRig,
        pattern: DancePattern,
        count: Int,
        subPhase: Double,
        intensity: CGFloat,
        isBeatDrop: Bool,
        bobY: inout CGFloat,
        scaleY: inout CGFloat,
        scaleXZ: inout CGFloat,
        targetHeadPitch: inout CGFloat,
        targetHeadRoll: inout CGFloat,
        targetHeadYaw: inout CGFloat
    ) {
        let continuousT = Double(count) + subPhase

        // Floating side-to-side motion (lateral drift)
        let driftX = CGFloat(sin(continuousT * 0.75)) * 0.10 * intensity
        rig.rootNode.eulerAngles.z = driftX * 1.2

        // Vertical drift with spectral inertia
        let floatWave = CGFloat(sin(continuousT * 1.1)) * 0.08 * intensity
        bobY += 0.09 * intensity + floatWave

        // Body tilt like ethereal sheet in the wind
        rig.rootNode.eulerAngles.x = CGFloat(cos(continuousT * 0.85)) * 0.08 * intensity

        // Arm / spectral wisp movement (arms trailing gracefully)
        let armWave = CGFloat(sin(continuousT * 1.25)) * 0.32 * intensity
        rig.leftArmNode?.eulerAngles.z = 1.15 + armWave
        rig.rightArmNode?.eulerAngles.z = -1.15 - armWave
        rig.leftArmNode?.eulerAngles.y = CGFloat(cos(continuousT * 1.0)) * 0.25 * intensity
        rig.rightArmNode?.eulerAngles.y = -CGFloat(cos(continuousT * 1.0)) * 0.25 * intensity

        // Slow mystical rotation
        rig.rootNode.eulerAngles.y = CGFloat(sin(continuousT * 0.45)) * 0.32 * intensity

        // Spectral stretch & compression
        let pulse = CGFloat(sin(continuousT * 1.2)) * 0.07 * intensity
        scaleY += pulse
        scaleXZ -= pulse * 0.6

        // Beat Drop / Count 8 Accent: Fast spectral sweep upward & twist
        if count == 7 && (isBeatDrop || pattern == .patternC) {
            bobY += 0.18 * intensity
            rig.rootNode.eulerAngles.y += 0.65 * intensity
            rig.leftArmNode?.eulerAngles.z = 1.65 * intensity
            rig.rightArmNode?.eulerAngles.z = -1.65 * intensity
            scaleY += 0.12 * intensity
        }
    }

    // MARK: - 6. FOX CHOREOGRAPHY
    // Side-to-side weight shift, alternating paw lift, shoulder/body sway, large tail sweep,
    // ear reactions, quick head movement, occasional small pounce, energetic but not repetitive jumping

    private func animateFoxDance(
        rig: Pet3DRig,
        pattern: DancePattern,
        count: Int,
        subPhase: Double,
        intensity: CGFloat,
        isBeatDrop: Bool,
        bobY: inout CGFloat,
        scaleY: inout CGFloat,
        targetHeadPitch: inout CGFloat,
        targetHeadRoll: inout CGFloat,
        targetHeadYaw: inout CGFloat
    ) {
        let smoothSub = CGFloat(sin(subPhase * .pi))
        let sideSign: CGFloat = (count % 4 < 2) ? 1.0 : -1.0

        // Side-to-side weight shift & body sway
        rig.rootNode.eulerAngles.z = sideSign * 0.09 * intensity
        rig.bodyNode.eulerAngles.y = sideSign * 0.08 * intensity

        // Large expressive tail sweep (foxes have big fluffy tails!)
        let tailSweep = CGFloat(sin(Double(count) * 0.9 + subPhase * .pi * 2.0)) * 0.85 * intensity
        rig.tailNode?.eulerAngles.y = tailSweep
        for (i, seg) in rig.tailSegments.enumerated() {
            let lag = Double(i) * 0.22
            seg.eulerAngles.y = CGFloat(sin(Double(count) * 0.9 + subPhase * .pi * 2.0 - lag)) * 0.50 * intensity
        }

        // Ear reactions: energetic rhythmic perk
        rig.leftEarNode?.eulerAngles.z = sideSign * 0.18 * intensity
        rig.rightEarNode?.eulerAngles.z = -sideSign * 0.18 * intensity

        // Quick head movement
        targetHeadYaw = sideSign * 0.22 * intensity
        targetHeadPitch = (smoothSub * 0.08 - 0.02) * intensity

        // Alternating Paw Lifts
        switch count {
        case 0, 1: // Count 1, 2: Left paw high lift
            let lift = smoothSub * 0.38 * intensity
            rig.frontLeftLeg?.eulerAngles.x = lift
            rig.frontLeftShin?.eulerAngles.x = -lift * 0.9
            rig.frontLeftPaw?.eulerAngles.x = lift * 0.4

        case 2, 3: // Count 3, 4: Right paw high lift
            let lift = smoothSub * 0.38 * intensity
            rig.frontRightLeg?.eulerAngles.x = lift
            rig.frontRightShin?.eulerAngles.x = -lift * 0.9
            rig.frontRightPaw?.eulerAngles.x = lift * 0.4

        case 4, 5: // Count 5, 6: Energetic shoulder sway
            rig.bodyNode.eulerAngles.z = -sideSign * 0.14 * intensity
            bobY += smoothSub * 0.035 * intensity

        case 6: // Count 7: Preparation for small pounce (crouch down)
            bobY -= 0.06 * intensity
            scaleY -= 0.05
            rig.frontLeftLeg?.eulerAngles.x = -0.15
            rig.frontRightLeg?.eulerAngles.x = -0.15
            rig.backLeftLeg?.eulerAngles.x = -0.25
            rig.backRightLeg?.eulerAngles.x = -0.25

        case 7: // Count 8: Small pounce spring forward/up!
            let pounceSpring = smoothSub * 0.09 * intensity
            bobY += pounceSpring
            rig.frontLeftLeg?.eulerAngles.x = 0.45 * intensity
            rig.frontRightLeg?.eulerAngles.x = 0.45 * intensity
            targetHeadPitch = 0.15
            if isBeatDrop {
                bobY += 0.05 * intensity
            }

        default:
            break
        }
    }

    // MARK: - 7. BUNNY CHOREOGRAPHY
    // Bunny-style binky movement, controlled two-foot hops, ear bounce, small side hops,
    // body compression before hop, tail bounce, occasional double-hop

    private func animateBunnyDance(
        rig: Pet3DRig,
        pattern: DancePattern,
        count: Int,
        subPhase: Double,
        intensity: CGFloat,
        isBeatDrop: Bool,
        bobY: inout CGFloat,
        scaleY: inout CGFloat,
        scaleXZ: inout CGFloat,
        targetHeadPitch: inout CGFloat,
        targetHeadRoll: inout CGFloat,
        targetHeadYaw: inout CGFloat
    ) {
        let smoothSub = CGFloat(sin(subPhase * .pi))

        // Long Bunny Ears Bounce & Flap with the groove
        let earFlap = CGFloat(sin(subPhase * .pi * 2.0)) * 0.42 * intensity
        rig.leftEarNode?.eulerAngles.x = -0.25 + earFlap
        rig.rightEarNode?.eulerAngles.x = -0.25 + earFlap
        rig.leftEarNode?.eulerAngles.z = CGFloat(sin(subPhase * .pi)) * 0.15 * intensity
        rig.rightEarNode?.eulerAngles.z = -CGFloat(sin(subPhase * .pi)) * 0.15 * intensity

        // Cute tail bounce
        rig.tailNode?.eulerAngles.x = CGFloat(sin(subPhase * .pi * 2.0)) * 0.35 * intensity

        // Bunny Binky & Hop Kinematics
        let isDoubleHopPattern = (pattern == .patternB)

        switch count {
        case 0: // Count 1: Body compression before hop (crouch)
            bobY -= 0.045 * intensity
            scaleY -= 0.05 * intensity
            scaleXZ += 0.04 * intensity
            rig.backLeftLeg?.eulerAngles.x = -0.35
            rig.backRightLeg?.eulerAngles.x = -0.35
            targetHeadPitch = -0.06

        case 1: // Count 2: Controlled spring hop!
            let hopHeight = smoothSub * 0.09 * intensity
            bobY += hopHeight
            scaleY += 0.06 * intensity
            rig.backLeftLeg?.eulerAngles.x = 0.20
            rig.backRightLeg?.eulerAngles.x = 0.20
            targetHeadPitch = 0.10

        case 2: // Count 3: Side-hop left prep
            rig.rootNode.eulerAngles.z = 0.12 * intensity
            bobY -= 0.03 * intensity

        case 3: // Count 4: Side-hop left spring!
            if isDoubleHopPattern {
                // Rapid double-hop accent!
                let doubleHop = CGFloat(sin(subPhase * .pi * 2.0)) * 0.07 * intensity
                bobY += max(0.0, doubleHop)
            } else {
                bobY += smoothSub * 0.08 * intensity
            }
            rig.rootNode.eulerAngles.z = 0.08 * intensity

        case 4: // Count 5: Side-hop right prep
            rig.rootNode.eulerAngles.z = -0.12 * intensity
            bobY -= 0.03 * intensity

        case 5: // Count 6: Side-hop right spring!
            bobY += smoothSub * 0.08 * intensity
            rig.rootNode.eulerAngles.z = -0.08 * intensity

        case 6: // Count 7: Deep anticipation crouch
            bobY -= 0.06 * intensity
            scaleY -= 0.07 * intensity
            scaleXZ += 0.06 * intensity
            rig.backLeftLeg?.eulerAngles.x = -0.45
            rig.backRightLeg?.eulerAngles.x = -0.45

        case 7: // Count 8: Big Binky Accent / Twist Hop!
            let binkyRise = smoothSub * (isBeatDrop ? 0.15 : 0.11) * intensity
            bobY += binkyRise
            // Classic bunny binky mid-air body twist!
            rig.rootNode.eulerAngles.y = CGFloat(sin(subPhase * .pi)) * 0.35 * intensity
            rig.rootNode.eulerAngles.z = -0.15 * intensity
            targetHeadRoll = 0.25 * intensity
            targetHeadPitch = 0.14

        default:
            break
        }
    }
}
