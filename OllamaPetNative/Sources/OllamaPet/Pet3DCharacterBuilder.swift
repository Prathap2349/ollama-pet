import Foundation
import SceneKit
import AppKit

// MARK: - 3D Rig Structure Representing Character Anatomy

public struct Pet3DRig {
    public let rootNode: SCNNode
    public let bodyNode: SCNNode
    public let headNode: SCNNode
    public let leftEyeNode: SCNNode?
    public let rightEyeNode: SCNNode?
    public let leftEarNode: SCNNode?
    public let rightEarNode: SCNNode?
    public let tailNode: SCNNode?
    public let tailSegments: [SCNNode]
    public let leftWingNode: SCNNode?
    public let rightWingNode: SCNNode?
    public let frontLeftLeg: SCNNode?
    public let frontRightLeg: SCNNode?
    public let backLeftLeg: SCNNode?
    public let backRightLeg: SCNNode?
    public let hornsNode: SCNNode?
    public let accessoriesNode: SCNNode?

    public init(
        rootNode: SCNNode,
        bodyNode: SCNNode,
        headNode: SCNNode,
        leftEyeNode: SCNNode? = nil,
        rightEyeNode: SCNNode? = nil,
        leftEarNode: SCNNode? = nil,
        rightEarNode: SCNNode? = nil,
        tailNode: SCNNode? = nil,
        tailSegments: [SCNNode] = [],
        leftWingNode: SCNNode? = nil,
        rightWingNode: SCNNode? = nil,
        frontLeftLeg: SCNNode? = nil,
        frontRightLeg: SCNNode? = nil,
        backLeftLeg: SCNNode? = nil,
        backRightLeg: SCNNode? = nil,
        hornsNode: SCNNode? = nil,
        accessoriesNode: SCNNode? = nil
    ) {
        self.rootNode = rootNode
        self.bodyNode = bodyNode
        self.headNode = headNode
        self.leftEyeNode = leftEyeNode
        self.rightEyeNode = rightEyeNode
        self.leftEarNode = leftEarNode
        self.rightEarNode = rightEarNode
        self.tailNode = tailNode
        self.tailSegments = tailSegments
        self.leftWingNode = leftWingNode
        self.rightWingNode = rightWingNode
        self.frontLeftLeg = frontLeftLeg
        self.frontRightLeg = frontRightLeg
        self.backLeftLeg = backLeftLeg
        self.backRightLeg = backRightLeg
        self.hornsNode = hornsNode
        self.accessoriesNode = accessoriesNode
    }
}

// MARK: - Procedural 3D Character Builder

public class Pet3DCharacterBuilder {

    // MARK: - Material Factory
    public static func pbrMaterial(
        color: NSColor,
        roughness: CGFloat = 0.45,
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

    // MARK: - 1. Dragon (Ember)
    private static func buildDragon(customHorn: Bool, customWings: Bool, accessory: String) -> Pet3DRig {
        let root = SCNNode()
        let body = SCNNode()
        body.position = SCNVector3(0, 0.28, 0)
        root.addChildNode(body)

        let primaryMat = pbrMaterial(color: NSColor(red: 0.95, green: 0.32, blue: 0.12, alpha: 1.0), roughness: 0.35, metalness: 0.1)
        let bellyMat = pbrMaterial(color: NSColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1.0), roughness: 0.5)
        let hornMat = pbrMaterial(color: NSColor(red: 1.0, green: 0.65, blue: 0.1, alpha: 1.0), roughness: 0.2, metalness: 0.3, emission: NSColor(red: 0.8, green: 0.4, blue: 0.05, alpha: 1.0))
        let eyeMat = pbrMaterial(color: NSColor(red: 1.0, green: 0.9, blue: 0.1, alpha: 1.0), roughness: 0.1, metalness: 0.0, emission: NSColor(red: 0.7, green: 0.5, blue: 0.0, alpha: 1.0))
        let pupilMat = pbrMaterial(color: NSColor.black, roughness: 0.1)

        // Torso
        let torsoGeo = SCNCapsule(capRadius: 0.28, height: 0.65)
        torsoGeo.materials = [primaryMat]
        let torsoNode = SCNNode(geometry: torsoGeo)
        torsoNode.eulerAngles = SCNVector3(Float.pi / 2.5, 0, 0)
        body.addChildNode(torsoNode)

        // Belly Plate
        let bellyGeo = SCNCapsule(capRadius: 0.22, height: 0.5)
        bellyGeo.materials = [bellyMat]
        let bellyNode = SCNNode(geometry: bellyGeo)
        bellyNode.position = SCNVector3(0, -0.06, 0.12)
        bellyNode.eulerAngles = SCNVector3(Float.pi / 2.5, 0, 0)
        body.addChildNode(bellyNode)

        // Head Node
        let head = SCNNode()
        head.position = SCNVector3(0, 0.38, 0.28)
        body.addChildNode(head)

        let headGeo = SCNSphere(radius: 0.24)
        headGeo.materials = [primaryMat]
        head.addChildNode(SCNNode(geometry: headGeo))

        // Snout
        let snoutGeo = SCNCapsule(capRadius: 0.12, height: 0.3)
        snoutGeo.materials = [primaryMat]
        let snout = SCNNode(geometry: snoutGeo)
        snout.position = SCNVector3(0, -0.04, 0.18)
        snout.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        head.addChildNode(snout)

        // Horns
        var hornsNode: SCNNode? = nil
        if customHorn {
            let hGroup = SCNNode()
            let hornGeo = SCNCone(topRadius: 0.02, bottomRadius: 0.07, height: 0.32)
            hornGeo.materials = [hornMat]

            let leftHorn = SCNNode(geometry: hornGeo)
            leftHorn.position = SCNVector3(-0.14, 0.22, -0.08)
            leftHorn.eulerAngles = SCNVector3(-Float.pi / 6, 0, -Float.pi / 5)
            hGroup.addChildNode(leftHorn)

            let rightHorn = SCNNode(geometry: hornGeo)
            rightHorn.position = SCNVector3(0.14, 0.22, -0.08)
            rightHorn.eulerAngles = SCNVector3(-Float.pi / 6, 0, Float.pi / 5)
            hGroup.addChildNode(rightHorn)

            head.addChildNode(hGroup)
            hornsNode = hGroup
        }

        // Eyes
        let leftEye = SCNNode()
        leftEye.position = SCNVector3(-0.13, 0.08, 0.16)
        let eyeScleraGeo = SCNSphere(radius: 0.06)
        eyeScleraGeo.materials = [eyeMat]
        let eyeScleraNode = SCNNode(geometry: eyeScleraGeo)
        leftEye.addChildNode(eyeScleraNode)
        let pupilGeo = SCNSphere(radius: 0.035)
        pupilGeo.materials = [pupilMat]
        let pupilNode = SCNNode(geometry: pupilGeo)
        pupilNode.position = SCNVector3(0, 0, 0.04)
        pupilNode.scale = SCNVector3(0.4, 1.2, 0.5)
        leftEye.addChildNode(pupilNode)
        head.addChildNode(leftEye)

        let rightEye = SCNNode()
        rightEye.position = SCNVector3(0.13, 0.08, 0.16)
        let rightEyeSclera = SCNNode(geometry: eyeScleraGeo)
        rightEye.addChildNode(rightEyeSclera)
        let rightPupil = SCNNode(geometry: pupilGeo)
        rightPupil.position = SCNVector3(0, 0, 0.04)
        rightPupil.scale = SCNVector3(0.4, 1.2, 0.5)
        rightEye.addChildNode(rightPupil)
        head.addChildNode(rightEye)

        // Wings
        var leftWing: SCNNode? = nil
        var rightWing: SCNNode? = nil
        if customWings {
            let wingArmGeo = SCNCylinder(radius: 0.025, height: 0.42)
            wingArmGeo.materials = [primaryMat]
            let wingMembraneGeo = SCNBox(width: 0.4, height: 0.01, length: 0.25, chamferRadius: 0.02)
            wingMembraneGeo.materials = [hornMat]

            let lw = SCNNode()
            lw.position = SCNVector3(-0.25, 0.18, -0.05)
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
            rw.position = SCNVector3(0.25, 0.18, -0.05)
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

        // Tail
        let tailRoot = SCNNode()
        tailRoot.position = SCNVector3(0, -0.15, -0.28)
        body.addChildNode(tailRoot)

        var tailSegs: [SCNNode] = []
        var prevNode = tailRoot
        for i in 0..<3 {
            let segGeo = SCNCone(topRadius: CGFloat(0.08 - (Double(i) * 0.02)), bottomRadius: CGFloat(0.12 - (Double(i) * 0.02)), height: 0.24)
            segGeo.materials = [primaryMat]
            let seg = SCNNode(geometry: segGeo)
            seg.position = SCNVector3(0, -0.08, -0.16)
            seg.eulerAngles = SCNVector3(Float.pi / 3, 0, 0)
            prevNode.addChildNode(seg)
            tailSegs.append(seg)
            prevNode = seg
        }
        // Tail spade tip
        let spadeGeo = SCNPyramid(width: 0.14, height: 0.22, length: 0.14)
        spadeGeo.materials = [hornMat]
        let spade = SCNNode(geometry: spadeGeo)
        spade.position = SCNVector3(0, -0.12, -0.08)
        spade.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        prevNode.addChildNode(spade)

        // 4 Legs
        let legGeo = SCNCapsule(capRadius: 0.065, height: 0.28)
        legGeo.materials = [primaryMat]
        let footGeo = SCNBox(width: 0.11, height: 0.05, length: 0.15, chamferRadius: 0.02)
        footGeo.materials = [primaryMat]

        func makeLeg(x: Float, y: Float, z: Float) -> SCNNode {
            let leg = SCNNode()
            leg.position = SCNVector3(x, y, z)
            let upper = SCNNode(geometry: legGeo)
            upper.position = SCNVector3(0, -0.12, 0)
            leg.addChildNode(upper)
            let foot = SCNNode(geometry: footGeo)
            foot.position = SCNVector3(0, -0.24, 0.04)
            leg.addChildNode(foot)
            body.addChildNode(leg)
            return leg
        }

        let fl = makeLeg(x: -0.22, y: -0.08, z: 0.16)
        let fr = makeLeg(x: 0.22, y: -0.08, z: 0.16)
        let bl = makeLeg(x: -0.22, y: -0.14, z: -0.18)
        let br = makeLeg(x: 0.22, y: -0.14, z: -0.18)

        // Accessory
        let accNode = buildAccessory(accessory, headNode: head)

        return Pet3DRig(
            rootNode: root,
            bodyNode: body,
            headNode: head,
            leftEyeNode: leftEye,
            rightEyeNode: rightEye,
            tailNode: tailRoot,
            tailSegments: tailSegs,
            leftWingNode: leftWing,
            rightWingNode: rightWing,
            frontLeftLeg: fl,
            frontRightLeg: fr,
            backLeftLeg: bl,
            backRightLeg: br,
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

        // Body
        let torsoGeo = SCNCapsule(capRadius: 0.24, height: 0.58)
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

        // Eyes
        let leftEye = makeRoundEye(eyeMat: eyeMat, pupilMat: pupilMat)
        leftEye.position = SCNVector3(-0.11, 0.04, 0.18)
        head.addChildNode(leftEye)

        let rightEye = makeRoundEye(eyeMat: eyeMat, pupilMat: pupilMat)
        rightEye.position = SCNVector3(0.11, 0.04, 0.18)
        head.addChildNode(rightEye)

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

        // 4 Legs
        let legGeo = SCNCapsule(capRadius: 0.055, height: 0.24)
        legGeo.materials = [furMat]
        func makeLeg(x: Float, y: Float, z: Float) -> SCNNode {
            let leg = SCNNode()
            leg.position = SCNVector3(x, y, z)
            let cylinder = SCNNode(geometry: legGeo)
            cylinder.position = SCNVector3(0, -0.1, 0)
            leg.addChildNode(cylinder)
            body.addChildNode(leg)
            return leg
        }

        let fl = makeLeg(x: -0.16, y: -0.06, z: 0.14)
        let fr = makeLeg(x: 0.16, y: -0.06, z: 0.14)
        let bl = makeLeg(x: -0.16, y: -0.08, z: -0.16)
        let br = makeLeg(x: 0.16, y: -0.08, z: -0.16)

        let accNode = buildAccessory(accessory, headNode: head)

        return Pet3DRig(
            rootNode: root,
            bodyNode: body,
            headNode: head,
            leftEyeNode: leftEye,
            rightEyeNode: rightEye,
            leftEarNode: leftEar,
            rightEarNode: rightEar,
            tailNode: tailRoot,
            tailSegments: tailSegs,
            frontLeftLeg: fl,
            frontRightLeg: fr,
            backLeftLeg: bl,
            backRightLeg: br,
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

        // Body
        let torsoGeo = SCNCapsule(capRadius: 0.22, height: 0.6)
        torsoGeo.materials = [orangeMat]
        let torsoNode = SCNNode(geometry: torsoGeo)
        torsoNode.eulerAngles = SCNVector3(Float.pi / 2.3, 0, 0)
        body.addChildNode(torsoNode)

        // White chest fluff
        let chestGeo = SCNSphere(radius: 0.18)
        chestGeo.materials = [whiteMat]
        let chestNode = SCNNode(geometry: chestGeo)
        chestNode.position = SCNVector3(0, 0.06, 0.16)
        body.addChildNode(chestNode)

        // Head
        let head = SCNNode()
        head.position = SCNVector3(0, 0.34, 0.26)
        body.addChildNode(head)

        let headGeo = SCNSphere(radius: 0.22)
        headGeo.materials = [orangeMat]
        head.addChildNode(SCNNode(geometry: headGeo))

        // Pointed Muzzle
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

        // Large Fox Ears
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

        // Eyes
        let leftEye = makeRoundEye(eyeMat: eyeMat, pupilMat: blackMat)
        leftEye.position = SCNVector3(-0.11, 0.05, 0.17)
        head.addChildNode(leftEye)

        let rightEye = makeRoundEye(eyeMat: eyeMat, pupilMat: blackMat)
        rightEye.position = SCNVector3(0.11, 0.05, 0.17)
        head.addChildNode(rightEye)

        // Massive Bushy Tail with White Tip
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

        // 4 Legs with Black Socks
        let legGeo = SCNCapsule(capRadius: 0.05, height: 0.28)
        legGeo.materials = [blackMat]
        func makeLeg(x: Float, y: Float, z: Float) -> SCNNode {
            let leg = SCNNode()
            leg.position = SCNVector3(x, y, z)
            let cylinder = SCNNode(geometry: legGeo)
            cylinder.position = SCNVector3(0, -0.12, 0)
            leg.addChildNode(cylinder)
            body.addChildNode(leg)
            return leg
        }

        let fl = makeLeg(x: -0.16, y: -0.06, z: 0.14)
        let fr = makeLeg(x: 0.16, y: -0.06, z: 0.14)
        let bl = makeLeg(x: -0.16, y: -0.08, z: -0.16)
        let br = makeLeg(x: 0.16, y: -0.08, z: -0.16)

        let accNode = buildAccessory(accessory, headNode: head)

        return Pet3DRig(
            rootNode: root,
            bodyNode: body,
            headNode: head,
            leftEyeNode: leftEye,
            rightEyeNode: rightEye,
            leftEarNode: leftEar,
            rightEarNode: rightEar,
            tailNode: tailRoot,
            frontLeftLeg: fl,
            frontRightLeg: fr,
            backLeftLeg: bl,
            backRightLeg: br,
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

        // Plump Teardrop Body
        let torsoGeo = SCNSphere(radius: 0.28)
        torsoGeo.materials = [coatMat]
        let torsoNode = SCNNode(geometry: torsoGeo)
        torsoNode.scale = SCNVector3(0.95, 1.1, 1.05)
        body.addChildNode(torsoNode)

        // Head
        let head = SCNNode()
        head.position = SCNVector3(0, 0.32, 0.18)
        body.addChildNode(head)

        let headGeo = SCNSphere(radius: 0.22)
        headGeo.materials = [coatMat]
        head.addChildNode(SCNNode(geometry: headGeo))

        // Nose
        let noseGeo = SCNSphere(radius: 0.025)
        noseGeo.materials = [innerPinkMat]
        let nose = SCNNode(geometry: noseGeo)
        nose.position = SCNVector3(0, 0, 0.22)
        head.addChildNode(nose)

        // Long Tall Rabbit Ears
        let earGeo = SCNCapsule(capRadius: 0.045, height: 0.42)
        earGeo.materials = [coatMat]
        let innerEarGeo = SCNCapsule(capRadius: 0.03, height: 0.34)
        innerEarGeo.materials = [innerPinkMat]

        let leftEar = SCNNode()
        leftEar.position = SCNVector3(-0.11, 0.28, 0.0)
        leftEar.eulerAngles = SCNVector3(0, 0, -Float.pi / 16)
        leftEar.addChildNode(SCNNode(geometry: earGeo))
        let inL = SCNNode(geometry: innerEarGeo)
        inL.position = SCNVector3(0, 0, 0.02)
        leftEar.addChildNode(inL)
        head.addChildNode(leftEar)

        let rightEar = SCNNode()
        rightEar.position = SCNVector3(0.11, 0.28, 0.0)
        rightEar.eulerAngles = SCNVector3(0, 0, Float.pi / 16)
        rightEar.addChildNode(SCNNode(geometry: earGeo))
        let inR = SCNNode(geometry: innerEarGeo)
        inR.position = SCNVector3(0, 0, 0.02)
        rightEar.addChildNode(inR)
        head.addChildNode(rightEar)

        // Eyes
        let leftEye = SCNNode(geometry: SCNSphere(radius: 0.045))
        leftEye.geometry?.materials = [darkEyeMat]
        leftEye.position = SCNVector3(-0.12, 0.04, 0.16)
        head.addChildNode(leftEye)

        let rightEye = SCNNode(geometry: SCNSphere(radius: 0.045))
        rightEye.geometry?.materials = [darkEyeMat]
        rightEye.position = SCNVector3(0.12, 0.04, 0.16)
        head.addChildNode(rightEye)

        // Fluffy Cotton Puff Tail
        let tailRoot = SCNNode(geometry: SCNSphere(radius: 0.08))
        tailRoot.geometry?.materials = [pbrMaterial(color: .white, roughness: 0.8)]
        tailRoot.position = SCNVector3(0, -0.06, -0.28)
        body.addChildNode(tailRoot)

        // Hopping Feet
        let frontPawGeo = SCNCapsule(capRadius: 0.045, height: 0.16)
        frontPawGeo.materials = [coatMat]
        let hindFootGeo = SCNCapsule(capRadius: 0.06, height: 0.28)
        hindFootGeo.materials = [coatMat]

        func makePaw(x: Float, y: Float, z: Float, geo: SCNGeometry, angleX: Float = 0) -> SCNNode {
            let n = SCNNode()
            n.position = SCNVector3(x, y, z)
            let geomNode = SCNNode(geometry: geo)
            geomNode.eulerAngles = SCNVector3(angleX, 0, 0)
            n.addChildNode(geomNode)
            body.addChildNode(n)
            return n
        }

        let fl = makePaw(x: -0.12, y: -0.18, z: 0.12, geo: frontPawGeo)
        let fr = makePaw(x: 0.12, y: -0.18, z: 0.12, geo: frontPawGeo)
        let bl = makePaw(x: -0.18, y: -0.16, z: -0.1, geo: hindFootGeo, angleX: Float.pi / 2.5)
        let br = makePaw(x: 0.18, y: -0.16, z: -0.1, geo: hindFootGeo, angleX: Float.pi / 2.5)

        let accNode = buildAccessory(accessory, headNode: head)

        return Pet3DRig(
            rootNode: root,
            bodyNode: body,
            headNode: head,
            leftEyeNode: leftEye,
            rightEyeNode: rightEye,
            leftEarNode: leftEar,
            rightEarNode: rightEar,
            tailNode: tailRoot,
            frontLeftLeg: fl,
            frontRightLeg: fr,
            backLeftLeg: bl,
            backRightLeg: br,
            accessoriesNode: accNode
        )
    }

    // MARK: - 5. Robot (Aria)
    private static func buildRobot(accessory: String) -> Pet3DRig {
        let root = SCNNode()
        let body = SCNNode()
        body.position = SCNVector3(0, 0.28, 0)
        root.addChildNode(body)

        let metalMat = pbrMaterial(color: NSColor(red: 0.85, green: 0.88, blue: 0.92, alpha: 1.0), roughness: 0.18, metalness: 0.85)
        let cyanEmission = pbrMaterial(color: NSColor.cyan, roughness: 0.1, metalness: 0.2, emission: NSColor.cyan)
        let jointMat = pbrMaterial(color: NSColor(red: 0.2, green: 0.22, blue: 0.26, alpha: 1.0), roughness: 0.35, metalness: 0.6)

        // Chassis Sphere
        let chassisGeo = SCNSphere(radius: 0.26)
        chassisGeo.materials = [metalMat]
        body.addChildNode(SCNNode(geometry: chassisGeo))

        // Head Floating Unit
        let head = SCNNode()
        head.position = SCNVector3(0, 0.35, 0.05)
        body.addChildNode(head)

        let headGeo = SCNBox(width: 0.38, height: 0.28, length: 0.32, chamferRadius: 0.06)
        headGeo.materials = [metalMat]
        head.addChildNode(SCNNode(geometry: headGeo))

        // Visor Screen
        let visorGeo = SCNBox(width: 0.32, height: 0.14, length: 0.04, chamferRadius: 0.03)
        visorGeo.materials = [cyanEmission]
        let visor = SCNNode(geometry: visorGeo)
        visor.position = SCNVector3(0, 0.02, 0.16)
        head.addChildNode(visor)

        // Antenna Rod & Glowing Tip
        let antGeo = SCNCylinder(radius: 0.015, height: 0.22)
        antGeo.materials = [jointMat]
        let antTipGeo = SCNSphere(radius: 0.04)
        antTipGeo.materials = [cyanEmission]

        let ant = SCNNode()
        ant.position = SCNVector3(0, 0.22, 0)
        ant.addChildNode(SCNNode(geometry: antGeo))
        let tip = SCNNode(geometry: antTipGeo)
        tip.position = SCNVector3(0, 0.12, 0)
        ant.addChildNode(tip)
        head.addChildNode(ant)

        // Floating Magnetic Limbs
        let limbGeo = SCNCapsule(capRadius: 0.055, height: 0.22)
        limbGeo.materials = [metalMat]

        func makeArm(x: Float, y: Float, z: Float) -> SCNNode {
            let arm = SCNNode()
            arm.position = SCNVector3(x, y, z)
            arm.addChildNode(SCNNode(geometry: limbGeo))
            body.addChildNode(arm)
            return arm
        }

        let fl = makeArm(x: -0.28, y: 0.02, z: 0)
        let fr = makeArm(x: 0.28, y: 0.02, z: 0)
        let bl = makeArm(x: -0.16, y: -0.24, z: 0)
        let br = makeArm(x: 0.16, y: -0.24, z: 0)

        let accNode = buildAccessory(accessory, headNode: head)

        return Pet3DRig(
            rootNode: root,
            bodyNode: body,
            headNode: head,
            frontLeftLeg: fl,
            frontRightLeg: fr,
            backLeftLeg: bl,
            backRightLeg: br,
            accessoriesNode: accNode
        )
    }

    // MARK: - 6. RobotCat (Neo)
    private static func buildRobotCat(accessory: String) -> Pet3DRig {
        let root = SCNNode()
        let body = SCNNode()
        body.position = SCNVector3(0, 0.26, 0)
        root.addChildNode(body)

        let cyberMat = pbrMaterial(color: NSColor(red: 0.12, green: 0.14, blue: 0.18, alpha: 1.0), roughness: 0.2, metalness: 0.8)
        let neonGreen = pbrMaterial(color: NSColor(red: 0.1, green: 0.9, blue: 0.4, alpha: 1.0), roughness: 0.1, emission: NSColor(red: 0.1, green: 0.9, blue: 0.4, alpha: 1.0))

        let torsoGeo = SCNCapsule(capRadius: 0.23, height: 0.55)
        torsoGeo.materials = [cyberMat]
        let torsoNode = SCNNode(geometry: torsoGeo)
        torsoNode.eulerAngles = SCNVector3(Float.pi / 2.3, 0, 0)
        body.addChildNode(torsoNode)

        // Head
        let head = SCNNode()
        head.position = SCNVector3(0, 0.32, 0.24)
        body.addChildNode(head)

        let headGeo = SCNSphere(radius: 0.22)
        headGeo.materials = [cyberMat]
        head.addChildNode(SCNNode(geometry: headGeo))

        // Visor
        let visorGeo = SCNBox(width: 0.28, height: 0.08, length: 0.03, chamferRadius: 0.02)
        visorGeo.materials = [neonGreen]
        let visor = SCNNode(geometry: visorGeo)
        visor.position = SCNVector3(0, 0.04, 0.18)
        head.addChildNode(visor)

        // Cyber Triangular Ears
        let earGeo = SCNCone(topRadius: 0.01, bottomRadius: 0.07, height: 0.16)
        earGeo.materials = [neonGreen]
        let leftEar = SCNNode(geometry: earGeo)
        leftEar.position = SCNVector3(-0.12, 0.22, 0.0)
        leftEar.eulerAngles = SCNVector3(0, 0, -Float.pi / 8)
        head.addChildNode(leftEar)

        let rightEar = SCNNode(geometry: earGeo)
        rightEar.position = SCNVector3(0.12, 0.22, 0.0)
        rightEar.eulerAngles = SCNVector3(0, 0, Float.pi / 8)
        head.addChildNode(rightEar)

        // Cyber Tail
        let tailRoot = SCNNode()
        tailRoot.position = SCNVector3(0, -0.05, -0.26)
        body.addChildNode(tailRoot)

        let tailGeo = SCNCylinder(radius: 0.03, height: 0.34)
        tailGeo.materials = [neonGreen]
        let tail = SCNNode(geometry: tailGeo)
        tail.position = SCNVector3(0, 0.14, -0.12)
        tail.eulerAngles = SCNVector3(Float.pi / 3, 0, 0)
        tailRoot.addChildNode(tail)

        // 4 Legs
        let legGeo = SCNCapsule(capRadius: 0.05, height: 0.24)
        legGeo.materials = [cyberMat]
        func makeLeg(x: Float, y: Float, z: Float) -> SCNNode {
            let leg = SCNNode()
            leg.position = SCNVector3(x, y, z)
            leg.addChildNode(SCNNode(geometry: legGeo))
            body.addChildNode(leg)
            return leg
        }

        let fl = makeLeg(x: -0.15, y: -0.06, z: 0.14)
        let fr = makeLeg(x: 0.15, y: -0.06, z: 0.14)
        let bl = makeLeg(x: -0.15, y: -0.08, z: -0.16)
        let br = makeLeg(x: 0.15, y: -0.08, z: -0.16)

        let accNode = buildAccessory(accessory, headNode: head)

        return Pet3DRig(
            rootNode: root,
            bodyNode: body,
            headNode: head,
            leftEarNode: leftEar,
            rightEarNode: rightEar,
            tailNode: tailRoot,
            frontLeftLeg: fl,
            frontRightLeg: fr,
            backLeftLeg: bl,
            backRightLeg: br,
            accessoriesNode: accNode
        )
    }

    // MARK: - 7. Ghost (Boo)
    private static func buildGhost(accessory: String) -> Pet3DRig {
        let root = SCNNode()
        let body = SCNNode()
        body.position = SCNVector3(0, 0.28, 0)
        root.addChildNode(body)

        let ghostMat = pbrMaterial(color: NSColor(red: 0.92, green: 0.95, blue: 1.0, alpha: 0.88), roughness: 0.2, emission: NSColor(red: 0.3, green: 0.4, blue: 0.6, alpha: 0.3))
        let eyeMat = pbrMaterial(color: NSColor(red: 0.15, green: 0.15, blue: 0.25, alpha: 1.0), roughness: 0.1)

        // Dome Head + Floating Skirt
        let domeGeo = SCNSphere(radius: 0.28)
        domeGeo.materials = [ghostMat]
        let domeNode = SCNNode(geometry: domeGeo)
        domeNode.position = SCNVector3(0, 0.15, 0)
        body.addChildNode(domeNode)

        let skirtGeo = SCNCone(topRadius: 0.26, bottomRadius: 0.32, height: 0.35)
        skirtGeo.materials = [ghostMat]
        let skirt = SCNNode(geometry: skirtGeo)
        skirt.position = SCNVector3(0, -0.1, 0)
        body.addChildNode(skirt)

        // Ethereal Eyes
        let leftEye = SCNNode(geometry: SCNSphere(radius: 0.055))
        leftEye.geometry?.materials = [eyeMat]
        leftEye.position = SCNVector3(-0.11, 0.16, 0.23)
        leftEye.scale = SCNVector3(0.9, 1.2, 0.7)
        body.addChildNode(leftEye)

        let rightEye = SCNNode(geometry: SCNSphere(radius: 0.055))
        rightEye.geometry?.materials = [eyeMat]
        rightEye.position = SCNVector3(0.11, 0.16, 0.23)
        rightEye.scale = SCNVector3(0.9, 1.2, 0.7)
        body.addChildNode(rightEye)

        // Floating Wisp Arms
        let armGeo = SCNCapsule(capRadius: 0.05, height: 0.22)
        armGeo.materials = [ghostMat]

        let leftArm = SCNNode()
        leftArm.position = SCNVector3(-0.28, 0.05, 0.05)
        leftArm.eulerAngles = SCNVector3(0, 0, Float.pi / 4)
        leftArm.addChildNode(SCNNode(geometry: armGeo))
        body.addChildNode(leftArm)

        let rightArm = SCNNode()
        rightArm.position = SCNVector3(0.28, 0.05, 0.05)
        rightArm.eulerAngles = SCNVector3(0, 0, -Float.pi / 4)
        rightArm.addChildNode(SCNNode(geometry: armGeo))
        body.addChildNode(rightArm)

        let accNode = buildAccessory(accessory, headNode: body)

        return Pet3DRig(
            rootNode: root,
            bodyNode: body,
            headNode: domeNode,
            leftEyeNode: leftEye,
            rightEyeNode: rightEye,
            frontLeftLeg: leftArm,
            frontRightLeg: rightArm,
            accessoriesNode: accNode
        )
    }

    // MARK: - Helper Components
    private static func makeRoundEye(eyeMat: SCNMaterial, pupilMat: SCNMaterial) -> SCNNode {
        let eye = SCNNode()
        let sclera = SCNNode(geometry: SCNSphere(radius: 0.05))
        sclera.geometry?.materials = [eyeMat]
        eye.addChildNode(sclera)

        let pupil = SCNNode(geometry: SCNSphere(radius: 0.03))
        pupil.geometry?.materials = [pupilMat]
        pupil.position = SCNVector3(0, 0, 0.035)
        eye.addChildNode(pupil)
        return eye
    }

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
