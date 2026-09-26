import Foundation
import SceneKit
import SwiftUI
import AppKit

// MARK: - Native macOS 3D SceneKit Character View

public struct Pet3DSceneView: NSViewRepresentable {
    @ObservedObject var petState = PetState.shared
    @ObservedObject var motion = CharacterMotionStateMachine.shared
    @ObservedObject var music = MusicManager.shared
    @ObservedObject var perf = PerformanceManager.shared

    public init() {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.antialiasingMode = .multisampling4X
        scnView.autoenablesDefaultLighting = false
        scnView.allowsCameraControl = false

        let scene = SCNScene()
        scnView.scene = scene

        // Camera setup
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.usesOrthographicProjection = false
        cameraNode.camera?.fieldOfView = 48
        cameraNode.position = SCNVector3(0, 0.38, 2.3)
        cameraNode.eulerAngles = SCNVector3(-0.06, 0, 0)
        scene.rootNode.addChildNode(cameraNode)

        // Key Light with soft shadows
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.intensity = 1100
        keyLight.light?.color = NSColor(white: 0.98, alpha: 1.0)
        keyLight.light?.castsShadow = true
        keyLight.position = SCNVector3(2.5, 4.0, 3.0)
        keyLight.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 5, 0)
        scene.rootNode.addChildNode(keyLight)

        // Ambient Fill Light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 450
        ambientLight.light?.color = NSColor(red: 0.75, green: 0.8, blue: 0.9, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)

        // Accent Rim Light
        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .directional
        rimLight.light?.intensity = 650
        rimLight.light?.color = NSColor(petState.currentSpecies.accentColor)
        rimLight.position = SCNVector3(-2.0, 2.0, -2.5)
        rimLight.eulerAngles = SCNVector3(Float.pi / 6, -Float.pi / 4, 0)
        scene.rootNode.addChildNode(rimLight)
        context.coordinator.rimLightNode = rimLight
        context.coordinator.scnScene = scene

        context.coordinator.setupCharacter(in: scene, petState: petState)
        context.coordinator.startRenderLoop()

        return scnView
    }

    public func updateNSView(_ nsView: SCNView, context: Context) {
        context.coordinator.updateIfConfigChanged(petState: petState)
    }

    // MARK: - Coordinator Driving Procedural Kinematics, Facial System & Emotions
    @MainActor
    public class Coordinator: NSObject {
        var parent: Pet3DSceneView
        weak var scnScene: SCNScene?
        var currentRig: Pet3DRig?
        var rimLightNode: SCNNode?
        var lastSpecies: PetSpecies?
        var lastHorn: Bool?
        var lastWings: Bool?
        var lastAccessory: String?
        private var displayTimer: Timer?
        private var lastTime: TimeInterval = 0

        // Facial Blinking State Machine (Requirement 2)
        private var lastBlinkTime: TimeInterval = 0
        private var nextBlinkInterval: TimeInterval = 3.5
        private var blinkDuration: TimeInterval = 0.15

        // Natural Cognitive Eye Saccades (Looking around)
        private var lastSaccadeTime: TimeInterval = 0
        private var nextSaccadeInterval: TimeInterval = 3.0
        private var gazeTargetX: CGFloat = 0.0
        private var gazeTargetY: CGFloat = 0.0
        private var currentGazeX: CGFloat = 0.0
        private var currentGazeY: CGFloat = 0.0

        // Yawn State Machine
        private var isYawning: Bool = false
        private var yawnStartTime: TimeInterval = 0
        private var lastYawnCheckTime: TimeInterval = 0

        // Continuous Smoothing Interpolators
        private var currentJawAngle: CGFloat = 0.0
        private var currentUpperLidScale: CGFloat = 0.02
        private var currentLowerLidScale: CGFloat = 0.02
        private var currentHeadPitch: CGFloat = 0.0
        private var currentHeadYaw: CGFloat = 0.0
        private var currentHeadRoll: CGFloat = 0.0

        init(_ parent: Pet3DSceneView) {
            self.parent = parent
        }

        func setupCharacter(in scene: SCNScene, petState: PetState) {
            currentRig?.rootNode.removeFromParentNode()

            let rig = Pet3DCharacterBuilder.buildCharacter(
                species: petState.currentSpecies,
                customHornEnabled: petState.customHornEnabled,
                customWingsEnabled: petState.customWingsEnabled,
                customAccessory: petState.customAccessory
            )
            scene.rootNode.addChildNode(rig.rootNode)
            self.currentRig = rig
            self.lastSpecies = petState.currentSpecies
            self.lastHorn = petState.customHornEnabled
            self.lastWings = petState.customWingsEnabled
            self.lastAccessory = petState.customAccessory

            rimLightNode?.light?.color = NSColor(petState.currentSpecies.accentColor)
        }

        func updateIfConfigChanged(petState: PetState) {
            if lastSpecies != petState.currentSpecies ||
                lastHorn != petState.customHornEnabled ||
                lastWings != petState.customWingsEnabled ||
                lastAccessory != petState.customAccessory {
                if let scene = scnScene {
                    setupCharacter(in: scene, petState: petState)
                }
            }
        }

        func startRenderLoop() {
            displayTimer?.invalidate()
            let interval = max(1.0 / 60.0, parent.perf.minimumRenderInterval)
            displayTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.tick()
                }
            }
        }

        private func tick() {
            guard let rig = currentRig else { return }
            let t = Date().timeIntervalSinceReferenceDate
            let petState = parent.petState
            let mood = petState.currentMood
            let animState = petState.animState
            let species = petState.currentSpecies

            let isDancing = (animState == .dance)
            let isWalking = (animState == .walk || animState == .run)
            let isMoving = isDancing || isWalking
            let isThinking = (animState == .thinking || petState.isThinking)
            let isSleeping = (animState == .sleep || mood == .sleepy)
            let isTalking = (isThinking || petState.isBubbleVisible)

            // Music amplitude reactivity
            let musicAmp = parent.music.isPlaying ? parent.music.currentBeatAmplitude : 0.0

            let snapshot = parent.motion.evaluateSnapshot(
                at: t,
                animState: animState,
                mood: mood,
                atmosphere: .clearDay,
                isSafeMode: parent.perf.isSafeMode
            )

            // 1. Base Idle Breathing & Vertical Bob
            let reduceMotion = parent.perf.isReduceMotionActive
            var bobY: CGFloat = CGFloat(sin(t * 2.2)) * (reduceMotion ? 0.004 : 0.012)
            var scaleY: CGFloat = 1.0 + CGFloat(sin(t * 2.2)) * (reduceMotion ? 0.005 : 0.015)
            var scaleXZ: CGFloat = 1.0 - CGFloat(sin(t * 2.2)) * (reduceMotion ? 0.003 : 0.008)

            // Music Beat Reactivity
            if musicAmp > 0.05 && !reduceMotion {
                bobY += CGFloat(musicAmp) * 0.08
                scaleY += CGFloat(musicAmp) * 0.05
                scaleXZ -= CGFloat(musicAmp) * 0.03
            } else if isDancing && !reduceMotion {
                // Tasteful generic groove rhythm (~118 BPM) when dancing to external media
                let groove = CGFloat(abs(sin(t * 6.2))) * 0.05
                bobY += groove
                scaleY += groove * 0.6
                scaleXZ -= groove * 0.4
            }

            // 2. Natural Blinking State Machine (Requirement 2)
            var blinkProgress: CGFloat = 0.0
            if isSleeping {
                blinkProgress = 1.0
            } else {
                let timeSinceBlink = t - lastBlinkTime
                if timeSinceBlink >= nextBlinkInterval {
                    let blinkPhase = (timeSinceBlink - nextBlinkInterval) / blinkDuration
                    if blinkPhase <= 1.0 {
                        blinkProgress = CGFloat(sin(blinkPhase * Double.pi))
                    } else {
                        lastBlinkTime = t
                        nextBlinkInterval = Double.random(in: 2.8...5.5)
                        if Double.random(in: 0...1) < 0.2 {
                            nextBlinkInterval = 0.28 // Double-blink
                        }
                    }
                }
            }

            // 3. Natural Cognitive Eye Saccades (Requirement 2)
            if t - lastSaccadeTime >= nextSaccadeInterval {
                lastSaccadeTime = t
                nextSaccadeInterval = Double.random(in: 2.4...4.8)
                if isThinking {
                    gazeTargetX = CGFloat(sin(t * 1.5)) * 0.008
                    gazeTargetY = 0.006 // Upward thoughtful drift
                } else if mood == .focused {
                    gazeTargetX = 0.0
                    gazeTargetY = 0.0 // Locked directly forward
                } else if mood == .curious {
                    gazeTargetX = (Double.random(in: 0...1) < 0.5 ? -0.006 : 0.006)
                    gazeTargetY = 0.003
                } else {
                    gazeTargetX = CGFloat.random(in: -0.005...0.005)
                    gazeTargetY = CGFloat.random(in: -0.004...0.004)
                }
            }
            currentGazeX += (gazeTargetX - currentGazeX) * 0.15
            currentGazeY += (gazeTargetY - currentGazeY) * 0.15

            rig.leftPupilNode?.position.x = currentGazeX
            rig.leftPupilNode?.position.y = currentGazeY
            rig.rightPupilNode?.position.x = currentGazeX
            rig.rightPupilNode?.position.y = currentGazeY

            // 4. Eyelid Emotion Shaping (Requirement 2 & 4)
            var targetUpperLid: CGFloat = 0.02
            var targetLowerLid: CGFloat = 0.02

            if isSleeping {
                targetUpperLid = 1.0
                targetLowerLid = 0.5
            } else {
                switch mood {
                case .happy, .joyful:
                    targetLowerLid = 0.42 // Raised cheeks / crescent smile
                    targetUpperLid = max(0.12, blinkProgress)

                case .sleepy:
                    targetUpperLid = max(0.68, blinkProgress)
                    targetLowerLid = 0.18

                case .surprised:
                    targetUpperLid = -0.15 // Wide alert eyes
                    targetLowerLid = -0.05

                case .focused:
                    targetUpperLid = 0.22 // Attentive narrowed gaze
                    targetLowerLid = 0.22

                case .sad, .crying:
                    targetUpperLid = max(0.38, blinkProgress)
                    targetLowerLid = 0.05

                case .concerned:
                    targetUpperLid = max(0.20, blinkProgress)
                    targetLowerLid = 0.10

                case .excited, .celebrating:
                    targetUpperLid = max(-0.08, blinkProgress)
                    targetLowerLid = 0.18

                case .calm, .relaxed:
                    targetUpperLid = max(0.12, blinkProgress)
                    targetLowerLid = 0.05

                default:
                    targetUpperLid = max(0.02, blinkProgress)
                    targetLowerLid = 0.02
                }
            }

            currentUpperLidScale += (targetUpperLid - currentUpperLidScale) * 0.22
            currentLowerLidScale += (targetLowerLid - currentLowerLidScale) * 0.22

            rig.leftUpperLid?.scale.y = max(0.02, currentUpperLidScale)
            rig.rightUpperLid?.scale.y = max(0.02, currentUpperLidScale)
            rig.leftLowerLid?.scale.y = max(0.02, currentLowerLidScale)
            rig.rightLowerLid?.scale.y = max(0.02, currentLowerLidScale)

            // 5. Articulated Mouth & Jaw System (Requirement 3 & 4)
            if mood == .sleepy && !isYawning && (t - lastYawnCheckTime > 18.0) {
                lastYawnCheckTime = t
                if Double.random(in: 0...1) < 0.65 {
                    isYawning = true
                    yawnStartTime = t
                }
            }

            var targetJaw: CGFloat = 0.0
            if isYawning {
                let yawnElapsed = t - yawnStartTime
                let yawnDuration: TimeInterval = 2.2
                if yawnElapsed <= yawnDuration {
                    let yawnPhase = yawnElapsed / yawnDuration
                    targetJaw = 0.44 * CGFloat(sin(yawnPhase * Double.pi))
                } else {
                    isYawning = false
                }
            } else if isTalking {
                // Natural phoneme jaw oscillation at ~5.5 Hz
                targetJaw = 0.06 + CGFloat(abs(sin(t * 11.0))) * 0.14
            } else {
                switch mood {
                case .happy, .joyful:
                    targetJaw = 0.08 // Welcoming smile

                case .excited, .celebrating:
                    targetJaw = 0.20 // Open laughing mouth

                case .surprised:
                    targetJaw = 0.28 // Open gasping 'O'

                case .sleepy:
                    targetJaw = 0.02

                case .sad:
                    targetJaw = -0.04 // Downward tucked chin

                default:
                    targetJaw = 0.0
                }
            }

            currentJawAngle += (targetJaw - currentJawAngle) * 0.18
            rig.jawNode?.eulerAngles.x = currentJawAngle

            // 6. Realistic Articulated Quadruped Walking Gait (Requirement 7)
            let walkSpeed: Double = reduceMotion ? 2.2 : (isDancing ? 5.2 : 3.8)
            let motionMultiplier: CGFloat = reduceMotion ? 0.35 : 1.0
            let phase = t * walkSpeed

            if isMoving {
                switch species {
                case .bunny:
                    // Hopping Gait for Rabbit
                    let hopProgress = CGFloat(max(0.0, sin(t * (reduceMotion ? 2.5 : 5.0)))) * motionMultiplier
                    bobY += hopProgress * 0.12
                    scaleY = CGFloat(1.0) - (hopProgress * 0.14)
                    scaleXZ = CGFloat(1.0) + (hopProgress * 0.08)

                    rig.frontLeftLeg?.eulerAngles.x = -hopProgress * 0.45
                    rig.frontRightLeg?.eulerAngles.x = -hopProgress * 0.45
                    rig.backLeftLeg?.eulerAngles.x = hopProgress * 0.55
                    rig.backRightLeg?.eulerAngles.x = hopProgress * 0.55
                    rig.backLeftShin?.eulerAngles.x = -hopProgress * 0.35
                    rig.backRightShin?.eulerAngles.x = -hopProgress * 0.35

                    rig.leftEarNode?.eulerAngles.x = -hopProgress * 0.35
                    rig.rightEarNode?.eulerAngles.x = -hopProgress * 0.35

                case .ghost:
                    // Spectral Undulating Float
                    bobY += CGFloat(sin(t * 3.0)) * 0.06
                    rig.rootNode.eulerAngles.z = CGFloat(sin(t * 2.0)) * 0.08
                    rig.rootNode.eulerAngles.x = CGFloat(cos(t * 2.0)) * 0.06
                    rig.frontLeftLeg?.eulerAngles.z = CGFloat(Double.pi / 4) + CGFloat(sin(t * 3.5)) * 0.15
                    rig.frontRightLeg?.eulerAngles.z = -CGFloat(Double.pi / 4) - CGFloat(sin(t * 3.5)) * 0.15

                default:
                    // Biomechanical Quadruped Diagonal Trot (Dragon, Cat, Fox, Neo)
                    let fl_swing = CGFloat(sin(phase)) * 0.42 * motionMultiplier
                    let fl_knee = CGFloat(max(0.0, -sin(phase))) * 0.46 * motionMultiplier
                    let fl_paw = -fl_swing * 0.45

                    let fr_swing = CGFloat(sin(phase + Double.pi)) * 0.42 * motionMultiplier
                    let fr_knee = CGFloat(max(0.0, -sin(phase + Double.pi))) * 0.46 * motionMultiplier
                    let fr_paw = -fr_swing * 0.45

                    // Front Left & Back Right pair together
                    rig.frontLeftLeg?.eulerAngles.x = fl_swing
                    rig.frontLeftShin?.eulerAngles.x = fl_knee
                    rig.frontLeftPaw?.eulerAngles.x = fl_paw

                    rig.backRightLeg?.eulerAngles.x = fl_swing
                    rig.backRightShin?.eulerAngles.x = fl_knee
                    rig.backRightPaw?.eulerAngles.x = fl_paw

                    // Front Right & Back Left pair together
                    rig.frontRightLeg?.eulerAngles.x = fr_swing
                    rig.frontRightShin?.eulerAngles.x = fr_knee
                    rig.frontRightPaw?.eulerAngles.x = fr_paw

                    rig.backLeftLeg?.eulerAngles.x = fr_swing
                    rig.backLeftShin?.eulerAngles.x = fr_knee
                    rig.backLeftPaw?.eulerAngles.x = fr_paw

                    // Weight shift & Torso double-frequency bob
                    bobY += CGFloat(abs(sin(phase))) * 0.026 * motionMultiplier
                    rig.rootNode.eulerAngles.z = CGFloat(sin(phase)) * 0.035 * motionMultiplier
                    rig.bodyNode.eulerAngles.y = CGFloat(cos(phase)) * 0.025 * motionMultiplier
                }
            } else {
                // Standing rest position
                rig.frontLeftLeg?.eulerAngles.x = 0
                rig.frontLeftShin?.eulerAngles.x = 0
                rig.frontLeftPaw?.eulerAngles.x = 0
                rig.frontRightLeg?.eulerAngles.x = 0
                rig.frontRightShin?.eulerAngles.x = 0
                rig.frontRightPaw?.eulerAngles.x = 0
                rig.backLeftLeg?.eulerAngles.x = 0
                rig.backLeftShin?.eulerAngles.x = 0
                rig.backLeftPaw?.eulerAngles.x = 0
                rig.backRightLeg?.eulerAngles.x = 0
                rig.backRightShin?.eulerAngles.x = 0
                rig.backRightPaw?.eulerAngles.x = 0
                rig.rootNode.eulerAngles.z = 0
                rig.bodyNode.eulerAngles.y = 0
            }

            // 7. Wings Flapping (Dragon)
            if let lw = rig.leftWingNode, let rw = rig.rightWingNode {
                let wingRate = isDancing ? 8.0 : (mood == .excited ? 6.5 : (isWalking ? 4.0 : 2.5))
                let flap = CGFloat(sin(t * wingRate)) * 0.35
                lw.eulerAngles.z = CGFloat(Double.pi / 3) + flap
                rw.eulerAngles.z = -CGFloat(Double.pi / 3) - flap
            }

            // 8. Tail Expressive Dynamics
            if let tail = rig.tailNode {
                let tailWagFreq = isDancing ? 10.0 : (mood == .excited || mood == .joyful ? 8.0 : (mood == .happy ? 5.0 : 2.5))
                let tailAmp: CGFloat = (mood == .sad) ? 0.05 : 0.35
                tail.eulerAngles.y = CGFloat(sin(t * tailWagFreq)) * tailAmp

                for (idx, seg) in rig.tailSegments.enumerated() {
                    let delay = Double(idx + 1) * 0.18
                    seg.eulerAngles.y = CGFloat(sin((t - delay) * tailWagFreq)) * (tailAmp * 0.7)
                }
            }

            // 9. Emotion Engine Full Mapping (Requirement 4)
            var targetHeadPitch: CGFloat = 0.0
            var targetHeadRoll: CGFloat = 0.0
            var targetHeadYaw: CGFloat = 0.0

            switch mood {
            case .calm:
                targetHeadPitch = 0.0
                targetHeadRoll = 0.0

            case .happy:
                targetHeadRoll = CGFloat(sin(t * 2.0)) * 0.08
                targetHeadPitch = CGFloat(cos(t * 2.0)) * 0.05
                rig.leftEarNode?.eulerAngles.z = -CGFloat(Double.pi / 12) + CGFloat(sin(t * 3.0)) * 0.04
                rig.rightEarNode?.eulerAngles.z = CGFloat(Double.pi / 12) - CGFloat(sin(t * 3.0)) * 0.04

            case .joyful:
                targetHeadRoll = CGFloat(sin(t * 3.0)) * 0.10
                targetHeadPitch = 0.08 + CGFloat(cos(t * 3.0)) * 0.06
                bobY += CGFloat(abs(sin(t * 4.0))) * 0.03

            case .excited:
                targetHeadPitch = CGFloat(sin(t * 6.0)) * 0.12
                bobY += CGFloat(abs(sin(t * 6.0))) * 0.04

            case .curious:
                targetHeadRoll = 0.25 // Inquisitive cocked head
                targetHeadYaw = -0.15
                rig.leftEarNode?.eulerAngles.z = -CGFloat(Double.pi / 6)
                rig.rightEarNode?.eulerAngles.z = 0.0

            case .focused:
                targetHeadPitch = 0.06 // Forward attentive posture
                targetHeadRoll = 0.0

            case .sleepy:
                targetHeadPitch = -0.24 // Heavy drooping head
                scaleY = 0.94
                bobY -= 0.04

            case .sad, .crying:
                targetHeadPitch = -0.32 // Drooped sad head
                rig.leftEarNode?.eulerAngles.z = -CGFloat(Double.pi / 5)
                rig.rightEarNode?.eulerAngles.z = CGFloat(Double.pi / 5)
                bobY -= 0.03

            case .concerned:
                targetHeadRoll = 0.22
                targetHeadYaw = -0.12

            case .surprised:
                targetHeadPitch = 0.18 // Sudden upward gaze
                scaleY = 1.08

            case .celebrating:
                targetHeadPitch = CGFloat(sin(t * 5.0)) * 0.14
                targetHeadRoll = CGFloat(cos(t * 4.0)) * 0.12
                bobY += CGFloat(abs(sin(t * 5.0))) * 0.06

            case .relaxed:
                targetHeadPitch = -0.04
                targetHeadRoll = CGFloat(sin(t * 1.5)) * 0.04

            case .angry:
                targetHeadPitch = -0.18
                targetHeadYaw = CGFloat(sin(t * 4.0)) * 0.05

            case .proud:
                targetHeadPitch = 0.22 // High chin
                scaleXZ = 1.05

            default:
                targetHeadRoll = CGFloat(snapshot.headTiltAngle.radians) * 0.5
            }

            if isSleeping {
                targetHeadPitch = -0.24
                scaleY = 0.94
                bobY -= 0.04
            }

            if isThinking {
                targetHeadYaw = CGFloat(sin(t * 1.5)) * 0.20
                targetHeadPitch = 0.12
            }

            // Head stabilization during walking
            if isMoving {
                targetHeadPitch -= CGFloat(abs(sin(phase))) * 0.02 * motionMultiplier
            }

            // Smoothly interpolate head angles
            currentHeadPitch += (targetHeadPitch - currentHeadPitch) * 0.15
            currentHeadRoll += (targetHeadRoll - currentHeadRoll) * 0.15
            currentHeadYaw += (targetHeadYaw - currentHeadYaw) * 0.15

            // Apply Transforms
            rig.bodyNode.position.y = 0.26 + bobY
            rig.bodyNode.scale = SCNVector3(scaleXZ, scaleY, scaleXZ)
            rig.headNode.eulerAngles = SCNVector3(currentHeadPitch, currentHeadYaw, currentHeadRoll)
        }

        deinit {
            displayTimer?.invalidate()
        }
    }
}
