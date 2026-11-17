import Foundation
import SceneKit

// MARK: - Pose Probe Node

/// A detached stand-in for a rig joint whose Euler angles are plain stored values.
///
/// Pose code (walk / sit / sleep / dance / idle / mood) writes to these instead of the live
/// scene nodes. That lets `RigPoseLayer` read the requested angles back exactly as written,
/// without depending on how SceneKit decomposes its internal orientation into Euler angles
/// (which is ambiguous for large angles and at yaw = +/- pi/2).
final class PoseProbeNode: SCNNode {
    private var storedEulerAngles = SCNVector3Zero

    override var eulerAngles: SCNVector3 {
        get { storedEulerAngles }
        set { storedEulerAngles = newValue }
    }
}

// MARK: - Joint Limits

/// Per-axis limits in radians for a joint's node-local Euler angles.
struct JointLimits {
    var x: ClosedRange<CGFloat>
    var y: ClosedRange<CGFloat>
    var z: ClosedRange<CGFloat>

    func clamped(_ v: SCNVector3) -> SCNVector3 {
        SCNVector3(
            JointLimits.clamp(v.x, to: x),
            JointLimits.clamp(v.y, to: y),
            JointLimits.clamp(v.z, to: z)
        )
    }

    private static func clamp(_ value: CGFloat, to range: ClosedRange<CGFloat>) -> CGFloat {
        guard value.isFinite else { return 0 }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    // Root: yaw carries the movement direction (up to +/- pi); pitch/roll are small sways.
    static let root = JointLimits(x: -0.35...0.35, y: -CGFloat.pi...CGFloat.pi, z: -0.35...0.35)
    static let body = JointLimits(x: -0.40...0.40, y: -0.50...0.50, z: -0.50...0.50)

    static let leftWing = JointLimits(x: -0.60...0.60, y: -0.60...0.60, z: -0.25...1.80)
    static let rightWing = JointLimits(x: -0.60...0.60, y: -0.60...0.60, z: -1.80...0.25)

    static let ear = JointLimits(x: -0.90...0.90, y: -0.60...0.60, z: -1.00...1.00)
    static let tail = JointLimits(x: -0.90...0.90, y: -1.20...1.20, z: -0.60...0.60)
    static let tailSegment = JointLimits(x: -0.50...0.50, y: -0.90...0.90, z: -0.50...0.50)

    static let leg = JointLimits(x: -1.40...1.40, y: -0.50...0.50, z: -0.50...0.50)
    static let shin = JointLimits(x: -1.30...1.60, y: -0.30...0.30, z: -0.30...0.30)
    static let paw = JointLimits(x: -1.00...1.00, y: -0.30...0.30, z: -0.30...0.30)

    static let shoulder = JointLimits(x: -2.20...2.20, y: -0.80...0.80, z: -1.00...1.00)
    static let upperArm = JointLimits(x: -2.20...2.20, y: -0.60...0.60, z: -2.20...2.20)
    static let elbow = JointLimits(x: 0.0...2.4, y: -0.40...0.40, z: -0.40...0.40)
    static let wrist = JointLimits(x: -1.00...1.00, y: -0.80...0.80, z: -0.80...0.80)
    static let hand = JointLimits(x: -1.00...1.00, y: -0.80...0.80, z: -0.80...0.80)
}

// MARK: - Rig Pose Layer

/// Sits between the pose code and the live SceneKit rig.
///
/// Per frame:
///  1. `beginFrame()` resets every animated joint of the scratch rig (`pose`) to the neutral pose.
///  2. Pose code writes the active state's angles into `pose` (offsets from neutral).
///  3. `commit(dt:)` clamps each joint to its limits, eases it from last frame's value,
///     and writes the result to the live node.
///
/// The neutral pose is all-zero Euler angles, the same neutral that
/// `SpeciesDanceController.reset(rig:)` and the idle branch have always used.
/// Head, eyes, lids and jaw are intentionally not managed here.
final class RigPoseLayer {
    /// Exponential easing rate (1/seconds). Higher = snappier. About 95% of a step in ~125 ms.
    static let easeRate: CGFloat = 24
    /// Wrist / hand joints carry fast oscillations (e.g. the robot wave), so they ease less.
    static let fastEaseRate: CGFloat = 45

    /// Scratch rig. Same shape as the live rig, so existing pose code works unchanged on it.
    let pose: Pet3DRig

    private struct Binding {
        let probe: PoseProbeNode
        let live: SCNNode
        let limits: JointLimits
        let rate: CGFloat
        var smoothed: SCNVector3?
    }

    private var bindings: [Binding] = []

    init(rig: Pet3DRig) {
        var collected: [Binding] = []
        var probeForLiveNode: [ObjectIdentifier: PoseProbeNode] = [:]

        // One probe per live node, so a node referenced by two rig slots is only eased once.
        func bind(_ live: SCNNode, _ limits: JointLimits, rate: CGFloat = RigPoseLayer.easeRate) -> PoseProbeNode {
            let id = ObjectIdentifier(live)
            if let existing = probeForLiveNode[id] { return existing }
            let probe = PoseProbeNode()
            probeForLiveNode[id] = probe
            collected.append(Binding(probe: probe, live: live, limits: limits, rate: rate, smoothed: nil))
            return probe
        }

        func bindOpt(_ live: SCNNode?, _ limits: JointLimits, rate: CGFloat = RigPoseLayer.easeRate) -> PoseProbeNode? {
            guard let live = live else { return nil }
            return bind(live, limits, rate: rate)
        }

        pose = Pet3DRig(
            rootNode: bind(rig.rootNode, .root),
            bodyNode: bind(rig.bodyNode, .body),
            headNode: SCNNode(), // never animated through the layer
            leftEarNode: bindOpt(rig.leftEarNode, .ear),
            rightEarNode: bindOpt(rig.rightEarNode, .ear),
            tailNode: bindOpt(rig.tailNode, .tail),
            tailSegments: rig.tailSegments.map { bind($0, .tailSegment) },
            leftWingNode: bindOpt(rig.leftWingNode, .leftWing),
            rightWingNode: bindOpt(rig.rightWingNode, .rightWing),
            frontLeftLeg: bindOpt(rig.frontLeftLeg, .leg),
            frontLeftShin: bindOpt(rig.frontLeftShin, .shin),
            frontLeftPaw: bindOpt(rig.frontLeftPaw, .paw),
            frontRightLeg: bindOpt(rig.frontRightLeg, .leg),
            frontRightShin: bindOpt(rig.frontRightShin, .shin),
            frontRightPaw: bindOpt(rig.frontRightPaw, .paw),
            backLeftLeg: bindOpt(rig.backLeftLeg, .leg),
            backLeftShin: bindOpt(rig.backLeftShin, .shin),
            backLeftPaw: bindOpt(rig.backLeftPaw, .paw),
            backRightLeg: bindOpt(rig.backRightLeg, .leg),
            backRightShin: bindOpt(rig.backRightShin, .shin),
            backRightPaw: bindOpt(rig.backRightPaw, .paw),
            leftShoulderNode: bindOpt(rig.leftShoulderNode, .shoulder),
            leftArmNode: bindOpt(rig.leftArmNode, .upperArm),
            leftElbowNode: bindOpt(rig.leftElbowNode, .elbow),
            leftWristNode: bindOpt(rig.leftWristNode, .wrist, rate: RigPoseLayer.fastEaseRate),
            leftHandNode: bindOpt(rig.leftHandNode, .hand, rate: RigPoseLayer.fastEaseRate),
            rightShoulderNode: bindOpt(rig.rightShoulderNode, .shoulder),
            rightArmNode: bindOpt(rig.rightArmNode, .upperArm),
            rightElbowNode: bindOpt(rig.rightElbowNode, .elbow),
            rightWristNode: bindOpt(rig.rightWristNode, .wrist, rate: RigPoseLayer.fastEaseRate),
            rightHandNode: bindOpt(rig.rightHandNode, .hand, rate: RigPoseLayer.fastEaseRate)
        )
        bindings = collected
    }

    /// Step 1 of every frame: every animated joint goes back to the neutral pose.
    func beginFrame() {
        for binding in bindings {
            binding.probe.eulerAngles = SCNVector3Zero
        }
    }

    /// Last step of every frame: clamp, ease toward the requested pose, write to the live rig.
    /// The first frame after a rig is built applies the pose directly (nothing to ease from).
    func commit(dt: TimeInterval) {
        let step = max(0.0, dt)
        for i in bindings.indices {
            let binding = bindings[i]
            let target = binding.limits.clamped(binding.probe.eulerAngles)

            var next = target
            if let previous = binding.smoothed {
                let a = CGFloat(1.0 - exp(-Double(binding.rate) * step))
                next = SCNVector3(
                    previous.x + (target.x - previous.x) * a,
                    previous.y + (target.y - previous.y) * a,
                    previous.z + (target.z - previous.z) * a
                )
            }

            bindings[i].smoothed = next
            binding.live.eulerAngles = next
        }
    }
}
