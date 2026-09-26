import Foundation
import SwiftUI
import SceneKit
import AppKit

// MARK: - SwiftUI NSViewRepresentable Wrapper for Native 3D Character View

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

    // MARK: - Coordinator Driving Procedural Kinematics & Emotions
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
            let isThinking = (animState == .thinking || petState.isThinking)
            let isSleeping = (animState == .sleep || mood == .sleepy)
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

            // 2. Music Beat Reactivity (Phase 12)
            if musicAmp > 0.05 && !reduceMotion {
                bobY += CGFloat(musicAmp) * 0.09
                scaleY += CGFloat(musicAmp) * 0.06
                scaleXZ -= CGFloat(musicAmp) * 0.04
            }

            // 3. Realistic Walking & Dancing Gait Kinematics (Phase 9)
            let walkSpeed: Double = reduceMotion ? 2.0 : 4.0
            let motionMultiplier: CGFloat = reduceMotion ? 0.35 : 1.0
            let phase = t * walkSpeed
            let isMoving = isDancing

            if isMoving {
                switch species {
                case .bunny:
                    // Hopping Gait for Rabbit
                    let hopProgress = CGFloat(max(0.0, sin(t * (reduceMotion ? 2.5 : 5.0)))) * motionMultiplier
                    bobY += hopProgress * 0.12
                    let hopSquash = CGFloat(1.0) - (hopProgress * 0.15)
                    scaleY = hopSquash
                    scaleXZ = CGFloat(1.0) + (hopProgress * 0.1)

                    rig.frontLeftLeg?.eulerAngles.x = -hopProgress * 0.4
                    rig.frontRightLeg?.eulerAngles.x = -hopProgress * 0.4
                    rig.backLeftLeg?.eulerAngles.x = hopProgress * 0.6
                    rig.backRightLeg?.eulerAngles.x = hopProgress * 0.6

                    // Ears stream back in air
                    rig.leftEarNode?.eulerAngles.x = -hopProgress * 0.35
                    rig.rightEarNode?.eulerAngles.x = -hopProgress * 0.35

                case .ghost:
                    // Undulating Spectral Float
                    bobY += CGFloat(sin(t * 3.0)) * 0.06
                    rig.rootNode.eulerAngles.z = CGFloat(sin(t * 2.0)) * 0.08
                    rig.rootNode.eulerAngles.x = CGFloat(cos(t * 2.0)) * 0.06
                    rig.frontLeftLeg?.eulerAngles.z = CGFloat(Double.pi / 4) + CGFloat(sin(t * 3.5)) * 0.15
                    rig.frontRightLeg?.eulerAngles.z = -CGFloat(Double.pi / 4) - CGFloat(sin(t * 3.5)) * 0.15

                default:
                    // Diagonal Quadruped Gait (Cat, Fox, Dog, Dragon, RobotCat)
                    let fl_swing = CGFloat(sin(phase)) * 0.45
                    let fr_swing = CGFloat(sin(phase + Double.pi)) * 0.45
                    let bl_swing = fr_swing
                    let br_swing = fl_swing

                    rig.frontLeftLeg?.eulerAngles.x = fl_swing
                    rig.frontRightLeg?.eulerAngles.x = fr_swing
                    rig.backLeftLeg?.eulerAngles.x = bl_swing
                    rig.backRightLeg?.eulerAngles.x = br_swing

                    // Torso double-frequency bob
                    bobY += CGFloat(abs(sin(phase))) * 0.03
                    rig.rootNode.eulerAngles.z = CGFloat(sin(phase)) * 0.04
                }
            } else {
                // Standing rest
                rig.frontLeftLeg?.eulerAngles.x = 0
                rig.frontRightLeg?.eulerAngles.x = 0
                rig.backLeftLeg?.eulerAngles.x = 0
                rig.backRightLeg?.eulerAngles.x = 0
                rig.rootNode.eulerAngles.z = 0
            }

            // 4. Wings Flapping (Dragon)
            if let lw = rig.leftWingNode, let rw = rig.rightWingNode {
                let wingRate = isDancing ? 8.0 : (mood == .excited ? 6.0 : 2.5)
                let flap = CGFloat(sin(t * wingRate)) * 0.35
                lw.eulerAngles.z = CGFloat(Double.pi / 3) + flap
                rw.eulerAngles.z = -CGFloat(Double.pi / 3) - flap
            }

            // 5. Tail Expressive Dynamics
            if let tail = rig.tailNode {
                let tailWagFreq = isDancing ? 10.0 : (mood == .excited ? 8.0 : (mood == .happy ? 5.0 : 2.5))
                let tailAmp: CGFloat = (mood == .sad) ? 0.05 : 0.35
                tail.eulerAngles.y = CGFloat(sin(t * tailWagFreq)) * tailAmp

                for (idx, seg) in rig.tailSegments.enumerated() {
                    let delay = Double(idx + 1) * 0.2
                    seg.eulerAngles.y = CGFloat(sin((t - delay) * tailWagFreq)) * (tailAmp * 0.7)
                }
            }

            // 6. Emotion Engine Mapping (Phase 10)
            var headPitch: CGFloat = 0.0
            var headRoll: CGFloat = 0.0
            var headYaw: CGFloat = 0.0
            var eyeScaleY: CGFloat = 1.0

            switch mood {
            case .happy:
                headRoll = CGFloat(sin(t * 2.0)) * 0.08
                headPitch = CGFloat(cos(t * 2.0)) * 0.05
                rig.leftEarNode?.eulerAngles.z = -CGFloat(Double.pi / 12) + CGFloat(sin(t * 3.0)) * 0.04
                rig.rightEarNode?.eulerAngles.z = CGFloat(Double.pi / 12) - CGFloat(sin(t * 3.0)) * 0.04

            case .sad, .crying:
                headPitch = -0.32 // Droop head
                rig.leftEarNode?.eulerAngles.z = -CGFloat(Double.pi / 5)
                rig.rightEarNode?.eulerAngles.z = CGFloat(Double.pi / 5)
                bobY -= 0.03

            case .sleepy:
                headPitch = -0.22
                eyeScaleY = 0.12 // Closed eyelids
                scaleY = 0.94
                bobY -= 0.04

            case .excited:
                headPitch = CGFloat(sin(t * 6.0)) * 0.1
                bobY += CGFloat(abs(sin(t * 6.0))) * 0.04

            case .concerned:
                headRoll = 0.25 // Puzzled inquisitive tilt
                headYaw = -0.15
                rig.leftEarNode?.eulerAngles.z = -CGFloat(Double.pi / 6)
                rig.rightEarNode?.eulerAngles.z = 0.0

            case .surprised:
                headPitch = 0.15
                eyeScaleY = 1.25
                scaleY = 1.08

            case .angry:
                headPitch = -0.18
                headYaw = CGFloat(sin(t * 4.0)) * 0.05

            case .proud:
                headPitch = 0.22 // High chin
                scaleXZ = 1.05

            default:
                headRoll = CGFloat(snapshot.headTiltAngle.radians) * 0.5
            }

            if isSleeping {
                headPitch = -0.22
                eyeScaleY = 0.12
                scaleY = 0.94
                bobY -= 0.04
            }

            // Apply Thinking indicator gaze drift
            if isThinking {
                headYaw = CGFloat(sin(t * 1.5)) * 0.2
                headPitch = 0.12
            }

            // Apply Transforms
            rig.bodyNode.position.y = 0.26 + bobY
            rig.bodyNode.scale = SCNVector3(scaleXZ, scaleY, scaleXZ)
            rig.headNode.eulerAngles = SCNVector3(headPitch, headYaw, headRoll)

            // Eye Blinking & Shape
            rig.leftEyeNode?.scale.y = eyeScaleY
            rig.rightEyeNode?.scale.y = eyeScaleY
        }

        deinit {
            displayTimer?.invalidate()
        }
    }
}
