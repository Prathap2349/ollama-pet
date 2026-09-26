import Foundation
import SceneKit
import AppKit

// MARK: - 3D Rig Structure Representing Comprehensive Character Anatomy

public struct Pet3DRig {
    public let rootNode: SCNNode
    public let bodyNode: SCNNode
    public let neckNode: SCNNode?
    public let headNode: SCNNode

    // Facial System: Eyes & Eyelids (Requirement 2)
    public let leftEyeNode: SCNNode?
    public let rightEyeNode: SCNNode?
    public let leftPupilNode: SCNNode?
    public let rightPupilNode: SCNNode?
    public let leftUpperLid: SCNNode?
    public let rightUpperLid: SCNNode?
    public let leftLowerLid: SCNNode?
    public let rightLowerLid: SCNNode?

    // Facial System: Jaw & Mouth (Requirement 3)
    public let jawNode: SCNNode?
    public let tongueNode: SCNNode?
    public let upperTeethNode: SCNNode?
    public let lowerTeethNode: SCNNode?

    // Features
    public let leftEarNode: SCNNode?
    public let rightEarNode: SCNNode?
    public let tailNode: SCNNode?
    public let tailSegments: [SCNNode]
    public let leftWingNode: SCNNode?
    public let rightWingNode: SCNNode?

    // Articulated 4-Leg Limb Hierarchy (Requirements 5 & 7)
    public let frontLeftLeg: SCNNode?   // Thigh / upper arm
    public let frontLeftShin: SCNNode?  // Lower arm / shin
    public let frontLeftPaw: SCNNode?   // Paw / foot / claws

    public let frontRightLeg: SCNNode?
    public let frontRightShin: SCNNode?
    public let frontRightPaw: SCNNode?

    public let backLeftLeg: SCNNode?    // Hip / upper thigh
    public let backLeftShin: SCNNode?   // Knee / hock / lower leg
    public let backLeftPaw: SCNNode?    // Hind paw / claws

    public let backRightLeg: SCNNode?
    public let backRightShin: SCNNode?
    public let backRightPaw: SCNNode?

    public let hornsNode: SCNNode?
    public let accessoriesNode: SCNNode?

    public init(
        rootNode: SCNNode,
        bodyNode: SCNNode,
        neckNode: SCNNode? = nil,
        headNode: SCNNode,
        leftEyeNode: SCNNode? = nil,
        rightEyeNode: SCNNode? = nil,
        leftPupilNode: SCNNode? = nil,
        rightPupilNode: SCNNode? = nil,
        leftUpperLid: SCNNode? = nil,
        rightUpperLid: SCNNode? = nil,
        leftLowerLid: SCNNode? = nil,
        rightLowerLid: SCNNode? = nil,
        jawNode: SCNNode? = nil,
        tongueNode: SCNNode? = nil,
        upperTeethNode: SCNNode? = nil,
        lowerTeethNode: SCNNode? = nil,
        leftEarNode: SCNNode? = nil,
        rightEarNode: SCNNode? = nil,
        tailNode: SCNNode? = nil,
        tailSegments: [SCNNode] = [],
        leftWingNode: SCNNode? = nil,
        rightWingNode: SCNNode? = nil,
        frontLeftLeg: SCNNode? = nil,
        frontLeftShin: SCNNode? = nil,
        frontLeftPaw: SCNNode? = nil,
        frontRightLeg: SCNNode? = nil,
        frontRightShin: SCNNode? = nil,
        frontRightPaw: SCNNode? = nil,
        backLeftLeg: SCNNode? = nil,
        backLeftShin: SCNNode? = nil,
        backLeftPaw: SCNNode? = nil,
        backRightLeg: SCNNode? = nil,
        backRightShin: SCNNode? = nil,
        backRightPaw: SCNNode? = nil,
        hornsNode: SCNNode? = nil,
        accessoriesNode: SCNNode? = nil
    ) {
        self.rootNode = rootNode
        self.bodyNode = bodyNode
        self.neckNode = neckNode
        self.headNode = headNode
        self.leftEyeNode = leftEyeNode
        self.rightEyeNode = rightEyeNode
        self.leftPupilNode = leftPupilNode
        self.rightPupilNode = rightPupilNode
        self.leftUpperLid = leftUpperLid
        self.rightUpperLid = rightUpperLid
        self.leftLowerLid = leftLowerLid
        self.rightLowerLid = rightLowerLid
        self.jawNode = jawNode
        self.tongueNode = tongueNode
        self.upperTeethNode = upperTeethNode
        self.lowerTeethNode = lowerTeethNode
        self.leftEarNode = leftEarNode
        self.rightEarNode = rightEarNode
        self.tailNode = tailNode
        self.tailSegments = tailSegments
        self.leftWingNode = leftWingNode
        self.rightWingNode = rightWingNode
        self.frontLeftLeg = frontLeftLeg
        self.frontLeftShin = frontLeftShin
        self.frontLeftPaw = frontLeftPaw
        self.frontRightLeg = frontRightLeg
        self.frontRightShin = frontRightShin
        self.frontRightPaw = frontRightPaw
        self.backLeftLeg = backLeftLeg
        self.backLeftShin = backLeftShin
        self.backLeftPaw = backLeftPaw
        self.backRightLeg = backRightLeg
        self.backRightShin = backRightShin
        self.backRightPaw = backRightPaw
        self.hornsNode = hornsNode
        self.accessoriesNode = accessoriesNode
    }
}

// MARK: - Procedural 3D Character Builder

public class Pet3DCharacterBuilder {

    // MARK: - Material Factory
    public static func pbrMaterial(
        color: NSColor,
        roughness: CGFloat = 0.42,
        metalness: CGFloat = 0.05,
        emission: NSColor? = nil
    ) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = color
        mat.roughness.contents = roughness
        mat.metalness.contents = metalness
        if let em = emission {
            mat.emission.contents = em
        }
        return mat
    }

    // MARK: - Component Builders

    public struct FacialEyeComponents {
        public let eyeNode: SCNNode
        public let pupilNode: SCNNode
        public let upperLidNode: SCNNode
        public let lowerLidNode: SCNNode
    }

    private static func makeFacialEye(
        eyeMat: SCNMaterial,
        pupilMat: SCNMaterial,
        lidMat: SCNMaterial,
        radius: CGFloat = 0.055,
        isDragonPupil: Bool = false
    ) -> FacialEyeComponents {
        let eye = SCNNode()

        // Sclera / Iris sphere
        let scleraGeo = SCNSphere(radius: radius)
        scleraGeo.materials = [eyeMat]
        let scleraNode = SCNNode(geometry: scleraGeo)
        eye.addChildNode(scleraNode)

        // Saccade-capable Pupil
        let pupilGeo = SCNSphere(radius: radius * 0.52)
        pupilGeo.materials = [pupilMat]
        let pupilNode = SCNNode(geometry: pupilGeo)
        if isDragonPupil {
            pupilNode.scale = SCNVector3(0.35, 1.25, 0.45) // Dragon slit pupil
        } else {
            pupilNode.scale = SCNVector3(0.95, 0.95, 0.5) // Round warm mammalian pupil
        }
        pupilNode.position = SCNVector3(0, 0, radius * 0.72)
        eye.addChildNode(pupilNode)

        // Upper Eyelid Shell
        let upperLidGeo = SCNSphere(radius: radius * 1.06)
        upperLidGeo.materials = [lidMat]
        let upperLid = SCNNode(geometry: upperLidGeo)
        upperLid.position = SCNVector3(0, radius * 0.52, 0.005)
        upperLid.scale = SCNVector3(1.06, 0.02, 1.06)
        eye.addChildNode(upperLid)

        // Lower Eyelid Shell (Cheek raise for smiling/squinting)
        let lowerLidGeo = SCNSphere(radius: radius * 1.05)
        lowerLidGeo.materials = [lidMat]
        let lowerLid = SCNNode(geometry: lowerLidGeo)
        lowerLid.position = SCNVector3(0, -radius * 0.62, 0.005)
        lowerLid.scale = SCNVector3(1.06, 0.02, 1.06)
        eye.addChildNode(lowerLid)

        return FacialEyeComponents(
            eyeNode: eye,
            pupilNode: pupilNode,
            upperLidNode: upperLid,
            lowerLidNode: lowerLid
        )
    }

    public struct JawComponents {
        public let jawNode: SCNNode
        public let tongueNode: SCNNode
        public let teethNode: SCNNode
    }

    private static func makeArticulatedJaw(
        primaryMat: SCNMaterial,
        length: CGFloat = 0.22,
        width: CGFloat = 0.16
    ) -> JawComponents {
        let jawPivot = SCNNode() // Pivots on X-axis at base of mandible

        // Mandible bone
        let mandibleGeo = SCNCapsule(capRadius: width * 0.42, height: length)
        mandibleGeo.materials = [primaryMat]
        let mandible = SCNNode(geometry: mandibleGeo)
        mandible.position = SCNVector3(0, -0.025, length * 0.42)
        mandible.eulerAngles = SCNVector3(Float.pi / 2.1, 0, 0)
        mandible.scale = SCNVector3(1.0, 0.5, 1.0)
        jawPivot.addChildNode(mandible)

        // Tongue
        let tongueMat = pbrMaterial(color: NSColor(red: 0.95, green: 0.48, blue: 0.58, alpha: 1.0), roughness: 0.3)
        let tongueGeo = SCNCapsule(capRadius: width * 0.22, height: length * 0.55)
        tongueGeo.materials = [tongueMat]
        let tongue = SCNNode(geometry: tongueGeo)
        tongue.position = SCNVector3(0, 0.015, length * 0.38)
        tongue.eulerAngles = SCNVector3(Float.pi / 2.0, 0, 0)
        tongue.scale = SCNVector3(1.0, 0.35, 1.0)
        jawPivot.addChildNode(tongue)

        // Teeth ridge
        let teethMat = pbrMaterial(color: NSColor(white: 0.97, alpha: 1.0), roughness: 0.25)
        let teethGeo = SCNBox(width: width * 0.65, height: 0.018, length: length * 0.65, chamferRadius: 0.005)
        teethGeo.materials = [teethMat]
        let teeth = SCNNode(geometry: teethGeo)
        teeth.position = SCNVector3(0, 0.025, length * 0.42)
        teeth.eulerAngles = SCNVector3(Float.pi / 2.1, 0, 0)
        jawPivot.addChildNode(teeth)

        return JawComponents(jawNode: jawPivot, tongueNode: tongue, teethNode: teeth)
    }

    public struct ArticulatedLegComponents {
        public let upperLegNode: SCNNode
        public let shinNode: SCNNode
        public let pawNode: SCNNode
    }

    private static func makeArticulatedLeg(
        mat: SCNMaterial,
        clawMat: SCNMaterial,
        upperLength: CGFloat = 0.16,
        lowerLength: CGFloat = 0.16,
        radius: CGFloat = 0.055,
        addClaws: Bool = true
    ) -> ArticulatedLegComponents {
        let upper = SCNNode() // Hip / shoulder pivot

        let upperBoneGeo = SCNCapsule(capRadius: radius, height: upperLength + (radius * 1.5))
        upperBoneGeo.materials = [mat]
        let upperBone = SCNNode(geometry: upperBoneGeo)
        upperBone.position = SCNVector3(0, -upperLength * 0.5, 0)
        upper.addChildNode(upperBone)

        // Knee / Elbow joint
        let shin = SCNNode()
        shin.position = SCNVector3(0, -upperLength, 0)
        upper.addChildNode(shin)

        let shinBoneGeo = SCNCapsule(capRadius: radius * 0.88, height: lowerLength + (radius * 1.2))
        shinBoneGeo.materials = [mat]
        let shinBone = SCNNode(geometry: shinBoneGeo)
        shinBone.position = SCNVector3(0, -lowerLength * 0.5, 0)
        shin.addChildNode(shinBone)

        // Ankle / Paw joint
        let paw = SCNNode()
        paw.position = SCNVector3(0, -lowerLength, 0.02)
        shin.addChildNode(paw)

        let pawPadGeo = SCNBox(width: radius * 2.1, height: radius * 0.85, length: radius * 2.6, chamferRadius: 0.015)
        pawPadGeo.materials = [mat]
        let pawPad = SCNNode(geometry: pawPadGeo)
        pawPad.position = SCNVector3(0, -radius * 0.4, radius * 0.5)
        paw.addChildNode(pawPad)

        if addClaws {
            for c in [-1, 0, 1] {
                let clawGeo = SCNCone(topRadius: 0.003, bottomRadius: 0.012, height: 0.038)
                clawGeo.materials = [clawMat]
                let claw = SCNNode(geometry: clawGeo)
                claw.position = SCNVector3(CGFloat(c) * (radius * 0.65), -radius * 0.4, radius * 1.8)
                claw.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
                paw.addChildNode(claw)
            }
        }

        return ArticulatedLegComponents(upperLegNode: upper, shinNode: shin, pawNode: paw)
    }

    // MARK: - Build Character Rig for Species
    public static func buildCharacter(
        species: PetSpecies,
        customHornEnabled: Bool = true,
        customWingsEnabled: Bool = true,
        customAccessory: String = "none"
    ) -> Pet3DRig {
        switch species {
        case .dragon:
            return buildDragon(customHorn: customHornEnabled, customWings: customWingsEnabled, accessory: customAccessory)
        case .fox:
            return buildFox(accessory: customAccessory)
        case .bunny:
            return buildRabbit(accessory: customAccessory)
        case .robot:
            return buildRobot(accessory: customAccessory)
        case .robotcat:
            return buildRobotCat(accessory: customAccessory)
        case .ghost:
            return buildGhost(accessory: customAccessory)
        case .cat:
            return buildCat(accessory: customAccessory)
        }
    }

    // MARK: - 1. Dragon (Ember - Full Anatomy Upgrade)
    private static func buildDragon(customHorn: Bool, customWings: Bool, accessory: String) -> Pet3DRig {
        let root = SCNNode()
        let body = SCNNode()
        body.position = SCNVector3(0, 0.28, 0)
        root.addChildNode(body)

        let primaryMat = pbrMaterial(color: NSColor(red: 0.95, green: 0.32, blue: 0.12, alpha: 1.0), roughness: 0.38, metalness: 0.12)
        let bellyMat = pbrMaterial(color: NSColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1.0), roughness: 0.45)
        let hornMat = pbrMaterial(color: NSColor(red: 1.0, green: 0.68, blue: 0.15, alpha: 1.0), roughness: 0.22, metalness: 0.35, emission: NSColor(red: 0.85, green: 0.42, blue: 0.05, alpha: 1.0))
        let eyeMat = pbrMaterial(color: NSColor(red: 1.0, green: 0.92, blue: 0.15, alpha: 1.0), roughness: 0.08, emission: NSColor(red: 0.75, green: 0.55, blue: 0.05, alpha: 1.0))
        let pupilMat = pbrMaterial(color: NSColor(red: 0.05, green: 0.02, blue: 0.02, alpha: 1.0), roughness: 0.1)
        let clawMat = pbrMaterial(color: NSColor(red: 0.92, green: 0.85, blue: 0.75, alpha: 1.0), roughness: 0.25)

        // 1. Muscular Torso & Dorsal Ridge
        let torsoGeo = SCNCapsule(capRadius: 0.26, height: 0.65)
        torsoGeo.materials = [primaryMat]
        let torsoNode = SCNNode(geometry: torsoGeo)
        torsoNode.eulerAngles = SCNVector3(Float.pi / 2.4, 0, 0)
        body.addChildNode(torsoNode)

        // Ventral Belly Plates
        let bellyGeo = SCNCapsule(capRadius: 0.21, height: 0.52)
        bellyGeo.materials = [bellyMat]
        let bellyNode = SCNNode(geometry: bellyGeo)
        bellyNode.position = SCNVector3(0, -0.06, 0.12)
        bellyNode.eulerAngles = SCNVector3(Float.pi / 2.4, 0, 0)
        body.addChildNode(bellyNode)

        // Dorsal Fin Spines along back
        for s in 0..<4 {
            let spineGeo = SCNPyramid(width: 0.045, height: 0.08, length: 0.06)
            spineGeo.materials = [hornMat]
            let spine = SCNNode(geometry: spineGeo)
            spine.position = SCNVector3(0, 0.14 - (Double(s) * 0.06), -0.08 - (Double(s) * 0.08))
            spine.eulerAngles = SCNVector3(Float.pi / 4, 0, 0)
            body.addChildNode(spine)
        }

        // 2. Flexible Neck
        let neck = SCNNode()
        neck.position = SCNVector3(0, 0.26, 0.18)
        neck.eulerAngles = SCNVector3(-Float.pi / 12, 0, 0)
        let neckGeo = SCNCylinder(radius: 0.14, height: 0.22)
        neckGeo.materials = [primaryMat]
        neck.addChildNode(SCNNode(geometry: neckGeo))
        body.addChildNode(neck)

        // 3. Head & Snout Architecture
        let head = SCNNode()
        head.position = SCNVector3(0, 0.15, 0.12)
        neck.addChildNode(head)

        // Sculpted cranial skull
        let headGeo = SCNSphere(radius: 0.22)
        headGeo.materials = [primaryMat]
        let headBase = SCNNode(geometry: headGeo)
        headBase.scale = SCNVector3(0.95, 0.95, 1.2)
        head.addChildNode(headBase)

        // Upper Snout Bridge
        let snoutGeo = SCNCapsule(capRadius: 0.11, height: 0.28)
        snoutGeo.materials = [primaryMat]
        let snout = SCNNode(geometry: snoutGeo)
        snout.position = SCNVector3(0, -0.01, 0.18)
        snout.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        head.addChildNode(snout)

        // Nostrils
        let nostrilMat = pbrMaterial(color: NSColor(red: 0.4, green: 0.15, blue: 0.05, alpha: 1.0), roughness: 0.8)
        for side in [-1.0, 1.0] {
            let nostril = SCNNode(geometry: SCNSphere(radius: 0.016))
            nostril.geometry?.materials = [nostrilMat]
            nostril.position = SCNVector3(CGFloat(side) * 0.045, 0.04, 0.31)
            head.addChildNode(nostril)
        }

        // Upper Teeth Row
        let upperTeethGeo = SCNBox(width: 0.12, height: 0.016, length: 0.18, chamferRadius: 0.004)
        upperTeethGeo.materials = [clawMat]
        let upperTeeth = SCNNode(geometry: upperTeethGeo)
        upperTeeth.position = SCNVector3(0, -0.055, 0.20)
        head.addChildNode(upperTeeth)

        // 4. Articulated Lower Jaw (Requirement 3)
        let jawComp = makeArticulatedJaw(primaryMat: primaryMat, length: 0.22, width: 0.15)
        jawComp.jawNode.position = SCNVector3(0, -0.065, 0.08)
        head.addChildNode(jawComp.jawNode)

        // 5. Expressive Dragon Eyes with Eyelids (Requirement 2)
        let leftEyeComp = makeFacialEye(eyeMat: eyeMat, pupilMat: pupilMat, lidMat: primaryMat, radius: 0.058, isDragonPupil: true)
        leftEyeComp.eyeNode.position = SCNVector3(-0.125, 0.08, 0.15)
        leftEyeComp.eyeNode.eulerAngles = SCNVector3(0, -Float.pi / 16, 0)
        head.addChildNode(leftEyeComp.eyeNode)

        let rightEyeComp = makeFacialEye(eyeMat: eyeMat, pupilMat: pupilMat, lidMat: primaryMat, radius: 0.058, isDragonPupil: true)
        rightEyeComp.eyeNode.position = SCNVector3(0.125, 0.08, 0.15)
        rightEyeComp.eyeNode.eulerAngles = SCNVector3(0, Float.pi / 16, 0)
        head.addChildNode(rightEyeComp.eyeNode)

        // 6. Sculpted Horns
        var hornsNode: SCNNode? = nil
        if customHorn {
            let hGroup = SCNNode()
            let hornGeo = SCNCone(topRadius: 0.018, bottomRadius: 0.065, height: 0.32)
            hornGeo.materials = [hornMat]

            let leftHorn = SCNNode(geometry: hornGeo)
            leftHorn.position = SCNVector3(-0.13, 0.21, -0.06)
            leftHorn.eulerAngles = SCNVector3(-Float.pi / 5.5, 0, -Float.pi / 5)
            hGroup.addChildNode(leftHorn)

            let rightHorn = SCNNode(geometry: hornGeo)
            rightHorn.position = SCNVector3(0.13, 0.21, -0.06)
            rightHorn.eulerAngles = SCNVector3(-Float.pi / 5.5, 0, Float.pi / 5)
            hGroup.addChildNode(rightHorn)

            head.addChildNode(hGroup)
            hornsNode = hGroup
        }

        // 7. Wings with articulated joints
        var leftWing: SCNNode? = nil
        var rightWing: SCNNode? = nil
        if customWings {
            let wingArmGeo = SCNCylinder(radius: 0.024, height: 0.44)
            wingArmGeo.materials = [primaryMat]
            let wingMembraneGeo = SCNBox(width: 0.42, height: 0.01, length: 0.26, chamferRadius: 0.02)
            wingMembraneGeo.materials = [hornMat]

            let lw = SCNNode()
            lw.position = SCNVector3(-0.24, 0.18, -0.05)
            let armL = SCNNode(geometry: wingArmGeo)
            armL.eulerAngles = SCNVector3(0, 0, Float.pi / 3)
            armL.position = SCNVector3(-0.16, 0.1, 0)
            lw.addChildNode(armL)
            let memL = SCNNode(geometry: wingMembraneGeo)
            memL.position = SCNVector3(-0.16, 0.05, -0.06)
            memL.eulerAngles = SCNVector3(Float.pi / 8, 0, Float.pi / 4)
            lw.addChildNode(memL)
            body.addChildNode(lw)
            leftWing = lw

            let rw = SCNNode()
            rw.position = SCNVector3(0.24, 0.18, -0.05)
            let armR = SCNNode(geometry: wingArmGeo)
            armR.eulerAngles = SCNVector3(0, 0, -Float.pi / 3)
            armR.position = SCNVector3(0.16, 0.1, 0)
            rw.addChildNode(armR)
            let memR = SCNNode(geometry: wingMembraneGeo)
            memR.position = SCNVector3(0.16, 0.05, -0.06)
            memR.eulerAngles = SCNVector3(Float.pi / 8, 0, -Float.pi / 4)
            rw.addChildNode(memR)
            body.addChildNode(rw)
            rightWing = rw
        }

        // 8. Multi-Segment Tail ending in Dragon Spade
        let tailRoot = SCNNode()
        tailRoot.position = SCNVector3(0, -0.15, -0.28)
        body.addChildNode(tailRoot)

        var tailSegs: [SCNNode] = []
        var prevNode = tailRoot
        for i in 0..<4 {
            let topR = CGFloat(0.08 - (Double(i) * 0.015))
            let botR = CGFloat(0.11 - (Double(i) * 0.015))
            let segGeo = SCNCone(topRadius: topR, bottomRadius: botR, height: 0.20)
            segGeo.materials = [primaryMat]
            let seg = SCNNode(geometry: segGeo)
            seg.position = SCNVector3(0, -0.06, -0.14)
            seg.eulerAngles = SCNVector3(Float.pi / 3.2, 0, 0)
            prevNode.addChildNode(seg)
            tailSegs.append(seg)
            prevNode = seg
        }

        // Tail spade tip
        let spadeGeo = SCNPyramid(width: 0.15, height: 0.24, length: 0.15)
        spadeGeo.materials = [hornMat]
        let spade = SCNNode(geometry: spadeGeo)
        spade.position = SCNVector3(0, -0.10, -0.08)
        spade.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        prevNode.addChildNode(spade)

        // 9. Articulated 4-Leg Limb Hierarchy (Requirements 5 & 7)
        let flLeg = makeArticulatedLeg(mat: primaryMat, clawMat: clawMat, upperLength: 0.15, lowerLength: 0.14, radius: 0.055, addClaws: true)
        flLeg.upperLegNode.position = SCNVector3(-0.20, -0.04, 0.16)
        body.addChildNode(flLeg.upperLegNode)

        let frLeg = makeArticulatedLeg(mat: primaryMat, clawMat: clawMat, upperLength: 0.15, lowerLength: 0.14, radius: 0.055, addClaws: true)
        frLeg.upperLegNode.position = SCNVector3(0.20, -0.04, 0.16)
        body.addChildNode(frLeg.upperLegNode)

        let blLeg = makeArticulatedLeg(mat: primaryMat, clawMat: clawMat, upperLength: 0.16, lowerLength: 0.15, radius: 0.060, addClaws: true)
        blLeg.upperLegNode.position = SCNVector3(-0.20, -0.08, -0.18)
        body.addChildNode(blLeg.upperLegNode)

        let brLeg = makeArticulatedLeg(mat: primaryMat, clawMat: clawMat, upperLength: 0.16, lowerLength: 0.15, radius: 0.060, addClaws: true)
        brLeg.upperLegNode.position = SCNVector3(0.20, -0.08, -0.18)
        body.addChildNode(brLeg.upperLegNode)

        let accNode = buildAccessory(accessory, headNode: head)

        return Pet3DRig(
            rootNode: root,
            bodyNode: body,
            neckNode: neck,
            headNode: head,
            leftEyeNode: leftEyeComp.eyeNode,
            rightEyeNode: rightEyeComp.eyeNode,
            leftPupilNode: leftEyeComp.pupilNode,
            rightPupilNode: rightEyeComp.pupilNode,
            leftUpperLid: leftEyeComp.upperLidNode,
            rightUpperLid: rightEyeComp.upperLidNode,
            leftLowerLid: leftEyeComp.lowerLidNode,
            rightLowerLid: rightEyeComp.lowerLidNode,
            jawNode: jawComp.jawNode,
            tongueNode: jawComp.tongueNode,
            upperTeethNode: upperTeeth,
            lowerTeethNode: jawComp.teethNode,
            tailNode: tailRoot,
            tailSegments: tailSegs,
            leftWingNode: leftWing,
            rightWingNode: rightWing,
            frontLeftLeg: flLeg.upperLegNode,
            frontLeftShin: flLeg.shinNode,
            frontLeftPaw: flLeg.pawNode,
            frontRightLeg: frLeg.upperLegNode,
            frontRightShin: frLeg.shinNode,
            frontRightPaw: frLeg.pawNode,
            backLeftLeg: blLeg.upperLegNode,
            backLeftShin: blLeg.shinNode,
            backLeftPaw: blLeg.pawNode,
            backRightLeg: brLeg.upperLegNode,
            backRightShin: brLeg.shinNode,
            backRightPaw: brLeg.pawNode,
            hornsNode: hornsNode,
            accessoriesNode: accNode
        )
    }

    // MARK: - 2. Cat (Mochi)
    private static func buildCat(accessory: String) -> Pet3DRig {
        let root = SCNNode()
        let body = SCNNode()
        body.position = SCNVector3(0, 0.25, 0)
        root.addChildNode(body)

        let furMat = pbrMaterial(color: NSColor(red: 0.58, green: 0.42, blue: 0.95, alpha: 1.0), roughness: 0.55)
        let innerEarMat = pbrMaterial(color: NSColor(red: 0.98, green: 0.65, blue: 0.78, alpha: 1.0), roughness: 0.6)
        let eyeMat = pbrMaterial(color: NSColor(red: 0.2, green: 0.85, blue: 0.6, alpha: 1.0), roughness: 0.1, emission: NSColor(red: 0.05, green: 0.3, blue: 0.2, alpha: 1.0))
        let pupilMat = pbrMaterial(color: NSColor.black, roughness: 0.1)
        let clawMat = pbrMaterial(color: NSColor(white: 0.95, alpha: 1.0), roughness: 0.3)

        // Torso
        let torsoGeo = SCNCapsule(capRadius: 0.23, height: 0.58)
        torsoGeo.materials = [furMat]
        let torsoNode = SCNNode(geometry: torsoGeo)
        torsoNode.eulerAngles = SCNVector3(Float.pi / 2.3, 0, 0)
        body.addChildNode(torsoNode)

        // Head
        let head = SCNNode()
        head.position = SCNVector3(0, 0.32, 0.25)
        body.addChildNode(head)

        let headGeo = SCNSphere(radius: 0.23)
        headGeo.materials = [furMat]
        head.addChildNode(SCNNode(geometry: headGeo))

        // Ears
        let earGeo = SCNCone(topRadius: 0.02, bottomRadius: 0.08, height: 0.18)
        earGeo.materials = [furMat]
        let innerEarGeo = SCNCone(topRadius: 0.01, bottomRadius: 0.055, height: 0.14)
        innerEarGeo.materials = [innerEarMat]

        let leftEar = SCNNode()
        leftEar.position = SCNVector3(-0.13, 0.22, 0.02)
        leftEar.eulerAngles = SCNVector3(-Float.pi / 12, 0, -Float.pi / 8)
        leftEar.addChildNode(SCNNode(geometry: earGeo))
        let inL = SCNNode(geometry: innerEarGeo)
        inL.position = SCNVector3(0, 0, 0.02)
        leftEar.addChildNode(inL)
        head.addChildNode(leftEar)

        let rightEar = SCNNode()
        rightEar.position = SCNVector3(0.13, 0.22, 0.02)
        rightEar.eulerAngles = SCNVector3(-Float.pi / 12, 0, Float.pi / 8)
        rightEar.addChildNode(SCNNode(geometry: earGeo))
        let inR = SCNNode(geometry: innerEarGeo)
        inR.position = SCNVector3(0, 0, 0.02)
        rightEar.addChildNode(inR)
        head.addChildNode(rightEar)

        // Articulated Jaw
        let jawComp = makeArticulatedJaw(primaryMat: furMat, length: 0.16, width: 0.13)
        jawComp.jawNode.position = SCNVector3(0, -0.08, 0.12)
        head.addChildNode(jawComp.jawNode)

        // Facial Eyes with Eyelids
        let leftEyeComp = makeFacialEye(eyeMat: eyeMat, pupilMat: pupilMat, lidMat: furMat, radius: 0.052, isDragonPupil: false)
        leftEyeComp.eyeNode.position = SCNVector3(-0.11, 0.04, 0.18)
        head.addChildNode(leftEyeComp.eyeNode)

        let rightEyeComp = makeFacialEye(eyeMat: eyeMat, pupilMat: pupilMat, lidMat: furMat, radius: 0.052, isDragonPupil: false)
        rightEyeComp.eyeNode.position = SCNVector3(0.11, 0.04, 0.18)
        head.addChildNode(rightEyeComp.eyeNode)

        // Tail
        let tailRoot = SCNNode()
        tailRoot.position = SCNVector3(0, -0.05, -0.26)
        body.addChildNode(tailRoot)

        var tailSegs: [SCNNode] = []
        var prevNode = tailRoot
        for _ in 0..<3 {
            let segGeo = SCNCylinder(radius: 0.035, height: 0.18)
            segGeo.materials = [furMat]
            let seg = SCNNode(geometry: segGeo)
            seg.position = SCNVector3(0, 0.08, -0.12)
            seg.eulerAngles = SCNVector3(Float.pi / 4, 0, 0)
            prevNode.addChildNode(seg)
            tailSegs.append(seg)
            prevNode = seg
        }

        // Articulated Legs
        let fl = makeArticulatedLeg(mat: furMat, clawMat: clawMat, upperLength: 0.13, lowerLength: 0.12, radius: 0.048, addClaws: false)
        fl.upperLegNode.position = SCNVector3(-0.16, -0.06, 0.14)
        body.addChildNode(fl.upperLegNode)

        let fr = makeArticulatedLeg(mat: furMat, clawMat: clawMat, upperLength: 0.13, lowerLength: 0.12, radius: 0.048, addClaws: false)
        fr.upperLegNode.position = SCNVector3(0.16, -0.06, 0.14)
        body.addChildNode(fr.upperLegNode)

        let bl = makeArticulatedLeg(mat: furMat, clawMat: clawMat, upperLength: 0.14, lowerLength: 0.13, radius: 0.052, addClaws: false)
        bl.upperLegNode.position = SCNVector3(-0.16, -0.08, -0.16)
        body.addChildNode(bl.upperLegNode)

        let br = makeArticulatedLeg(mat: furMat, clawMat: clawMat, upperLength: 0.14, lowerLength: 0.13, radius: 0.052, addClaws: false)
        br.upperLegNode.position = SCNVector3(0.16, -0.08, -0.16)
        body.addChildNode(br.upperLegNode)

        let accNode = buildAccessory(accessory, headNode: head)

        return Pet3DRig(
            rootNode: root,
            bodyNode: body,
            headNode: head,
            leftEyeNode: leftEyeComp.eyeNode,
            rightEyeNode: rightEyeComp.eyeNode,
            leftPupilNode: leftEyeComp.pupilNode,
            rightPupilNode: rightEyeComp.pupilNode,
            leftUpperLid: leftEyeComp.upperLidNode,
            rightUpperLid: rightEyeComp.upperLidNode,
            leftLowerLid: leftEyeComp.lowerLidNode,
            rightLowerLid: rightEyeComp.lowerLidNode,
            jawNode: jawComp.jawNode,
            tongueNode: jawComp.tongueNode,
            leftEarNode: leftEar,
            rightEarNode: rightEar,
            tailNode: tailRoot,
            tailSegments: tailSegs,
            frontLeftLeg: fl.upperLegNode,
            frontLeftShin: fl.shinNode,
            frontLeftPaw: fl.pawNode,
            frontRightLeg: fr.upperLegNode,
            frontRightShin: fr.shinNode,
            frontRightPaw: fr.pawNode,
            backLeftLeg: bl.upperLegNode,
            backLeftShin: bl.shinNode,
            backLeftPaw: bl.pawNode,
            backRightLeg: br.upperLegNode,
            backRightShin: br.shinNode,
            backRightPaw: br.pawNode,
            accessoriesNode: accNode
        )
    }

    // MARK: - 3. Fox (Kita)
    private static func buildFox(accessory: String) -> Pet3DRig {
        let root = SCNNode()
        let body = SCNNode()
        body.position = SCNVector3(0, 0.27, 0)
        root.addChildNode(body)

        let orangeMat = pbrMaterial(color: NSColor(red: 0.98, green: 0.52, blue: 0.18, alpha: 1.0), roughness: 0.45)
        let whiteMat = pbrMaterial(color: NSColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0), roughness: 0.5)
        let blackMat = pbrMaterial(color: NSColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0), roughness: 0.5)
        let eyeMat = pbrMaterial(color: NSColor(red: 0.95, green: 0.75, blue: 0.2, alpha: 1.0), roughness: 0.1)

        let torsoGeo = SCNCapsule(capRadius: 0.22, height: 0.6)
        torsoGeo.materials = [orangeMat]
        let torsoNode = SCNNode(geometry: torsoGeo)
        torsoNode.eulerAngles = SCNVector3(Float.pi / 2.3, 0, 0)
        body.addChildNode(torsoNode)

        let chestGeo = SCNSphere(radius: 0.18)
        chestGeo.materials = [whiteMat]
        let chestNode = SCNNode(geometry: chestGeo)
        chestNode.position = SCNVector3(0, 0.06, 0.16)
        body.addChildNode(chestNode)

        let head = SCNNode()
        head.position = SCNVector3(0, 0.34, 0.26)
        body.addChildNode(head)

        let headGeo = SCNSphere(radius: 0.22)
        headGeo.materials = [orangeMat]
        head.addChildNode(SCNNode(geometry: headGeo))

        let snoutGeo = SCNCone(topRadius: 0.03, bottomRadius: 0.11, height: 0.24)
        snoutGeo.materials = [whiteMat]
        let snout = SCNNode(geometry: snoutGeo)
        snout.position = SCNVector3(0, -0.04, 0.2)
        snout.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        head.addChildNode(snout)

        let noseGeo = SCNSphere(radius: 0.03)
        noseGeo.materials = [blackMat]
        let nose = SCNNode(geometry: noseGeo)
        nose.position = SCNVector3(0, -0.04, 0.32)
        head.addChildNode(nose)

        let earGeo = SCNCone(topRadius: 0.015, bottomRadius: 0.09, height: 0.25)
        earGeo.materials = [orangeMat]
        let innerEarGeo = SCNCone(topRadius: 0.01, bottomRadius: 0.06, height: 0.2)
        innerEarGeo.materials = [whiteMat]

        let leftEar = SCNNode()
        leftEar.position = SCNVector3(-0.14, 0.24, -0.02)
        leftEar.eulerAngles = SCNVector3(-Float.pi / 10, 0, -Float.pi / 6)
        leftEar.addChildNode(SCNNode(geometry: earGeo))
        let inL = SCNNode(geometry: innerEarGeo)
        inL.position = SCNVector3(0, 0, 0.02)
        leftEar.addChildNode(inL)
        head.addChildNode(leftEar)

        let rightEar = SCNNode()
        rightEar.position = SCNVector3(0.14, 0.24, -0.02)
        rightEar.eulerAngles = SCNVector3(-Float.pi / 10, 0, Float.pi / 6)
        rightEar.addChildNode(SCNNode(geometry: earGeo))
        let inR = SCNNode(geometry: innerEarGeo)
        inR.position = SCNVector3(0, 0, 0.02)
        rightEar.addChildNode(inR)
        head.addChildNode(rightEar)

        // Articulated Fox Jaw
        let jawComp = makeArticulatedJaw(primaryMat: whiteMat, length: 0.18, width: 0.11)
        jawComp.jawNode.position = SCNVector3(0, -0.07, 0.14)
        head.addChildNode(jawComp.jawNode)

        // Eyes with lids
        let leftEyeComp = makeFacialEye(eyeMat: eyeMat, pupilMat: blackMat, lidMat: orangeMat, radius: 0.052, isDragonPupil: false)
        leftEyeComp.eyeNode.position = SCNVector3(-0.11, 0.05, 0.17)
        head.addChildNode(leftEyeComp.eyeNode)

        let rightEyeComp = makeFacialEye(eyeMat: eyeMat, pupilMat: blackMat, lidMat: orangeMat, radius: 0.052, isDragonPupil: false)
        rightEyeComp.eyeNode.position = SCNVector3(0.11, 0.05, 0.17)
        head.addChildNode(rightEyeComp.eyeNode)

        let tailRoot = SCNNode()
        tailRoot.position = SCNVector3(0, -0.04, -0.28)
        body.addChildNode(tailRoot)

        let tailBodyGeo = SCNCapsule(capRadius: 0.13, height: 0.42)
        tailBodyGeo.materials = [orangeMat]
        let tailMain = SCNNode(geometry: tailBodyGeo)
        tailMain.position = SCNVector3(0, 0.14, -0.16)
        tailMain.eulerAngles = SCNVector3(Float.pi / 3, 0, 0)
        tailRoot.addChildNode(tailMain)

        let tailTipGeo = SCNCone(topRadius: 0.02, bottomRadius: 0.13, height: 0.22)
        tailTipGeo.materials = [whiteMat]
        let tailTip = SCNNode(geometry: tailTipGeo)
        tailTip.position = SCNVector3(0, 0.32, -0.26)
        tailTip.eulerAngles = SCNVector3(Float.pi / 3, 0, 0)
        tailRoot.addChildNode(tailTip)

        let fl = makeArticulatedLeg(mat: blackMat, clawMat: blackMat, upperLength: 0.14, lowerLength: 0.14, radius: 0.046, addClaws: false)
        fl.upperLegNode.position = SCNVector3(-0.16, -0.06, 0.14)
        body.addChildNode(fl.upperLegNode)

        let fr = makeArticulatedLeg(mat: blackMat, clawMat: blackMat, upperLength: 0.14, lowerLength: 0.14, radius: 0.046, addClaws: false)
        fr.upperLegNode.position = SCNVector3(0.16, -0.06, 0.14)
        body.addChildNode(fr.upperLegNode)

        let bl = makeArticulatedLeg(mat: blackMat, clawMat: blackMat, upperLength: 0.15, lowerLength: 0.14, radius: 0.050, addClaws: false)
        bl.upperLegNode.position = SCNVector3(-0.16, -0.08, -0.16)
        body.addChildNode(bl.upperLegNode)

        let br = makeArticulatedLeg(mat: blackMat, clawMat: blackMat, upperLength: 0.15, lowerLength: 0.14, radius: 0.050, addClaws: false)
        br.upperLegNode.position = SCNVector3(0.16, -0.08, -0.16)
        body.addChildNode(br.upperLegNode)

        let accNode = buildAccessory(accessory, headNode: head)

        return Pet3DRig(
            rootNode: root,
            bodyNode: body,
            headNode: head,
            leftEyeNode: leftEyeComp.eyeNode,
            rightEyeNode: rightEyeComp.eyeNode,
            leftPupilNode: leftEyeComp.pupilNode,
            rightPupilNode: rightEyeComp.pupilNode,
            leftUpperLid: leftEyeComp.upperLidNode,
            rightUpperLid: rightEyeComp.upperLidNode,
            leftLowerLid: leftEyeComp.lowerLidNode,
            rightLowerLid: rightEyeComp.lowerLidNode,
            jawNode: jawComp.jawNode,
            tongueNode: jawComp.tongueNode,
            leftEarNode: leftEar,
            rightEarNode: rightEar,
            tailNode: tailRoot,
            frontLeftLeg: fl.upperLegNode,
            frontLeftShin: fl.shinNode,
            frontLeftPaw: fl.pawNode,
            frontRightLeg: fr.upperLegNode,
            frontRightShin: fr.shinNode,
            frontRightPaw: fr.pawNode,
            backLeftLeg: bl.upperLegNode,
            backLeftShin: bl.shinNode,
            backLeftPaw: bl.pawNode,
            backRightLeg: br.upperLegNode,
            backRightShin: br.shinNode,
            backRightPaw: br.pawNode,
            accessoriesNode: accNode
        )
    }

    // MARK: - 4. Rabbit (Pochi)
    private static func buildRabbit(accessory: String) -> Pet3DRig {
        let root = SCNNode()
        let body = SCNNode()
        body.position = SCNVector3(0, 0.24, 0)
        root.addChildNode(body)

        let coatMat = pbrMaterial(color: NSColor(red: 0.96, green: 0.65, blue: 0.78, alpha: 1.0), roughness: 0.6)
        let innerPinkMat = pbrMaterial(color: NSColor(red: 1.0, green: 0.82, blue: 0.88, alpha: 1.0), roughness: 0.65)
        let darkEyeMat = pbrMaterial(color: NSColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0), roughness: 0.1)
        let pupilMat = pbrMaterial(color: NSColor.black, roughness: 0.05)

        let torsoGeo = SCNSphere(radius: 0.28)
        torsoGeo.materials = [coatMat]
        let torsoNode = SCNNode(geometry: torsoGeo)
        torsoNode.scale = SCNVector3(0.95, 1.1, 1.05)
        body.addChildNode(torsoNode)

        let head = SCNNode()
        head.position = SCNVector3(0, 0.32, 0.18)
        body.addChildNode(head)

        let headGeo = SCNSphere(radius: 0.22)
        headGeo.materials = [coatMat]
        head.addChildNode(SCNNode(geometry: headGeo))

        let noseGeo = SCNSphere(radius: 0.025)
        noseGeo.materials = [innerPinkMat]
        let nose = SCNNode(geometry: noseGeo)
        nose.position = SCNVector3(0, 0, 0.22)
        head.addChildNode(nose)

        // Articulated Rabbit Jaw
        let jawComp = makeArticulatedJaw(primaryMat: coatMat, length: 0.14, width: 0.11)
        jawComp.jawNode.position = SCNVector3(0, -0.06, 0.12)
        head.addChildNode(jawComp.jawNode)

        // Rabbit Ears
        let earGeo = SCNCapsule(capRadius: 0.045, height: 0.42)
        earGeo.materials = [coatMat]
        let inEarGeo = SCNCapsule(capRadius: 0.028, height: 0.34)
        inEarGeo.materials = [innerPinkMat]

        let leftEar = SCNNode()
        leftEar.position = SCNVector3(-0.11, 0.28, 0)
        leftEar.eulerAngles = SCNVector3(0, 0, -Float.pi / 16)
        leftEar.addChildNode(SCNNode(geometry: earGeo))
        let inL = SCNNode(geometry: inEarGeo)
        inL.position = SCNVector3(0, 0, 0.02)
        leftEar.addChildNode(inL)
        head.addChildNode(leftEar)

        let rightEar = SCNNode()
        rightEar.position = SCNVector3(0.11, 0.28, 0)
        rightEar.eulerAngles = SCNVector3(0, 0, Float.pi / 16)
        rightEar.addChildNode(SCNNode(geometry: earGeo))
        let inR = SCNNode(geometry: inEarGeo)
        inR.position = SCNVector3(0, 0, 0.02)
        rightEar.addChildNode(inR)
        head.addChildNode(rightEar)

        // Doe Eyes with Eyelids
        let leftEyeComp = makeFacialEye(eyeMat: darkEyeMat, pupilMat: pupilMat, lidMat: coatMat, radius: 0.055, isDragonPupil: false)
        leftEyeComp.eyeNode.position = SCNVector3(-0.12, 0.05, 0.16)
        head.addChildNode(leftEyeComp.eyeNode)

        let rightEyeComp = makeFacialEye(eyeMat: darkEyeMat, pupilMat: pupilMat, lidMat: coatMat, radius: 0.055, isDragonPupil: false)
        rightEyeComp.eyeNode.position = SCNVector3(0.12, 0.05, 0.16)
        head.addChildNode(rightEyeComp.eyeNode)

        // Cottontail
        let tailRoot = SCNNode()
        tailRoot.position = SCNVector3(0, -0.1, -0.28)
        let puffGeo = SCNSphere(radius: 0.08)
        puffGeo.materials = [innerPinkMat]
        tailRoot.addChildNode(SCNNode(geometry: puffGeo))
        body.addChildNode(tailRoot)

        // Hopping Legs
        let fl = makeArticulatedLeg(mat: coatMat, clawMat: coatMat, upperLength: 0.10, lowerLength: 0.10, radius: 0.042, addClaws: false)
        fl.upperLegNode.position = SCNVector3(-0.12, -0.10, 0.14)
        body.addChildNode(fl.upperLegNode)

        let fr = makeArticulatedLeg(mat: coatMat, clawMat: coatMat, upperLength: 0.10, lowerLength: 0.10, radius: 0.042, addClaws: false)
        fr.upperLegNode.position = SCNVector3(0.12, -0.10, 0.14)
        body.addChildNode(fr.upperLegNode)

        let bl = makeArticulatedLeg(mat: coatMat, clawMat: coatMat, upperLength: 0.14, lowerLength: 0.14, radius: 0.055, addClaws: false)
        bl.upperLegNode.position = SCNVector3(-0.15, -0.08, -0.12)
        body.addChildNode(bl.upperLegNode)

        let br = makeArticulatedLeg(mat: coatMat, clawMat: coatMat, upperLength: 0.14, lowerLength: 0.14, radius: 0.055, addClaws: false)
        br.upperLegNode.position = SCNVector3(0.15, -0.08, -0.12)
        body.addChildNode(br.upperLegNode)

        let accNode = buildAccessory(accessory, headNode: head)

        return Pet3DRig(
            rootNode: root,
            bodyNode: body,
            headNode: head,
            leftEyeNode: leftEyeComp.eyeNode,
            rightEyeNode: rightEyeComp.eyeNode,
            leftPupilNode: leftEyeComp.pupilNode,
            rightPupilNode: rightEyeComp.pupilNode,
            leftUpperLid: leftEyeComp.upperLidNode,
            rightUpperLid: rightEyeComp.upperLidNode,
            leftLowerLid: leftEyeComp.lowerLidNode,
            rightLowerLid: rightEyeComp.lowerLidNode,
            jawNode: jawComp.jawNode,
            tongueNode: jawComp.tongueNode,
            leftEarNode: leftEar,
            rightEarNode: rightEar,
            tailNode: tailRoot,
            frontLeftLeg: fl.upperLegNode,
            frontLeftShin: fl.shinNode,
            frontLeftPaw: fl.pawNode,
            frontRightLeg: fr.upperLegNode,
            frontRightShin: fr.shinNode,
            frontRightPaw: fr.pawNode,
            backLeftLeg: bl.upperLegNode,
            backLeftShin: bl.shinNode,
            backLeftPaw: bl.pawNode,
            backRightLeg: br.upperLegNode,
            backRightShin: br.shinNode,
            backRightPaw: br.pawNode,
            accessoriesNode: accNode
        )
    }

    // MARK: - 5. Robot (Aria)
    private static func buildRobot(accessory: String) -> Pet3DRig {
        let root = SCNNode()
        let body = SCNNode()
        body.position = SCNVector3(0, 0.28, 0)
        root.addChildNode(body)

        let chassisMat = pbrMaterial(color: NSColor(white: 0.88, alpha: 1.0), roughness: 0.25, metalness: 0.8)
        let darkMetalMat = pbrMaterial(color: NSColor(white: 0.22, alpha: 1.0), roughness: 0.35, metalness: 0.6)
        let neonBlueMat = pbrMaterial(color: NSColor.cyan, roughness: 0.1, emission: NSColor.cyan)
        let pupilMat = pbrMaterial(color: NSColor.white, roughness: 0.05, emission: NSColor.white)

        let torsoGeo = SCNBox(width: 0.36, height: 0.42, length: 0.28, chamferRadius: 0.04)
        torsoGeo.materials = [chassisMat]
        body.addChildNode(SCNNode(geometry: torsoGeo))

        let head = SCNNode()
        head.position = SCNVector3(0, 0.36, 0)
        body.addChildNode(head)

        let headGeo = SCNBox(width: 0.34, height: 0.26, length: 0.28, chamferRadius: 0.035)
        headGeo.materials = [chassisMat]
        head.addChildNode(SCNNode(geometry: headGeo))

        // Visor Screen
        let visorGeo = SCNBox(width: 0.28, height: 0.12, length: 0.02, chamferRadius: 0.01)
        visorGeo.materials = [darkMetalMat]
        let visor = SCNNode(geometry: visorGeo)
        visor.position = SCNVector3(0, 0.02, 0.14)
        head.addChildNode(visor)

        // Articulated Robotic Jaw Visor
        let jawComp = makeArticulatedJaw(primaryMat: darkMetalMat, length: 0.12, width: 0.24)
        jawComp.jawNode.position = SCNVector3(0, -0.08, 0.10)
        head.addChildNode(jawComp.jawNode)

        // Glowing Optic Eyes with Shutter Lids
        let leftEyeComp = makeFacialEye(eyeMat: neonBlueMat, pupilMat: pupilMat, lidMat: darkMetalMat, radius: 0.042, isDragonPupil: false)
        leftEyeComp.eyeNode.position = SCNVector3(-0.075, 0.02, 0.15)
        head.addChildNode(leftEyeComp.eyeNode)

        let rightEyeComp = makeFacialEye(eyeMat: neonBlueMat, pupilMat: pupilMat, lidMat: darkMetalMat, radius: 0.042, isDragonPupil: false)
        rightEyeComp.eyeNode.position = SCNVector3(0.075, 0.02, 0.15)
        head.addChildNode(rightEyeComp.eyeNode)

        // Antenna
        let antNode = SCNNode()
        let stalk = SCNNode(geometry: SCNCylinder(radius: 0.008, height: 0.14))
        stalk.geometry?.materials = [darkMetalMat]
        stalk.position = SCNVector3(0, 0.20, 0)
        antNode.addChildNode(stalk)
        let orb = SCNNode(geometry: SCNSphere(radius: 0.03))
        orb.geometry?.materials = [neonBlueMat]
        orb.position = SCNVector3(0, 0.28, 0)
        antNode.addChildNode(orb)
        head.addChildNode(antNode)

        let fl = makeArticulatedLeg(mat: chassisMat, clawMat: darkMetalMat, upperLength: 0.15, lowerLength: 0.14, radius: 0.044, addClaws: false)
        fl.upperLegNode.position = SCNVector3(-0.11, -0.22, 0)
        body.addChildNode(fl.upperLegNode)

        let fr = makeArticulatedLeg(mat: chassisMat, clawMat: darkMetalMat, upperLength: 0.15, lowerLength: 0.14, radius: 0.044, addClaws: false)
        fr.upperLegNode.position = SCNVector3(0.11, -0.22, 0)
        body.addChildNode(fr.upperLegNode)

        let accNode = buildAccessory(accessory, headNode: head)

        return Pet3DRig(
            rootNode: root,
            bodyNode: body,
            headNode: head,
            leftEyeNode: leftEyeComp.eyeNode,
            rightEyeNode: rightEyeComp.eyeNode,
            leftPupilNode: leftEyeComp.pupilNode,
            rightPupilNode: rightEyeComp.pupilNode,
            leftUpperLid: leftEyeComp.upperLidNode,
            rightUpperLid: rightEyeComp.upperLidNode,
            leftLowerLid: leftEyeComp.lowerLidNode,
            rightLowerLid: rightEyeComp.lowerLidNode,
            jawNode: jawComp.jawNode,
            tongueNode: jawComp.tongueNode,
            frontLeftLeg: fl.upperLegNode,
            frontLeftShin: fl.shinNode,
            frontLeftPaw: fl.pawNode,
            frontRightLeg: fr.upperLegNode,
            frontRightShin: fr.shinNode,
            frontRightPaw: fr.pawNode,
            accessoriesNode: accNode
        )
    }

    // MARK: - 6. RobotCat (Neo)
    private static func buildRobotCat(accessory: String) -> Pet3DRig {
        let root = SCNNode()
        let body = SCNNode()
        body.position = SCNVector3(0, 0.27, 0)
        root.addChildNode(body)

        let metalMat = pbrMaterial(color: NSColor(white: 0.28, alpha: 1.0), roughness: 0.3, metalness: 0.75)
        let goldMat = pbrMaterial(color: NSColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0), roughness: 0.2, metalness: 0.9)
        let neonGreen = pbrMaterial(color: NSColor.green, roughness: 0.1, emission: NSColor.green)
        let pupilMat = pbrMaterial(color: NSColor.black, roughness: 0.05)

        let torsoGeo = SCNCapsule(capRadius: 0.21, height: 0.54)
        torsoGeo.materials = [metalMat]
        let torsoNode = SCNNode(geometry: torsoGeo)
        torsoNode.eulerAngles = SCNVector3(Float.pi / 2.3, 0, 0)
        body.addChildNode(torsoNode)

        let head = SCNNode()
        head.position = SCNVector3(0, 0.32, 0.24)
        body.addChildNode(head)

        let headGeo = SCNSphere(radius: 0.21)
        headGeo.materials = [metalMat]
        head.addChildNode(SCNNode(geometry: headGeo))

        let earGeo = SCNPyramid(width: 0.11, height: 0.18, length: 0.08)
        earGeo.materials = [goldMat]
        let leftEar = SCNNode(geometry: earGeo)
        leftEar.position = SCNVector3(-0.11, 0.18, 0)
        leftEar.eulerAngles = SCNVector3(0, 0, -Float.pi / 6)
        head.addChildNode(leftEar)

        let rightEar = SCNNode(geometry: earGeo)
        rightEar.position = SCNVector3(0.11, 0.18, 0)
        rightEar.eulerAngles = SCNVector3(0, 0, Float.pi / 6)
        head.addChildNode(rightEar)

        // Articulated Cyber Jaw
        let jawComp = makeArticulatedJaw(primaryMat: metalMat, length: 0.15, width: 0.12)
        jawComp.jawNode.position = SCNVector3(0, -0.07, 0.11)
        head.addChildNode(jawComp.jawNode)

        // Optics with Electronic Eyelids
        let leftEyeComp = makeFacialEye(eyeMat: neonGreen, pupilMat: pupilMat, lidMat: metalMat, radius: 0.048, isDragonPupil: false)
        leftEyeComp.eyeNode.position = SCNVector3(-0.09, 0.04, 0.17)
        head.addChildNode(leftEyeComp.eyeNode)

        let rightEyeComp = makeFacialEye(eyeMat: neonGreen, pupilMat: pupilMat, lidMat: metalMat, radius: 0.048, isDragonPupil: false)
        rightEyeComp.eyeNode.position = SCNVector3(0.09, 0.04, 0.17)
        head.addChildNode(rightEyeComp.eyeNode)

        let tailRoot = SCNNode()
        tailRoot.position = SCNVector3(0, -0.05, -0.26)
        body.addChildNode(tailRoot)
        let tailGeo = SCNCylinder(radius: 0.02, height: 0.32)
        tailGeo.materials = [goldMat]
        let tail = SCNNode(geometry: tailGeo)
        tail.position = SCNVector3(0, 0.14, -0.12)
        tail.eulerAngles = SCNVector3(Float.pi / 3, 0, 0)
        tailRoot.addChildNode(tail)

        let fl = makeArticulatedLeg(mat: metalMat, clawMat: goldMat, upperLength: 0.14, lowerLength: 0.13, radius: 0.044, addClaws: true)
        fl.upperLegNode.position = SCNVector3(-0.15, -0.06, 0.13)
        body.addChildNode(fl.upperLegNode)

        let fr = makeArticulatedLeg(mat: metalMat, clawMat: goldMat, upperLength: 0.14, lowerLength: 0.13, radius: 0.044, addClaws: true)
        fr.upperLegNode.position = SCNVector3(0.15, -0.06, 0.13)
        body.addChildNode(fr.upperLegNode)

        let bl = makeArticulatedLeg(mat: metalMat, clawMat: goldMat, upperLength: 0.14, lowerLength: 0.14, radius: 0.048, addClaws: true)
        bl.upperLegNode.position = SCNVector3(-0.15, -0.08, -0.15)
        body.addChildNode(bl.upperLegNode)

        let br = makeArticulatedLeg(mat: metalMat, clawMat: goldMat, upperLength: 0.14, lowerLength: 0.14, radius: 0.048, addClaws: true)
        br.upperLegNode.position = SCNVector3(0.15, -0.08, -0.15)
        body.addChildNode(br.upperLegNode)

        let accNode = buildAccessory(accessory, headNode: head)

        return Pet3DRig(
            rootNode: root,
            bodyNode: body,
            headNode: head,
            leftEyeNode: leftEyeComp.eyeNode,
            rightEyeNode: rightEyeComp.eyeNode,
            leftPupilNode: leftEyeComp.pupilNode,
            rightPupilNode: rightEyeComp.pupilNode,
            leftUpperLid: leftEyeComp.upperLidNode,
            rightUpperLid: rightEyeComp.upperLidNode,
            leftLowerLid: leftEyeComp.lowerLidNode,
            rightLowerLid: rightEyeComp.lowerLidNode,
            jawNode: jawComp.jawNode,
            tongueNode: jawComp.tongueNode,
            leftEarNode: leftEar,
            rightEarNode: rightEar,
            tailNode: tailRoot,
            frontLeftLeg: fl.upperLegNode,
            frontLeftShin: fl.shinNode,
            frontLeftPaw: fl.pawNode,
            frontRightLeg: fr.upperLegNode,
            frontRightShin: fr.shinNode,
            frontRightPaw: fr.pawNode,
            backLeftLeg: bl.upperLegNode,
            backLeftShin: bl.shinNode,
            backLeftPaw: bl.pawNode,
            backRightLeg: br.upperLegNode,
            backRightShin: br.shinNode,
            backRightPaw: br.pawNode,
            accessoriesNode: accNode
        )
    }

    // MARK: - 7. Ghost (Boo)
    private static func buildGhost(accessory: String) -> Pet3DRig {
        let root = SCNNode()
        let body = SCNNode()
        body.position = SCNVector3(0, 0.32, 0)
        root.addChildNode(body)

        let ghostMat = SCNMaterial()
        ghostMat.lightingModel = .physicallyBased
        ghostMat.diffuse.contents = NSColor(white: 0.98, alpha: 0.92)
        ghostMat.roughness.contents = 0.25
        ghostMat.metalness.contents = 0.05
        ghostMat.emission.contents = NSColor(red: 0.2, green: 0.35, blue: 0.8, alpha: 0.35)

        let darkMat = pbrMaterial(color: NSColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1.0), roughness: 0.1)
        let pupilMat = pbrMaterial(color: NSColor.white, roughness: 0.05, emission: NSColor.white)

        let domeGeo = SCNSphere(radius: 0.28)
        domeGeo.materials = [ghostMat]
        let domeNode = SCNNode(geometry: domeGeo)
        body.addChildNode(domeNode)

        let skirtGeo = SCNCone(topRadius: 0.28, bottomRadius: 0.34, height: 0.36)
        skirtGeo.materials = [ghostMat]
        let skirtNode = SCNNode(geometry: skirtGeo)
        skirtNode.position = SCNVector3(0, -0.22, 0)
        body.addChildNode(skirtNode)

        // Spectral Openable Mouth
        let jawComp = makeArticulatedJaw(primaryMat: darkMat, length: 0.10, width: 0.10)
        jawComp.jawNode.position = SCNVector3(0, -0.08, 0.22)
        domeNode.addChildNode(jawComp.jawNode)

        // Expressive Ghost Eyes with Eyelids
        let leftEyeComp = makeFacialEye(eyeMat: darkMat, pupilMat: pupilMat, lidMat: ghostMat, radius: 0.048, isDragonPupil: false)
        leftEyeComp.eyeNode.position = SCNVector3(-0.09, 0.04, 0.25)
        domeNode.addChildNode(leftEyeComp.eyeNode)

        let rightEyeComp = makeFacialEye(eyeMat: darkMat, pupilMat: pupilMat, lidMat: ghostMat, radius: 0.048, isDragonPupil: false)
        rightEyeComp.eyeNode.position = SCNVector3(0.09, 0.04, 0.25)
        domeNode.addChildNode(rightEyeComp.eyeNode)

        // Spectral Waving Arm Flippers
        let armGeo = SCNCone(topRadius: 0.02, bottomRadius: 0.06, height: 0.22)
        armGeo.materials = [ghostMat]

        let leftArm = SCNNode(geometry: armGeo)
        leftArm.position = SCNVector3(-0.25, -0.06, 0.08)
        leftArm.eulerAngles = SCNVector3(0, 0, Float.pi / 2.5)
        body.addChildNode(leftArm)

        let rightArm = SCNNode(geometry: armGeo)
        rightArm.position = SCNVector3(0.25, -0.06, 0.08)
        rightArm.eulerAngles = SCNVector3(0, 0, -Float.pi / 2.5)
        body.addChildNode(rightArm)

        let accNode = buildAccessory(accessory, headNode: domeNode)

        return Pet3DRig(
            rootNode: root,
            bodyNode: body,
            headNode: domeNode,
            leftEyeNode: leftEyeComp.eyeNode,
            rightEyeNode: rightEyeComp.eyeNode,
            leftPupilNode: leftEyeComp.pupilNode,
            rightPupilNode: rightEyeComp.pupilNode,
            leftUpperLid: leftEyeComp.upperLidNode,
            rightUpperLid: rightEyeComp.upperLidNode,
            leftLowerLid: leftEyeComp.lowerLidNode,
            rightLowerLid: rightEyeComp.lowerLidNode,
            jawNode: jawComp.jawNode,
            tongueNode: jawComp.tongueNode,
            frontLeftLeg: leftArm,
            frontRightLeg: rightArm,
            accessoriesNode: accNode
        )
    }

    // MARK: - Accessories Builder
    private static func buildAccessory(_ accessory: String, headNode: SCNNode) -> SCNNode? {
        guard accessory != "none" else { return nil }
        let accNode = SCNNode()

        switch accessory {
        case "glasses":
            let frameMat = pbrMaterial(color: NSColor.black, roughness: 0.3)
            let glassMat = pbrMaterial(color: NSColor.cyan.withAlphaComponent(0.6), roughness: 0.1)
            let leftRim = SCNNode(geometry: SCNTorus(ringRadius: 0.065, pipeRadius: 0.008))
            leftRim.geometry?.materials = [frameMat]
            leftRim.position = SCNVector3(-0.11, 0.05, 0.22)
            leftRim.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
            accNode.addChildNode(leftRim)

            let leftLens = SCNNode(geometry: SCNCylinder(radius: 0.06, height: 0.004))
            leftLens.geometry?.materials = [glassMat]
            leftLens.position = SCNVector3(-0.11, 0.05, 0.22)
            leftLens.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
            accNode.addChildNode(leftLens)

            let rightRim = SCNNode(geometry: SCNTorus(ringRadius: 0.065, pipeRadius: 0.008))
            rightRim.geometry?.materials = [frameMat]
            rightRim.position = SCNVector3(0.11, 0.05, 0.22)
            rightRim.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
            accNode.addChildNode(rightRim)

            let rightLens = SCNNode(geometry: SCNCylinder(radius: 0.06, height: 0.004))
            rightLens.geometry?.materials = [glassMat]
            rightLens.position = SCNVector3(0.11, 0.05, 0.22)
            rightLens.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
            accNode.addChildNode(rightLens)

            let bridge = SCNNode(geometry: SCNCylinder(radius: 0.008, height: 0.08))
            bridge.geometry?.materials = [frameMat]
            bridge.position = SCNVector3(0, 0.05, 0.22)
            bridge.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            accNode.addChildNode(bridge)

        case "hat":
            let hatMat = pbrMaterial(color: NSColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 1.0), roughness: 0.4)
            let ribbonMat = pbrMaterial(color: NSColor.red, roughness: 0.3)
            let brim = SCNNode(geometry: SCNCylinder(radius: 0.26, height: 0.02))
            brim.geometry?.materials = [hatMat]
            brim.position = SCNVector3(0, 0.22, 0)
            accNode.addChildNode(brim)

            let crown = SCNNode(geometry: SCNCylinder(radius: 0.16, height: 0.2))
            crown.geometry?.materials = [hatMat]
            crown.position = SCNVector3(0, 0.32, 0)
            accNode.addChildNode(crown)

            let rib = SCNNode(geometry: SCNCylinder(radius: 0.165, height: 0.04))
            rib.geometry?.materials = [ribbonMat]
            rib.position = SCNVector3(0, 0.25, 0)
            accNode.addChildNode(rib)

        case "bowtie":
            let bowMat = pbrMaterial(color: NSColor.red, roughness: 0.3)
            let knot = SCNNode(geometry: SCNSphere(radius: 0.035))
            knot.geometry?.materials = [bowMat]
            knot.position = SCNVector3(0, -0.22, 0.24)
            accNode.addChildNode(knot)

            let leftWing = SCNNode(geometry: SCNCone(topRadius: 0.01, bottomRadius: 0.06, height: 0.09))
            leftWing.geometry?.materials = [bowMat]
            leftWing.position = SCNVector3(-0.06, -0.22, 0.24)
            leftWing.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            accNode.addChildNode(leftWing)

            let rightWing = SCNNode(geometry: SCNCone(topRadius: 0.01, bottomRadius: 0.06, height: 0.09))
            rightWing.geometry?.materials = [bowMat]
            rightWing.position = SCNVector3(0.06, -0.22, 0.24)
            rightWing.eulerAngles = SCNVector3(0, 0, -Float.pi / 2)
            accNode.addChildNode(rightWing)

        case "crown":
            let goldMat = pbrMaterial(color: NSColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0), roughness: 0.2, metalness: 0.8)
            let base = SCNNode(geometry: SCNCylinder(radius: 0.14, height: 0.04))
            base.geometry?.materials = [goldMat]
            base.position = SCNVector3(0, 0.24, 0)
            accNode.addChildNode(base)

            for i in 0..<5 {
                let angle = Float(i) * (2 * Float.pi / 5)
                let point = SCNNode(geometry: SCNPyramid(width: 0.05, height: 0.09, length: 0.05))
                point.geometry?.materials = [goldMat]
                point.position = SCNVector3(sin(angle) * 0.12, 0.28, cos(angle) * 0.12)
                accNode.addChildNode(point)
            }

        default:
            break
        }

        headNode.addChildNode(accNode)
        return accNode
    }
}
