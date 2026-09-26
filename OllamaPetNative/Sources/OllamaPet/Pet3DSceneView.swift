import Foundation
import SceneKit
import SwiftUI
import AppKit

// MARK: - Native macOS 3D SceneKit Character View

public struct Pet3DSceneView: NSViewRepresentable {
    public var previewSpecies: PetSpecies?
    @ObservedObject var petState = PetState.shared
    @ObservedObject var motion = CharacterMotionStateMachine.shared
    @ObservedObject var music = MusicManager.shared
    @ObservedObject var perf = PerformanceManager.shared

    public init(previewSpecies: PetSpecies? = nil) {
        self.previewSpecies = previewSpecies
    }

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

        // 3D Locomotion Direction Orientation (Requirement 6)
        private var currentMovementYaw: Float = 0.0

        // LookAtUserController (Requirement 9)
        private var currentLookAtYaw: CGFloat = 0.0
        private var currentLookAtPitch: CGFloat = 0.0

        // Robot Wave & Hand Gestures (Requirement 2)
        public var isWaving: Bool = false
        private var waveStartTime: TimeInterval = 0

        // Dragon Fire Breath Emitter (Requirement 4)
        public var isBreathingFire: Bool = false
        private var fireStartTime: TimeInterval = 0
        private var activeFlameBurstNodes: [SCNNode] = []

        init(_ parent: Pet3DSceneView) {
            self.parent = parent
            super.init()
            setupNotificationObservers()
        }

        private func setupNotificationObservers() {
            NotificationCenter.default.addObserver(forName: NSNotification.Name("PetTriggerDragonFireBreath"), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.triggerFireBreath()
                }
            }
            NotificationCenter.default.addObserver(forName: NSNotification.Name("PetTriggerRobotWave"), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.triggerRobotWave()
                }
            }
        }

        public func triggerFireBreath() {
            guard !isBreathingFire else { return }
            isBreathingFire = true
            fireStartTime = Date().timeIntervalSinceReferenceDate
            PetState.shared.showBubble("🔥 *FWOOOOSH!*", duration: 3.0)
            SoundEffect.click.play()
        }

        public func triggerRobotWave() {
            guard !isWaving else { return }
            isWaving = true
            waveStartTime = Date().timeIntervalSinceReferenceDate
            PetState.shared.showBubble("👋 *Beep-boop! Hello!*", duration: 2.5)
            SoundEffect.receive.play()
        }

        func setupCharacter(in scene: SCNScene, petState: PetState) {
            currentRig?.rootNode.removeFromParentNode()

            let activeSpecies = parent.previewSpecies ?? petState.currentSpecies
            let rig = Pet3DCharacterBuilder.buildCharacter(
                species: activeSpecies,
                customHornEnabled: petState.customHornEnabled,
                customWingsEnabled: petState.customWingsEnabled,
                customAccessory: petState.customAccessory
            )
            scene.rootNode.addChildNode(rig.rootNode)
            self.currentRig = rig
            self.lastSpecies = activeSpecies
            self.lastHorn = petState.customHornEnabled
            self.lastWings = petState.customWingsEnabled
            self.lastAccessory = petState.customAccessory

            rimLightNode?.light?.color = NSColor(activeSpecies.accentColor)
        }

        func updateIfConfigChanged(petState: PetState) {
            let activeSpecies = parent.previewSpecies ?? petState.currentSpecies
            if lastSpecies != activeSpecies ||
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
            let species = parent.previewSpecies ?? petState.currentSpecies

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

            // 3. Natural Cognitive Eye Saccades & LookAtUserController (Requirements 2 & 9)
            var targetLookYaw: CGFloat = 0.0
            var targetLookPitch: CGFloat = 0.0

            if petState.isChatOpen {
                // Focus attentively toward chat panel interaction area
                gazeTargetX = petState.activeAnchor.isLeft ? -0.012 : 0.012
                gazeTargetY = 0.004
                targetLookYaw = petState.activeAnchor.isLeft ? -0.22 : 0.22
                targetLookPitch = 0.06
            } else if isTalking {
                gazeTargetX = 0.0
                gazeTargetY = 0.006
                targetLookYaw = 0.0
                targetLookPitch = 0.08
            } else {
                if t - lastSaccadeTime >= nextSaccadeInterval {
                    lastSaccadeTime = t
                    nextSaccadeInterval = Double.random(in: 2.4...4.8)
                    if isThinking {
                        gazeTargetX = CGFloat(sin(t * 1.5)) * 0.008
                        gazeTargetY = 0.006 // Upward thoughtful drift
                        targetLookYaw = CGFloat(sin(t * 1.5)) * 0.15
                    } else if mood == .focused {
                        gazeTargetX = 0.0
                        gazeTargetY = 0.0 // Locked directly forward
                    } else if mood == .curious {
                        gazeTargetX = (Double.random(in: 0...1) < 0.5 ? -0.008 : 0.008)
                        gazeTargetY = 0.004
                        targetLookYaw = gazeTargetX * 12.0
                    } else {
                        gazeTargetX = CGFloat.random(in: -0.006...0.006)
                        gazeTargetY = CGFloat.random(in: -0.004...0.004)
                        targetLookYaw = gazeTargetX * 8.0
                    }
                }
            }
            currentGazeX += (gazeTargetX - currentGazeX) * 0.15
            currentGazeY += (gazeTargetY - currentGazeY) * 0.15
            currentLookAtYaw += (targetLookYaw - currentLookAtYaw) * 0.12
            currentLookAtPitch += (targetLookPitch - currentLookAtPitch) * 0.12

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

            // 6. Direction-Aware 3D Orientation (Requirement 6)
            let targetMovementYaw = petState.movementDirection.yawAngle
            currentMovementYaw += (targetMovementYaw - currentMovementYaw) * 0.16
            rig.rootNode.eulerAngles.y = CGFloat(currentMovementYaw)

            // 7. Species-Specific Locomotion & Resting Behavior Engine (Requirements 5, 7, 8)
            let walkSpeed: Double = reduceMotion ? 2.2 : (isDancing ? 5.2 : 3.8)
            let motionMultiplier: CGFloat = reduceMotion ? 0.35 : 1.0
            let phase = t * walkSpeed

            if isWalking {
                switch species {
                case .dragon:
                    // Heavy quadruped diagonal trot + wing lift + tail counterbalance
                    let stride = phase * 0.85
                    let fl_swing = CGFloat(sin(stride)) * 0.44 * motionMultiplier
                    let fl_knee = CGFloat(max(0.0, -sin(stride))) * 0.48 * motionMultiplier
                    let fl_paw = -fl_swing * 0.50

                    let fr_swing = CGFloat(sin(stride + Double.pi)) * 0.44 * motionMultiplier
                    let fr_knee = CGFloat(max(0.0, -sin(stride + Double.pi))) * 0.48 * motionMultiplier
                    let fr_paw = -fr_swing * 0.50

                    rig.frontLeftLeg?.eulerAngles.x = fl_swing
                    rig.frontLeftShin?.eulerAngles.x = fl_knee
                    rig.frontLeftPaw?.eulerAngles.x = fl_paw
                    rig.backRightLeg?.eulerAngles.x = fl_swing
                    rig.backRightShin?.eulerAngles.x = fl_knee
                    rig.backRightPaw?.eulerAngles.x = fl_paw

                    rig.frontRightLeg?.eulerAngles.x = fr_swing
                    rig.frontRightShin?.eulerAngles.x = fr_knee
                    rig.frontRightPaw?.eulerAngles.x = fr_paw
                    rig.backLeftLeg?.eulerAngles.x = fr_swing
                    rig.backLeftShin?.eulerAngles.x = fr_knee
                    rig.backLeftPaw?.eulerAngles.x = fr_paw

                    bobY += CGFloat(abs(sin(stride))) * 0.034 * motionMultiplier
                    rig.rootNode.eulerAngles.z = CGFloat(sin(stride)) * 0.05 * motionMultiplier

                    // Wing micro-lift & tail counterbalance
                    rig.leftWingNode?.eulerAngles.z = CGFloat(Double.pi / 3) + CGFloat(sin(stride * 2.0)) * 0.18
                    rig.rightWingNode?.eulerAngles.z = -CGFloat(Double.pi / 3) - CGFloat(sin(stride * 2.0)) * 0.18
                    rig.tailNode?.eulerAngles.y = -CGFloat(sin(stride)) * 0.48

                case .cat:
                    // Soft feline walk with flexible spine and quiet paws
                    let stride = phase * 0.95
                    let fl_swing = CGFloat(sin(stride)) * 0.36 * motionMultiplier
                    let fl_knee = CGFloat(max(0.0, -sin(stride))) * 0.32 * motionMultiplier
                    let fl_paw = -fl_swing * 0.40

                    let fr_swing = CGFloat(sin(stride + Double.pi)) * 0.36 * motionMultiplier
                    let fr_knee = CGFloat(max(0.0, -sin(stride + Double.pi))) * 0.32 * motionMultiplier
                    let fr_paw = -fr_swing * 0.40

                    rig.frontLeftLeg?.eulerAngles.x = fl_swing
                    rig.frontLeftShin?.eulerAngles.x = fl_knee
                    rig.frontLeftPaw?.eulerAngles.x = fl_paw
                    rig.backRightLeg?.eulerAngles.x = fl_swing
                    rig.backRightShin?.eulerAngles.x = fl_knee
                    rig.backRightPaw?.eulerAngles.x = fl_paw

                    rig.frontRightLeg?.eulerAngles.x = fr_swing
                    rig.frontRightShin?.eulerAngles.x = fr_knee
                    rig.frontRightPaw?.eulerAngles.x = fr_paw
                    rig.backLeftLeg?.eulerAngles.x = fr_swing
                    rig.backLeftShin?.eulerAngles.x = fr_knee
                    rig.backLeftPaw?.eulerAngles.x = fr_paw

                    // Spine flexibility & tail balance
                    rig.bodyNode.eulerAngles.y = CGFloat(cos(stride)) * 0.035 * motionMultiplier
                    rig.bodyNode.eulerAngles.z = CGFloat(sin(stride)) * 0.025 * motionMultiplier
                    bobY += CGFloat(abs(sin(stride))) * 0.018 * motionMultiplier
                    rig.tailNode?.eulerAngles.x = 0.22
                    rig.tailNode?.eulerAngles.y = CGFloat(sin(stride * 0.8)) * 0.35

                case .fox:
                    // Light bouncy trot with large tail sway and ear swivel
                    let stride = phase * 1.15
                    let fl_swing = CGFloat(sin(stride)) * 0.45 * motionMultiplier
                    let fl_knee = CGFloat(max(0.0, -sin(stride))) * 0.52 * motionMultiplier
                    let fl_paw = -fl_swing * 0.42

                    let fr_swing = CGFloat(sin(stride + Double.pi)) * 0.45 * motionMultiplier
                    let fr_knee = CGFloat(max(0.0, -sin(stride + Double.pi))) * 0.52 * motionMultiplier
                    let fr_paw = -fr_swing * 0.42

                    rig.frontLeftLeg?.eulerAngles.x = fl_swing
                    rig.frontLeftShin?.eulerAngles.x = fl_knee
                    rig.frontLeftPaw?.eulerAngles.x = fl_paw
                    rig.backRightLeg?.eulerAngles.x = fl_swing
                    rig.backRightShin?.eulerAngles.x = fl_knee
                    rig.backRightPaw?.eulerAngles.x = fl_paw

                    rig.frontRightLeg?.eulerAngles.x = fr_swing
                    rig.frontRightShin?.eulerAngles.x = fr_knee
                    rig.frontRightPaw?.eulerAngles.x = fr_paw
                    rig.backLeftLeg?.eulerAngles.x = fr_swing
                    rig.backLeftShin?.eulerAngles.x = fr_knee
                    rig.backLeftPaw?.eulerAngles.x = fr_paw

                    bobY += CGFloat(abs(sin(stride))) * 0.040 * motionMultiplier
                    rig.tailNode?.eulerAngles.y = CGFloat(sin(stride)) * 0.60
                    rig.leftEarNode?.eulerAngles.z = -CGFloat(Double.pi / 10) + CGFloat(sin(stride)) * 0.08
                    rig.rightEarNode?.eulerAngles.z = CGFloat(Double.pi / 10) - CGFloat(sin(stride)) * 0.08

                case .bunny:
                    // Hopping gait: synchronized rear-leg launch & ear bounce
                    let hopCycle = sin(phase * 1.25)
                    let hopProgress = CGFloat(max(0.0, hopCycle)) * motionMultiplier
                    bobY += hopProgress * 0.14
                    scaleY = CGFloat(1.0) - (hopProgress * 0.15)
                    scaleXZ = CGFloat(1.0) + (hopProgress * 0.10)

                    rig.frontLeftLeg?.eulerAngles.x = -hopProgress * 0.45
                    rig.frontRightLeg?.eulerAngles.x = -hopProgress * 0.45
                    rig.backLeftLeg?.eulerAngles.x = hopProgress * 0.65
                    rig.backRightLeg?.eulerAngles.x = hopProgress * 0.65
                    rig.backLeftShin?.eulerAngles.x = -hopProgress * 0.40
                    rig.backRightShin?.eulerAngles.x = -hopProgress * 0.40

                    rig.leftEarNode?.eulerAngles.x = -hopProgress * 0.45
                    rig.rightEarNode?.eulerAngles.x = -hopProgress * 0.45

                case .robot:
                    // Bipedal mechanical step cycle with alternating robotic arm swings
                    let legSwing = CGFloat(sin(phase)) * 0.45 * motionMultiplier
                    rig.frontLeftLeg?.eulerAngles.x = legSwing
                    rig.frontRightLeg?.eulerAngles.x = -legSwing
                    rig.frontLeftShin?.eulerAngles.x = CGFloat(max(0.0, -sin(phase))) * 0.42 * motionMultiplier
                    rig.frontRightShin?.eulerAngles.x = CGFloat(max(0.0, sin(phase))) * 0.42 * motionMultiplier

                    // Alternating arm swings opposite to legs
                    rig.leftShoulderNode?.eulerAngles.x = -legSwing * 0.42
                    rig.leftElbowNode?.eulerAngles.x = 0.32
                    rig.rightShoulderNode?.eulerAngles.x = legSwing * 0.42
                    rig.rightElbowNode?.eulerAngles.x = 0.32

                    bobY += CGFloat(abs(sin(phase))) * 0.022 * motionMultiplier
                    rig.rootNode.eulerAngles.z = (legSwing > 0 ? 0.02 : -0.02) * motionMultiplier

                case .robotcat:
                    // Hybrid cybernetic quadruped walk
                    let stride = phase * 1.05
                    let fl_swing = CGFloat(sin(stride)) * 0.40 * motionMultiplier
                    let fl_knee = CGFloat(max(0.0, -sin(stride))) * 0.44 * motionMultiplier
                    rig.frontLeftLeg?.eulerAngles.x = fl_swing
                    rig.frontLeftShin?.eulerAngles.x = fl_knee
                    rig.backRightLeg?.eulerAngles.x = fl_swing
                    rig.backRightShin?.eulerAngles.x = fl_knee
                    rig.frontRightLeg?.eulerAngles.x = -fl_swing
                    rig.frontRightShin?.eulerAngles.x = CGFloat(max(0.0, sin(stride))) * 0.44 * motionMultiplier
                    rig.backLeftLeg?.eulerAngles.x = -fl_swing
                    rig.backLeftShin?.eulerAngles.x = CGFloat(max(0.0, sin(stride))) * 0.44 * motionMultiplier
                    rig.tailNode?.eulerAngles.y = CGFloat(sin(stride * 2.0)) * 0.35

                case .ghost:
                    // Legless spectral floating glide
                    bobY += CGFloat(sin(t * 3.2)) * 0.08
                    rig.rootNode.eulerAngles.z = CGFloat(sin(t * 2.2)) * 0.08
                    rig.rootNode.eulerAngles.x = CGFloat(cos(t * 2.2)) * 0.06
                    rig.leftArmNode?.eulerAngles.z = CGFloat(Double.pi / 2.5) + CGFloat(sin(t * 3.2)) * 0.20
                    rig.rightArmNode?.eulerAngles.z = -CGFloat(Double.pi / 2.5) - CGFloat(sin(t * 3.2)) * 0.20
                }
            } else if animState == .sit {
                // Species-Specific Sitting Postures (Requirement 8)
                switch species {
                case .cat:
                    rig.backLeftLeg?.eulerAngles.x = -1.1
                    rig.backRightLeg?.eulerAngles.x = -1.1
                    rig.frontLeftLeg?.eulerAngles.x = 0.05
                    rig.frontRightLeg?.eulerAngles.x = 0.05
                    bobY -= 0.06
                    rig.tailNode?.eulerAngles.y = 0.45

                case .dragon:
                    rig.frontLeftLeg?.eulerAngles.x = 0.2
                    rig.frontRightLeg?.eulerAngles.x = 0.2
                    rig.backLeftLeg?.eulerAngles.x = -0.7
                    rig.backRightLeg?.eulerAngles.x = -0.7
                    bobY -= 0.08
                    rig.leftWingNode?.eulerAngles.z = 0.12
                    rig.rightWingNode?.eulerAngles.z = -0.12

                case .fox:
                    rig.backLeftLeg?.eulerAngles.x = -1.0
                    rig.backRightLeg?.eulerAngles.x = -1.0
                    rig.frontLeftLeg?.eulerAngles.x = 0.05
                    rig.frontRightLeg?.eulerAngles.x = 0.05
                    bobY -= 0.05
                    rig.tailNode?.eulerAngles.y = 0.55

                case .bunny:
                    bobY -= 0.07
                    rig.backLeftLeg?.eulerAngles.x = -0.5
                    rig.backRightLeg?.eulerAngles.x = -0.5
                    rig.leftEarNode?.eulerAngles.x = -0.25
                    rig.rightEarNode?.eulerAngles.x = -0.25

                case .robot:
                    // Mechanical calibration / power-save sitting
                    rig.frontLeftLeg?.eulerAngles.x = -0.7
                    rig.frontRightLeg?.eulerAngles.x = -0.7
                    rig.leftShoulderNode?.eulerAngles.x = 0.1
                    rig.leftElbowNode?.eulerAngles.x = 0.5
                    rig.rightShoulderNode?.eulerAngles.x = 0.1
                    rig.rightElbowNode?.eulerAngles.x = 0.5
                    bobY -= 0.08

                case .robotcat:
                    rig.backLeftLeg?.eulerAngles.x = -0.9
                    rig.backRightLeg?.eulerAngles.x = -0.9
                    bobY -= 0.06

                case .ghost:
                    bobY -= 0.08
                }
            } else if isSleeping {
                // Species-Specific Sleeping Postures (Requirement 8)
                switch species {
                case .cat:
                    rig.bodyNode.eulerAngles.z = 0.15
                    rig.tailNode?.eulerAngles.y = 0.65
                    bobY -= 0.09

                case .dragon:
                    rig.leftWingNode?.eulerAngles.z = 0.05
                    rig.rightWingNode?.eulerAngles.z = -0.05
                    rig.tailNode?.eulerAngles.y = 0.70
                    bobY -= 0.10

                case .fox:
                    rig.tailNode?.eulerAngles.y = 0.85
                    bobY -= 0.08

                case .bunny:
                    rig.leftEarNode?.eulerAngles.x = -0.35
                    rig.rightEarNode?.eulerAngles.x = -0.35
                    bobY -= 0.09

                case .robot:
                    rig.leftShoulderNode?.eulerAngles.x = 0.05
                    rig.leftElbowNode?.eulerAngles.x = 0.2
                    rig.rightShoulderNode?.eulerAngles.x = 0.05
                    rig.rightElbowNode?.eulerAngles.x = 0.2
                    bobY -= 0.06

                case .robotcat:
                    bobY -= 0.08

                case .ghost:
                    bobY -= 0.06
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

                // Robot Arm Neutral, Waving & Talking Gestures
                if species == .robot {
                    if isWaving {
                        let waveElapsed = t - waveStartTime
                        if waveElapsed <= 3.0 {
                            rig.rightShoulderNode?.eulerAngles.x = -CGFloat(Double.pi / 1.7)
                            rig.rightElbowNode?.eulerAngles.x = CGFloat(Double.pi / 2.3)
                            rig.rightWristNode?.eulerAngles.y = CGFloat(sin(t * 14.0)) * 0.45
                        } else {
                            isWaving = false
                        }
                    } else if isTalking {
                        // Expressive robotic hand gestures during chat
                        rig.leftShoulderNode?.eulerAngles.x = -0.22 - CGFloat(sin(t * 3.5)) * 0.12
                        rig.leftElbowNode?.eulerAngles.x = 0.55 + CGFloat(cos(t * 3.5)) * 0.15
                        rig.rightShoulderNode?.eulerAngles.x = -0.22 + CGFloat(sin(t * 3.5)) * 0.12
                        rig.rightElbowNode?.eulerAngles.x = 0.55 - CGFloat(cos(t * 3.5)) * 0.15
                    } else {
                        rig.leftShoulderNode?.eulerAngles.x = 0.04
                        rig.leftElbowNode?.eulerAngles.x = 0.18
                        rig.rightShoulderNode?.eulerAngles.x = 0.04
                        rig.rightElbowNode?.eulerAngles.x = 0.18
                        rig.rightWristNode?.eulerAngles.y = 0.0
                    }
                }
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

            // 8. Emotion & Head Targeting Variables
            var targetHeadPitch: CGFloat = 0.0
            var targetHeadRoll: CGFloat = 0.0
            var targetHeadYaw: CGFloat = 0.0

            // Dragon Fire Breath Animation Sequence (Requirement 4)
            if isBreathingFire, let emitter = rig.fireEmitterNode {
                let fireElapsed = t - fireStartTime
                if fireElapsed <= 0.4 {
                    // Phase 1: Inhale & prepare
                    targetJaw = 0.15
                    targetHeadPitch = 0.22
                    scaleXZ = 1.10
                } else if fireElapsed <= 2.2 {
                    // Phase 2: Fire burst!
                    targetJaw = 0.55
                    rig.jawNode?.eulerAngles.x = 0.55
                    if activeFlameBurstNodes.isEmpty {
                        for fi in 0..<3 {
                            let flameGeo = SCNCone(topRadius: 0.01, bottomRadius: CGFloat(0.045 + Double(fi) * 0.025), height: CGFloat(0.14 + Double(fi) * 0.09))
                            let flameMat = Pet3DCharacterBuilder.pbrMaterial(
                                color: NSColor(red: 1.0, green: CGFloat(0.35 + Double(fi) * 0.2), blue: 0.05, alpha: 0.92),
                                roughness: 0.1,
                                emission: NSColor(red: 1.0, green: CGFloat(0.50 + Double(fi) * 0.2), blue: 0.1, alpha: 1.0)
                            )
                            flameGeo.materials = [flameMat]
                            let fn = SCNNode(geometry: flameGeo)
                            fn.position = SCNVector3(0, 0, 0.08 + Double(fi) * 0.14)
                            fn.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
                            emitter.addChildNode(fn)
                            activeFlameBurstNodes.append(fn)
                        }
                    }
                    for (fi, fn) in activeFlameBurstNodes.enumerated() {
                        let flutter = CGFloat(sin(t * 24.0 + Double(fi) * 2.0)) * 0.016
                        fn.position.x = flutter
                        fn.scale = SCNVector3(1.0 + flutter * 3.0, 1.0 + flutter * 3.0, 1.0 + flutter * 3.0)
                    }
                } else if fireElapsed <= 2.8 {
                    // Phase 3: Flames dissipate
                    for fn in activeFlameBurstNodes {
                        fn.removeFromParentNode()
                    }
                    activeFlameBurstNodes.removeAll()
                    targetJaw = 0.0
                } else {
                    isBreathingFire = false
                }
            }

            // Species-Specific Dancing (Requirement 22)
            if isDancing {
                switch species {
                case .dragon:
                    let danceBeat = sin(t * 8.0)
                    bobY += CGFloat(abs(danceBeat)) * 0.05
                    rig.leftWingNode?.eulerAngles.z = CGFloat(Double.pi / 3) + CGFloat(sin(t * 10.0)) * 0.45
                    rig.rightWingNode?.eulerAngles.z = -CGFloat(Double.pi / 3) - CGFloat(sin(t * 10.0)) * 0.45
                    rig.tailNode?.eulerAngles.y = CGFloat(sin(t * 12.0)) * 0.65

                case .robot:
                    // Mechanical popping & locking with dual arms
                    let beat = sin(t * 6.5)
                    rig.rightShoulderNode?.eulerAngles.x = -CGFloat(Double.pi / 2.2) + CGFloat(sin(t * 6.5)) * 0.35
                    rig.leftShoulderNode?.eulerAngles.x = CGFloat(sin(t * 6.5 + Double.pi)) * 0.35
                    rig.rightElbowNode?.eulerAngles.x = 0.85 + CGFloat(cos(t * 6.5)) * 0.25
                    rig.leftElbowNode?.eulerAngles.x = 0.85 - CGFloat(cos(t * 6.5)) * 0.25
                    bobY += CGFloat(abs(beat)) * 0.04
                    rig.frontLeftLeg?.eulerAngles.x = CGFloat(beat) * 0.25
                    rig.frontRightLeg?.eulerAngles.x = -CGFloat(beat) * 0.25

                case .cat:
                    bobY += CGFloat(abs(sin(t * 6.0))) * 0.04
                    rig.rootNode.eulerAngles.z = CGFloat(sin(t * 6.0)) * 0.06
                    rig.tailNode?.eulerAngles.y = CGFloat(sin(t * 8.0)) * 0.50

                case .fox:
                    bobY += CGFloat(abs(sin(t * 7.0))) * 0.05
                    rig.tailNode?.eulerAngles.y = CGFloat(sin(t * 9.0)) * 0.70

                case .bunny:
                    bobY += CGFloat(abs(sin(t * 8.5))) * 0.12
                    rig.leftEarNode?.eulerAngles.x = CGFloat(sin(t * 8.5)) * 0.35
                    rig.rightEarNode?.eulerAngles.x = CGFloat(sin(t * 8.5)) * 0.35

                case .robotcat:
                    bobY += CGFloat(abs(sin(t * 6.5))) * 0.04
                    rig.tailNode?.eulerAngles.y = CGFloat(sin(t * 10.0)) * 0.45

                case .ghost:
                    bobY += CGFloat(sin(t * 5.0)) * 0.10
                    rig.leftArmNode?.eulerAngles.z = CGFloat(Double.pi / 2.5) + CGFloat(sin(t * 5.0)) * 0.30
                    rig.rightArmNode?.eulerAngles.z = -CGFloat(Double.pi / 2.5) - CGFloat(sin(t * 5.0)) * 0.30
                }
            }

            // 9. Emotion Engine Full Mapping (Requirement 4)
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

            // Smoothly interpolate head angles (including LookAtUserController)
            let finalTargetPitch = targetHeadPitch + currentLookAtPitch
            let finalTargetYaw = targetHeadYaw + currentLookAtYaw
            currentHeadPitch += (finalTargetPitch - currentHeadPitch) * 0.15
            currentHeadRoll += (targetHeadRoll - currentHeadRoll) * 0.15
            currentHeadYaw += (finalTargetYaw - currentHeadYaw) * 0.15

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
