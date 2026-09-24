import Foundation
import SwiftUI
import AppKit

// MARK: - Pure Composable Canvas Renderer

@MainActor
public struct PetCanvasRenderer {

    public static func draw(
        context: inout GraphicsContext,
        size: CGSize,
        species: PetSpecies,
        model: CharacterStructuralModel,
        animState: PetAnimState,
        snapshot: AnimationSnapshot,
        perf: PerformanceManager
    ) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        // 1. LAYER 1: AURA (Optional, low cost)
        if !perf.isSafeMode && (perf.dynamicLightingEnabled || perf.cpuReactiveGlowEnabled) {
            drawAura(context: &context, center: center, species: species, perf: perf, time: snapshot.time)
        }

        // Apply motion transforms (Spring squash/stretch, breath, levitation, head tilt)
        var petContext = context
        let bodyY = center.y + snapshot.levitationOffset + snapshot.breathOffset
        petContext.translateBy(x: center.x, y: bodyY)
        petContext.rotate(by: snapshot.headTiltAngle)
        petContext.scaleBy(x: snapshot.squashStretch.width, y: snapshot.squashStretch.height)
        petContext.translateBy(x: -center.x, y: -bodyY)

        let bodyCenter = CGPoint(x: center.x, y: bodyY)

        // 2. LAYER 2: BODY SHELL & DISTINCT SILHOUETTE ANATOMY
        drawBody(
            context: &petContext,
            center: bodyCenter,
            species: species,
            model: model,
            animState: animState,
            snapshot: snapshot,
            isGrayscale: perf.grayscaleTestMode
        )

        // 3. LAYER 3: FACIAL FEATURES & EYES
        drawFace(
            context: &petContext,
            center: bodyCenter,
            species: species,
            model: model,
            animState: animState,
            snapshot: snapshot,
            isGrayscale: perf.grayscaleTestMode
        )

        // 4. LAYER 4: FLOATING ACCESSORIES & PARTICLES (Only if enabled)
        if perf.particlesEnabled && !perf.isSafeMode {
            drawParticles(context: &context, size: size, snapshot: snapshot)
        }

        // 5. LAYER 5: OPTIONAL ENVIRONMENTAL WEATHER OVERLAY
        if perf.weatherEffectsEnabled && !perf.isSafeMode {
            drawWeatherOverlay(context: &context, snapshot: snapshot)
        }
    }

    // MARK: - Layer 1: Aura & Lighting (Optional)

    private static func drawAura(
        context: inout GraphicsContext,
        center: CGPoint,
        species: PetSpecies,
        perf: PerformanceManager,
        time: Double
    ) {
        let cpu = SystemMonitor.shared.cpuPercent
        let auraColor: Color
        if perf.cpuReactiveGlowEnabled && cpu > 70 {
            auraColor = Color.red.opacity(0.3)
        } else if perf.cpuReactiveGlowEnabled && cpu > 40 {
            auraColor = Color.orange.opacity(0.25)
        } else {
            auraColor = species.accentColor.opacity(0.18)
        }

        let radius: CGFloat = 52.0
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Circle().path(in: rect), with: .color(auraColor))
    }

    // MARK: - Layer 2: Anatomically Distinct Body Geometry

    private static func drawBody(
        context: inout GraphicsContext,
        center: CGPoint,
        species: PetSpecies,
        model: CharacterStructuralModel,
        animState: PetAnimState,
        snapshot: AnimationSnapshot,
        isGrayscale: Bool
    ) {
        // Base color handling
        let primaryColor = isGrayscale ? Color(white: 0.28) : species.accentColor
        let secondaryColor = isGrayscale ? Color(white: 0.20) : species.accentColor.opacity(0.7)
        let bellyColor = isGrayscale ? Color(white: 0.40) : Color.white.opacity(0.35)

        switch model {
        case .kineticSlime:
            drawKineticSlime(context: &context, center: center, primaryColor: primaryColor, secondaryColor: secondaryColor, time: snapshot.time)
            return

        case .cyberSentry:
            drawCyberSentry(context: &context, center: center, primaryColor: primaryColor, secondaryColor: secondaryColor, time: snapshot.time)
            return

        case .pixelChibiBeast:
            drawPixelChibiBeast(context: &context, center: center, primaryColor: primaryColor, secondaryColor: secondaryColor, snapshot: snapshot)
            return

        case .classicSpecies:
            break
        }

        // Render Distinct Silhouettes for each of the 7 classic species
        switch species {
        case .cat:
            // CAT (Mochi): Small feline head, triangular upright ears, short legs, curved tail, paws
            drawCatAnatomy(context: &context, center: center, primary: primaryColor, belly: bellyColor, snapshot: snapshot)

        case .dragon:
            // DRAGON (Ember): Large horns, wings, elongated snout, 4 legs with claws, long tail with spade
            drawDragonAnatomy(context: &context, center: center, primary: primaryColor, secondary: secondaryColor, snapshot: snapshot)

        case .robot:
            // ROBOT (ARIA): Mechanical rectangular head and torso, antenna, articulated limbs with joints, chest core (NOT an animal body!)
            drawRobotAnatomy(context: &context, center: center, primary: primaryColor, snapshot: snapshot)

        case .robotcat:
            // ROBOT CAT (NEO): Hybrid with cat ears, robotic face plate, cyber panel body, segmented tail
            drawRobotCatAnatomy(context: &context, center: center, primary: primaryColor, secondary: secondaryColor, snapshot: snapshot)

        case .ghost:
            // GHOST (Boo): NO LEGS AT ALL! Floating body, wavy lower sheet/skirt, small arms, floating wave
            drawGhostAnatomy(context: &context, center: center, primary: primaryColor, snapshot: snapshot)

        case .fox:
            // FOX (Kita): Pointed ears with dark rims, elongated muzzle, fox ruff, 4 legs, giant fluffy tail
            drawFoxAnatomy(context: &context, center: center, primary: primaryColor, secondary: secondaryColor, snapshot: snapshot)

        case .bunny:
            // BUNNY (Pochi): Very tall ears, chubby round body, short front paws, large hind hopping legs, cotton puff tail
            drawBunnyAnatomy(context: &context, center: center, primary: primaryColor, snapshot: snapshot)
        }
    }

    // MARK: - Species Anatomy Implementations (Distinct Silhouettes)

    // 1. CAT — MOCHI
    private static func drawCatAnatomy(context: inout GraphicsContext, center: CGPoint, primary: Color, belly: Color, snapshot: AnimationSnapshot) {
        // Body (feline sitting posture)
        let bodyRect = CGRect(x: center.x - 26, y: center.y - 12, width: 52, height: 42)
        context.fill(RoundedRectangle(cornerRadius: 18).path(in: bodyRect), with: .color(primary))

        // Belly patch
        let bellyRect = CGRect(x: center.x - 14, y: center.y - 4, width: 28, height: 26)
        context.fill(Ellipse().path(in: bellyRect), with: .color(belly))

        // Head (compact feline head)
        let headRect = CGRect(x: center.x - 22, y: center.y - 34, width: 44, height: 34)
        context.fill(RoundedRectangle(cornerRadius: 16).path(in: headRect), with: .color(primary))

        // Triangular Upright Cat Ears
        var lEar = Path()
        lEar.move(to: CGPoint(x: center.x - 20, y: center.y - 30))
        lEar.addLine(to: CGPoint(x: center.x - 26, y: center.y - 48))
        lEar.addLine(to: CGPoint(x: center.x - 10, y: center.y - 32))
        lEar.closeSubpath()
        context.fill(lEar, with: .color(primary))

        var rEar = Path()
        rEar.move(to: CGPoint(x: center.x + 10, y: center.y - 32))
        rEar.addLine(to: CGPoint(x: center.x + 26, y: center.y - 48))
        rEar.addLine(to: CGPoint(x: center.x + 20, y: center.y - 30))
        rEar.closeSubpath()
        context.fill(rEar, with: .color(primary))

        // Short front feline paws
        let lPaw = Capsule().path(in: CGRect(x: center.x - 18, y: center.y + 22, width: 12, height: 10))
        let rPaw = Capsule().path(in: CGRect(x: center.x + 6, y: center.y + 22, width: 12, height: 10))
        context.fill(lPaw, with: .color(primary.opacity(0.9)))
        context.fill(rPaw, with: .color(primary.opacity(0.9)))

        // Long curved cat tail
        var tail = Path()
        let tailEnd = CGPoint(x: center.x - 34 + CGFloat(snapshot.tailWagAngle.degrees * 0.5), y: center.y - 6)
        tail.move(to: CGPoint(x: center.x - 22, y: center.y + 16))
        tail.addQuadCurve(to: tailEnd, control: CGPoint(x: center.x - 38, y: center.y + 18))
        context.stroke(tail, with: .color(primary), lineWidth: 4.5)
    }

    // 2. DRAGON — EMBER (Distinct from cat: Horns, wings, elongated snout, claws, spade tail)
    private static func drawDragonAnatomy(context: inout GraphicsContext, center: CGPoint, primary: Color, secondary: Color, snapshot: AnimationSnapshot) {
        // Wings (behind body)
        let wingSpan = CGFloat(snapshot.wingFlapAngle.degrees * 0.4)
        var lWing = Path()
        lWing.move(to: CGPoint(x: center.x - 16, y: center.y - 12))
        lWing.addLine(to: CGPoint(x: center.x - 42, y: center.y - 34 + wingSpan))
        lWing.addLine(to: CGPoint(x: center.x - 32, y: center.y - 8))
        lWing.addLine(to: CGPoint(x: center.x - 20, y: center.y - 2))
        lWing.closeSubpath()
        context.fill(lWing, with: .color(secondary))

        var rWing = Path()
        rWing.move(to: CGPoint(x: center.x + 16, y: center.y - 12))
        rWing.addLine(to: CGPoint(x: center.x + 42, y: center.y - 34 + wingSpan))
        rWing.addLine(to: CGPoint(x: center.x + 32, y: center.y - 8))
        rWing.addLine(to: CGPoint(x: center.x + 20, y: center.y - 2))
        rWing.closeSubpath()
        context.fill(rWing, with: .color(secondary))

        // Robust Dragon Body
        let bodyRect = CGRect(x: center.x - 28, y: center.y - 14, width: 56, height: 44)
        context.fill(RoundedRectangle(cornerRadius: 16).path(in: bodyRect), with: .color(primary))

        // Elongated Dragon Head & Snout
        let headRect = CGRect(x: center.x - 24, y: center.y - 36, width: 48, height: 32)
        context.fill(RoundedRectangle(cornerRadius: 12).path(in: headRect), with: .color(primary))

        // Snout extension
        let snoutRect = CGRect(x: center.x - 16, y: center.y - 22, width: 32, height: 16)
        context.fill(RoundedRectangle(cornerRadius: 8).path(in: snoutRect), with: .color(primary))

        // Horns
        var lHorn = Path()
        lHorn.move(to: CGPoint(x: center.x - 18, y: center.y - 32))
        lHorn.addQuadCurve(to: CGPoint(x: center.x - 30, y: center.y - 52), control: CGPoint(x: center.x - 28, y: center.y - 42))
        lHorn.addLine(to: CGPoint(x: center.x - 10, y: center.y - 32))
        lHorn.closeSubpath()
        context.fill(lHorn, with: .color(secondary))

        var rHorn = Path()
        rHorn.move(to: CGPoint(x: center.x + 10, y: center.y - 32))
        rHorn.addQuadCurve(to: CGPoint(x: center.x + 30, y: center.y - 52), control: CGPoint(x: center.x + 28, y: center.y - 42))
        rHorn.addLine(to: CGPoint(x: center.x + 18, y: center.y - 32))
        rHorn.closeSubpath()
        context.fill(rHorn, with: .color(secondary))

        // Dorsal spikes along back
        for i in 0..<3 {
            let sx = center.x - 8 + CGFloat(i * 8)
            var spike = Path()
            spike.move(to: CGPoint(x: sx - 3, y: center.y - 14))
            spike.addLine(to: CGPoint(x: sx, y: center.y - 22))
            spike.addLine(to: CGPoint(x: sx + 3, y: center.y - 14))
            spike.closeSubpath()
            context.fill(spike, with: .color(secondary))
        }

        // Long Dragon Tail with Spade Tip
        var tail = Path()
        let tailTip = CGPoint(x: center.x - 38 + CGFloat(snapshot.tailWagAngle.degrees * 0.4), y: center.y + 4)
        tail.move(to: CGPoint(x: center.x - 24, y: center.y + 18))
        tail.addQuadCurve(to: tailTip, control: CGPoint(x: center.x - 42, y: center.y + 24))
        context.stroke(tail, with: .color(primary), lineWidth: 5.0)

        // Spade at tail tip
        var spade = Path()
        spade.move(to: tailTip)
        spade.addLine(to: CGPoint(x: tailTip.x - 8, y: tailTip.y - 6))
        spade.addLine(to: CGPoint(x: tailTip.x - 10, y: tailTip.y + 4))
        spade.closeSubpath()
        context.fill(spade, with: .color(secondary))

        // Claws/Legs
        let lClaw = RoundedRectangle(cornerRadius: 3).path(in: CGRect(x: center.x - 20, y: center.y + 24, width: 14, height: 8))
        let rClaw = RoundedRectangle(cornerRadius: 3).path(in: CGRect(x: center.x + 6, y: center.y + 24, width: 14, height: 8))
        context.fill(lClaw, with: .color(primary))
        context.fill(rClaw, with: .color(primary))
    }

    // 3. ROBOT — ARIA (Mechanical rectangular head & body, articulated limbs with joints, chest core)
    private static func drawRobotAnatomy(context: inout GraphicsContext, center: CGPoint, primary: Color, snapshot: AnimationSnapshot) {
        // Antenna
        var ant = Path()
        ant.move(to: CGPoint(x: center.x, y: center.y - 34))
        ant.addLine(to: CGPoint(x: center.x, y: center.y - 48))
        context.stroke(ant, with: .color(Color.gray), lineWidth: 2.5)
        let antTip = Circle().path(in: CGRect(x: center.x - 4, y: center.y - 54, width: 8, height: 8))
        context.fill(antTip, with: .color(Color.red))

        // Segmented Rectangular Head
        let headRect = CGRect(x: center.x - 24, y: center.y - 34, width: 48, height: 26)
        context.fill(RoundedRectangle(cornerRadius: 6).path(in: headRect), with: .color(primary))
        context.stroke(RoundedRectangle(cornerRadius: 6).path(in: headRect), with: .color(Color.gray), lineWidth: 1.5)

        // Neck joint
        let neck = Rectangle().path(in: CGRect(x: center.x - 6, y: center.y - 8, width: 12, height: 4))
        context.fill(neck, with: .color(Color.gray))

        // Rectangular Mechanical Torso
        let torsoRect = CGRect(x: center.x - 26, y: center.y - 4, width: 52, height: 32)
        context.fill(RoundedRectangle(cornerRadius: 6).path(in: torsoRect), with: .color(primary))
        context.stroke(RoundedRectangle(cornerRadius: 6).path(in: torsoRect), with: .color(Color.gray), lineWidth: 1.5)

        // Glowing Chest Power Core
        let core = Circle().path(in: CGRect(x: center.x - 7, y: center.y + 6, width: 14, height: 14))
        context.fill(core, with: .color(Color.cyan))

        // Articulated Mechanical Arms with circular joints
        let lJoint = Circle().path(in: CGRect(x: center.x - 32, y: center.y - 2, width: 7, height: 7))
        let rJoint = Circle().path(in: CGRect(x: center.x + 25, y: center.y - 2, width: 7, height: 7))
        context.fill(lJoint, with: .color(Color.gray))
        context.fill(rJoint, with: .color(Color.gray))

        let lArm = RoundedRectangle(cornerRadius: 3).path(in: CGRect(x: center.x - 33, y: center.y + 5, width: 6, height: 16))
        let rArm = RoundedRectangle(cornerRadius: 3).path(in: CGRect(x: center.x + 27, y: center.y + 5, width: 6, height: 16))
        context.fill(lArm, with: .color(primary))
        context.fill(rArm, with: .color(primary))

        // Articulated Mechanical Legs with visible joints
        let lLegJoint = Circle().path(in: CGRect(x: center.x - 17, y: center.y + 26, width: 6, height: 6))
        let rLegJoint = Circle().path(in: CGRect(x: center.x + 11, y: center.y + 26, width: 6, height: 6))
        context.fill(lLegJoint, with: .color(Color.gray))
        context.fill(rLegJoint, with: .color(Color.gray))

        let lLeg = RoundedRectangle(cornerRadius: 3).path(in: CGRect(x: center.x - 19, y: center.y + 30, width: 8, height: 12))
        let rLeg = RoundedRectangle(cornerRadius: 3).path(in: CGRect(x: center.x + 11, y: center.y + 30, width: 8, height: 12))
        context.fill(lLeg, with: .color(primary))
        context.fill(rLeg, with: .color(primary))
    }

    // 4. ROBOT CAT — NEO (Hybrid: Cat ears, mechanical face, cyber panel body, segmented tail)
    private static func drawRobotCatAnatomy(context: inout GraphicsContext, center: CGPoint, primary: Color, secondary: Color, snapshot: AnimationSnapshot) {
        // Robotic Cat Ears (metal plated)
        var lEar = Path()
        lEar.move(to: CGPoint(x: center.x - 22, y: center.y - 28))
        lEar.addLine(to: CGPoint(x: center.x - 28, y: center.y - 46))
        lEar.addLine(to: CGPoint(x: center.x - 12, y: center.y - 30))
        lEar.closeSubpath()
        context.fill(lEar, with: .color(primary))
        context.stroke(lEar, with: .color(Color.green.opacity(0.8)), lineWidth: 1.5)

        var rEar = Path()
        rEar.move(to: CGPoint(x: center.x + 12, y: center.y - 30))
        rEar.addLine(to: CGPoint(x: center.x + 28, y: center.y - 46))
        rEar.addLine(to: CGPoint(x: center.x + 22, y: center.y - 28))
        rEar.closeSubpath()
        context.fill(rEar, with: .color(primary))
        context.stroke(rEar, with: .color(Color.green.opacity(0.8)), lineWidth: 1.5)

        // Cyber Head Plate
        let headRect = CGRect(x: center.x - 24, y: center.y - 32, width: 48, height: 30)
        context.fill(RoundedRectangle(cornerRadius: 12).path(in: headRect), with: .color(primary))

        // Mechanical Cyber Torso
        let bodyRect = CGRect(x: center.x - 26, y: center.y - 2, width: 52, height: 34)
        context.fill(RoundedRectangle(cornerRadius: 10).path(in: bodyRect), with: .color(primary))

        // Cyber Circuit Trace Line on Chest
        var circuit = Path()
        circuit.move(to: CGPoint(x: center.x - 16, y: center.y + 12))
        circuit.addLine(to: CGPoint(x: center.x, y: center.y + 12))
        circuit.addLine(to: CGPoint(x: center.x + 6, y: center.y + 18))
        circuit.addLine(to: CGPoint(x: center.x + 16, y: center.y + 18))
        context.stroke(circuit, with: .color(Color.green), lineWidth: 1.5)

        // Segmented Mechanical Tail with LED tip
        var tail = Path()
        let tailEnd = CGPoint(x: center.x - 34 + CGFloat(snapshot.tailWagAngle.degrees * 0.4), y: center.y + 6)
        tail.move(to: CGPoint(x: center.x - 24, y: center.y + 20))
        tail.addQuadCurve(to: tailEnd, control: CGPoint(x: center.x - 38, y: center.y + 22))
        context.stroke(tail, with: .color(Color.gray), lineWidth: 3.5)

        let tailLed = Circle().path(in: CGRect(x: tailEnd.x - 3, y: tailEnd.y - 3, width: 6, height: 6))
        context.fill(tailLed, with: .color(Color.green))

        // Robotic Paws
        let lPaw = RoundedRectangle(cornerRadius: 3).path(in: CGRect(x: center.x - 16, y: center.y + 28, width: 10, height: 8))
        let rPaw = RoundedRectangle(cornerRadius: 3).path(in: CGRect(x: center.x + 6, y: center.y + 28, width: 10, height: 8))
        context.fill(lPaw, with: .color(Color.gray))
        context.fill(rPaw, with: .color(Color.gray))
    }

    // 5. GHOST — BOO (NO LEGS AT ALL! Floating body, wavy lower skirt, floating wisps)
    private static func drawGhostAnatomy(context: inout GraphicsContext, center: CGPoint, primary: Color, snapshot: AnimationSnapshot) {
        // Floating Undulating Ghost Body (NO LEGS!)
        let wave = snapshot.ghostWaveOffset
        var ghost = Path()
        let topCenter = CGPoint(x: center.x, y: center.y - 34)
        ghost.move(to: CGPoint(x: center.x - 26, y: center.y - 6))
        // Top dome
        ghost.addQuadCurve(to: CGPoint(x: center.x + 26, y: center.y - 6), control: CGPoint(x: topCenter.x, y: topCenter.y - 12))
        // Right side
        ghost.addLine(to: CGPoint(x: center.x + 24, y: center.y + 18))
        // Wavy scalloped bottom skirt (Floating sheet with zero legs)
        let bY = center.y + 22
        ghost.addQuadCurve(to: CGPoint(x: center.x + 8, y: bY + wave), control: CGPoint(x: center.x + 16, y: bY - 6))
        ghost.addQuadCurve(to: CGPoint(x: center.x - 8, y: bY - wave), control: CGPoint(x: center.x, y: bY + 6))
        ghost.addQuadCurve(to: CGPoint(x: center.x - 24, y: bY), control: CGPoint(x: center.x - 16, y: bY - 6))
        // Left side
        ghost.closeSubpath()

        // Translucent ethereal ghost fill
        context.fill(ghost, with: .color(primary.opacity(0.85)))
        context.stroke(ghost, with: .color(Color.white.opacity(0.7)), lineWidth: 1.5)

        // Floating rounded ghost arms/wisps
        let lWisp = Ellipse().path(in: CGRect(x: center.x - 34, y: center.y - 2, width: 14, height: 8))
        let rWisp = Ellipse().path(in: CGRect(x: center.x + 20, y: center.y - 2, width: 14, height: 8))
        context.fill(lWisp, with: .color(primary.opacity(0.85)))
        context.fill(rWisp, with: .color(primary.opacity(0.85)))
    }

    // 6. FOX — KITA (Pointed ears with dark rims, elongated muzzle, fox ruff, giant fluffy tail)
    private static func drawFoxAnatomy(context: inout GraphicsContext, center: CGPoint, primary: Color, secondary: Color, snapshot: AnimationSnapshot) {
        // Large Fluffy Fox Tail (prominent behind body)
        var tail = Path()
        let tailEnd = CGPoint(x: center.x - 42 + CGFloat(snapshot.tailWagAngle.degrees * 0.6), y: center.y - 4)
        tail.move(to: CGPoint(x: center.x - 18, y: center.y + 14))
        tail.addQuadCurve(to: tailEnd, control: CGPoint(x: center.x - 48, y: center.y + 28))
        context.stroke(tail, with: .color(primary), lineWidth: 14.0)

        // White fluffy tip of fox tail
        let tailTip = Circle().path(in: CGRect(x: tailEnd.x - 6, y: tailEnd.y - 6, width: 12, height: 12))
        context.fill(tailTip, with: .color(Color.white))

        // Fox Body
        let bodyRect = CGRect(x: center.x - 26, y: center.y - 10, width: 52, height: 40)
        context.fill(RoundedRectangle(cornerRadius: 16).path(in: bodyRect), with: .color(primary))

        // White Fox Chest Ruff
        var ruff = Path()
        ruff.move(to: CGPoint(x: center.x - 14, y: center.y - 8))
        ruff.addLine(to: CGPoint(x: center.x, y: center.y + 12))
        ruff.addLine(to: CGPoint(x: center.x + 14, y: center.y - 8))
        ruff.closeSubpath()
        context.fill(ruff, with: .color(Color.white.opacity(0.9)))

        // Fox Head with Elongated Muzzle
        let headRect = CGRect(x: center.x - 24, y: center.y - 34, width: 48, height: 32)
        context.fill(RoundedRectangle(cornerRadius: 14).path(in: headRect), with: .color(primary))

        // Pointed Fox Snout/Muzzle
        var muzzle = Path()
        muzzle.move(to: CGPoint(x: center.x - 12, y: center.y - 18))
        muzzle.addLine(to: CGPoint(x: center.x, y: center.y - 6))
        muzzle.addLine(to: CGPoint(x: center.x + 12, y: center.y - 18))
        muzzle.closeSubpath()
        context.fill(muzzle, with: .color(Color.white))

        let nose = Circle().path(in: CGRect(x: center.x - 2.5, y: center.y - 8, width: 5, height: 5))
        context.fill(nose, with: .color(Color.black))

        // Large Pointed Fox Ears with Dark Rims
        var lEar = Path()
        lEar.move(to: CGPoint(x: center.x - 22, y: center.y - 30))
        lEar.addLine(to: CGPoint(x: center.x - 28, y: center.y - 52))
        lEar.addLine(to: CGPoint(x: center.x - 8, y: center.y - 32))
        lEar.closeSubpath()
        context.fill(lEar, with: .color(primary))
        context.stroke(lEar, with: .color(Color(white: 0.15)), lineWidth: 1.5)

        var rEar = Path()
        rEar.move(to: CGPoint(x: center.x + 8, y: center.y - 32))
        rEar.addLine(to: CGPoint(x: center.x + 28, y: center.y - 52))
        rEar.addLine(to: CGPoint(x: center.x + 22, y: center.y - 30))
        rEar.closeSubpath()
        context.fill(rEar, with: .color(primary))
        context.stroke(rEar, with: .color(Color(white: 0.15)), lineWidth: 1.5)

        // Four Slender Legs with Dark Paws
        let lPaw = Capsule().path(in: CGRect(x: center.x - 16, y: center.y + 24, width: 8, height: 10))
        let rPaw = Capsule().path(in: CGRect(x: center.x + 8, y: center.y + 24, width: 8, height: 10))
        context.fill(lPaw, with: .color(Color(white: 0.15)))
        context.fill(rPaw, with: .color(Color(white: 0.15)))
    }

    // 7. BUNNY — POCHI (Very tall ears, chubby round body, short front paws, large hind hopping legs, puff tail)
    private static func drawBunnyAnatomy(context: inout GraphicsContext, center: CGPoint, primary: Color, snapshot: AnimationSnapshot) {
        // Very Tall Upright Rabbit Ears
        let lEar = Capsule().path(in: CGRect(x: center.x - 20, y: center.y - 58, width: 12, height: 36))
        let rEar = Capsule().path(in: CGRect(x: center.x + 8, y: center.y - 58, width: 12, height: 36))
        context.fill(lEar, with: .color(primary))
        context.fill(rEar, with: .color(primary))

        // Pink inner ears
        let lInner = Capsule().path(in: CGRect(x: center.x - 17, y: center.y - 54, width: 6, height: 28))
        let rInner = Capsule().path(in: CGRect(x: center.x + 11, y: center.y - 54, width: 6, height: 28))
        context.fill(lInner, with: .color(Color.pink.opacity(0.55)))
        context.fill(rInner, with: .color(Color.pink.opacity(0.55)))

        // Chubby Round Rabbit Body
        let bodyRect = CGRect(x: center.x - 28, y: center.y - 8, width: 56, height: 42)
        context.fill(Ellipse().path(in: bodyRect), with: .color(primary))

        // Round Head
        let headRect = CGRect(x: center.x - 22, y: center.y - 32, width: 44, height: 32)
        context.fill(Ellipse().path(in: headRect), with: .color(primary))

        // Short front bunny paws held near chest
        let lFront = Capsule().path(in: CGRect(x: center.x - 12, y: center.y + 6, width: 8, height: 12))
        let rFront = Capsule().path(in: CGRect(x: center.x + 4, y: center.y + 6, width: 8, height: 12))
        context.fill(lFront, with: .color(primary.opacity(0.9)))
        context.fill(rFront, with: .color(primary.opacity(0.9)))

        // Large Hind Hopping Feet (Key bunny silhouette feature!)
        let lFoot = Capsule().path(in: CGRect(x: center.x - 28, y: center.y + 22, width: 20, height: 10))
        let rFoot = Capsule().path(in: CGRect(x: center.x + 8, y: center.y + 22, width: 20, height: 10))
        context.fill(lFoot, with: .color(primary))
        context.fill(rFoot, with: .color(primary))

        // Round Cotton Puff Tail
        let puffTail = Circle().path(in: CGRect(x: center.x - 34, y: center.y + 12, width: 12, height: 12))
        context.fill(puffTail, with: .color(Color.white))
    }

    // Structural Model Renderers
    private static func drawKineticSlime(context: inout GraphicsContext, center: CGPoint, primaryColor: Color, secondaryColor: Color, time: Double) {
        let pointsCount = 8
        let baseRadius: CGFloat = 36.0
        var pts: [CGPoint] = []
        for i in 0..<pointsCount {
            let angle = (Double(i) / Double(pointsCount)) * 2 * .pi
            let r = baseRadius + CGFloat(sin(time * 3.0 + Double(i) * 1.2) * 4.0)
            pts.append(CGPoint(x: center.x + CGFloat(cos(angle)) * r, y: center.y + CGFloat(sin(angle)) * (r * 0.9)))
        }

        var slimePath = Path()
        slimePath.move(to: CGPoint(x: (pts[0].x + pts[pointsCount - 1].x) / 2, y: (pts[0].y + pts[pointsCount - 1].y) / 2))
        for i in 0..<pointsCount {
            let next = (i + 1) % pointsCount
            let mid = CGPoint(x: (pts[i].x + pts[next].x) / 2, y: (pts[i].y + pts[next].y) / 2)
            slimePath.addQuadCurve(to: mid, control: pts[i])
        }
        slimePath.closeSubpath()

        context.fill(slimePath, with: .color(primaryColor))
        let highlight = Ellipse().path(in: CGRect(x: center.x - 16, y: center.y - 20, width: 12, height: 7))
        context.fill(highlight, with: .color(Color.white.opacity(0.6)))
    }

    private static func drawCyberSentry(context: inout GraphicsContext, center: CGPoint, primaryColor: Color, secondaryColor: Color, time: Double) {
        let hull = RoundedRectangle(cornerRadius: 12).path(in: CGRect(x: center.x - 28, y: center.y - 22, width: 56, height: 46))
        context.fill(hull, with: .color(primaryColor))
        context.stroke(hull, with: .color(Color.cyan), lineWidth: 2.0)

        // Floating Satellite Thruster Pods
        let lPod = Capsule().path(in: CGRect(x: center.x - 38, y: center.y - 10 + CGFloat(sin(time * 4) * 3), width: 8, height: 18))
        let rPod = Capsule().path(in: CGRect(x: center.x + 30, y: center.y - 10 - CGFloat(sin(time * 4) * 3), width: 8, height: 18))
        context.fill(lPod, with: .color(Color.gray))
        context.fill(rPod, with: .color(Color.gray))
    }

    private static func drawPixelChibiBeast(context: inout GraphicsContext, center: CGPoint, primaryColor: Color, secondaryColor: Color, snapshot: AnimationSnapshot) {
        let body = RoundedRectangle(cornerRadius: 18).path(in: CGRect(x: center.x - 26, y: center.y - 12, width: 52, height: 40))
        context.fill(body, with: .color(primaryColor))

        let head = RoundedRectangle(cornerRadius: 16).path(in: CGRect(x: center.x - 22, y: center.y - 34, width: 44, height: 34))
        context.fill(head, with: .color(primaryColor))
    }

    // MARK: - Layer 3: Facial Features & Expressive Eyes

    public enum CharacterEyeStyle {
        case standard     // Expressive glossy iris + specular shine
        case led          // Digital glowing LED matrix on dark recessed socket
        case spectral     // Ethereal ghostly gaze with inner spirit glow
        case reptilian    // Dragon slit-pupil with golden amber iris
    }

    public struct CharacterFaceLayout {
        public let eyeCenterY: CGFloat
        public let eyeSpacing: CGFloat
        public let eyeWidth: CGFloat
        public let eyeHeight: CGFloat
        public let eyeStyle: CharacterEyeStyle
        public let noseOffsetY: CGFloat?
        public let mouthOffsetY: CGFloat
        public let mouthWidth: CGFloat
        public let hasBlush: Bool
        public let blushOffsetY: CGFloat
        public let blushSpacing: CGFloat
    }

    public static func faceLayout(for species: PetSpecies, model: CharacterStructuralModel) -> CharacterFaceLayout {
        // If structural model overrides anatomy
        if model == .cyberSentry {
            return CharacterFaceLayout(
                eyeCenterY: -12,
                eyeSpacing: 10,
                eyeWidth: 7.5,
                eyeHeight: 7.5,
                eyeStyle: .led,
                noseOffsetY: nil,
                mouthOffsetY: -4,
                mouthWidth: 10,
                hasBlush: false,
                blushOffsetY: 0,
                blushSpacing: 0
            )
        } else if model == .kineticSlime {
            return CharacterFaceLayout(
                eyeCenterY: -6,
                eyeSpacing: 10,
                eyeWidth: 8,
                eyeHeight: 9,
                eyeStyle: .standard,
                noseOffsetY: nil,
                mouthOffsetY: 1,
                mouthWidth: 8,
                hasBlush: true,
                blushOffsetY: -1,
                blushSpacing: 16
            )
        }

        // Species-specific calibrated layouts matched directly to head bounds
        switch species {
        case .cat:
            // Head: [-34, 0], center -17
            return CharacterFaceLayout(
                eyeCenterY: -21,
                eyeSpacing: 11,
                eyeWidth: 8.0,
                eyeHeight: 9.0,
                eyeStyle: .standard,
                noseOffsetY: -14,
                mouthOffsetY: -9,
                mouthWidth: 8.0,
                hasBlush: true,
                blushOffsetY: -15,
                blushSpacing: 16
            )

        case .dragon:
            // Head: [-36, -4], Snout: [-22, -6]
            return CharacterFaceLayout(
                eyeCenterY: -24,
                eyeSpacing: 13,
                eyeWidth: 7.5,
                eyeHeight: 8.5,
                eyeStyle: .reptilian,
                noseOffsetY: -13,
                mouthOffsetY: -8,
                mouthWidth: 10.0,
                hasBlush: false,
                blushOffsetY: 0,
                blushSpacing: 0
            )

        case .robot:
            // Head: [-34, -8], center -21. Dark socket plate with glowing cyan LED eyes
            return CharacterFaceLayout(
                eyeCenterY: -21,
                eyeSpacing: 10,
                eyeWidth: 7.5,
                eyeHeight: 7.5,
                eyeStyle: .led,
                noseOffsetY: nil,
                mouthOffsetY: -12,
                mouthWidth: 12.0,
                hasBlush: false,
                blushOffsetY: 0,
                blushSpacing: 0
            )

        case .robotcat:
            // Cyber Head: [-32, -2], center -17
            return CharacterFaceLayout(
                eyeCenterY: -20,
                eyeSpacing: 10,
                eyeWidth: 7.5,
                eyeHeight: 7.5,
                eyeStyle: .led,
                noseOffsetY: -13,
                mouthOffsetY: -8,
                mouthWidth: 9.0,
                hasBlush: false,
                blushOffsetY: 0,
                blushSpacing: 0
            )

        case .ghost:
            // Dome: [-42, -6]. Face placed in upper-middle dome. NO LEGS AT ALL.
            return CharacterFaceLayout(
                eyeCenterY: -20,
                eyeSpacing: 11,
                eyeWidth: 7.5,
                eyeHeight: 9.5,
                eyeStyle: .spectral,
                noseOffsetY: nil,
                mouthOffsetY: -10,
                mouthWidth: 8.0,
                hasBlush: true,
                blushOffsetY: -14,
                blushSpacing: 17
            )

        case .fox:
            // Head: [-34, -2], Muzzle: [-18, -6]
            return CharacterFaceLayout(
                eyeCenterY: -23,
                eyeSpacing: 12,
                eyeWidth: 8.0,
                eyeHeight: 8.5,
                eyeStyle: .standard,
                noseOffsetY: -8,
                mouthOffsetY: -4,
                mouthWidth: 8.0,
                hasBlush: true,
                blushOffsetY: -17,
                blushSpacing: 18
            )

        case .bunny:
            // Ears: [-58, -22], Head: [-32, 0]. Eyes placed comfortably inside head.
            return CharacterFaceLayout(
                eyeCenterY: -21,
                eyeSpacing: 11,
                eyeWidth: 8.0,
                eyeHeight: 9.0,
                eyeStyle: .standard,
                noseOffsetY: -14,
                mouthOffsetY: -9,
                mouthWidth: 8.0,
                hasBlush: true,
                blushOffsetY: -15,
                blushSpacing: 16
            )
        }
    }

    private static func drawFace(
        context: inout GraphicsContext,
        center: CGPoint,
        species: PetSpecies,
        model: CharacterStructuralModel,
        animState: PetAnimState,
        snapshot: AnimationSnapshot,
        isGrayscale: Bool
    ) {
        let layout = faceLayout(for: species, model: model)

        // 1. Draw Eyes (handles LED sockets, spectral glows, reptilian slits, or standard gloss)
        drawCharacterEyes(
            context: &context,
            center: center,
            species: species,
            layout: layout,
            animState: animState,
            snapshot: snapshot,
            isGrayscale: isGrayscale
        )

        // 2. Draw Species-specific Nose
        drawCharacterNose(
            context: &context,
            center: center,
            species: species,
            layout: layout,
            isGrayscale: isGrayscale
        )

        // 3. Draw Mouth (LED smile for robots, kawaii W-mouth for bunny/cat, expressive curve)
        drawCharacterMouth(
            context: &context,
            center: center,
            species: species,
            layout: layout,
            animState: animState,
            snapshot: snapshot,
            isGrayscale: isGrayscale
        )

        // 4. Draw Soft Blush Cheeks
        drawBlush(
            context: &context,
            center: center,
            layout: layout,
            isGrayscale: isGrayscale
        )

        // 5. Draw Whiskers for Cat
        if species == .cat && !isGrayscale {
            var whiskers = Path()
            let wy = center.y - 12
            whiskers.move(to: CGPoint(x: center.x - 22, y: wy - 2))
            whiskers.addLine(to: CGPoint(x: center.x - 34, y: wy - 4))
            whiskers.move(to: CGPoint(x: center.x - 22, y: wy + 3))
            whiskers.addLine(to: CGPoint(x: center.x - 34, y: wy + 4))

            whiskers.move(to: CGPoint(x: center.x + 22, y: wy - 2))
            whiskers.addLine(to: CGPoint(x: center.x + 34, y: wy - 4))
            whiskers.move(to: CGPoint(x: center.x + 22, y: wy + 3))
            whiskers.addLine(to: CGPoint(x: center.x + 34, y: wy + 4))
            context.stroke(whiskers, with: .color(Color.white.opacity(0.6)), lineWidth: 1.2)
        }
    }

    private static func drawCharacterEyes(
        context: inout GraphicsContext,
        center: CGPoint,
        species: PetSpecies,
        layout: CharacterFaceLayout,
        animState: PetAnimState,
        snapshot: AnimationSnapshot,
        isGrayscale: Bool
    ) {
        let eyeY = center.y + layout.eyeCenterY
        let leftEyeX = center.x - layout.eyeSpacing + snapshot.eyeOffset.x
        let rightEyeX = center.x + layout.eyeSpacing + snapshot.eyeOffset.x
        let gazeY = eyeY + snapshot.eyeOffset.y

        let isClosed = animState == .sleep || snapshot.blinkProgress >= 0.85

        switch layout.eyeStyle {
        case .led:
            // Recessed Dark Socket Plate behind the eyes
            let socketRect = CGRect(x: center.x - 18, y: eyeY - 7.5, width: 36, height: 15)
            context.fill(RoundedRectangle(cornerRadius: 4).path(in: socketRect), with: .color(Color.black.opacity(0.88)))
            context.stroke(RoundedRectangle(cornerRadius: 4).path(in: socketRect), with: .color(Color(white: 0.3)), lineWidth: 1.0)

            // Subtle non-obscuring digital scan line
            var scan = Path()
            let scanY = (eyeY - 6) + CGFloat(fmod(snapshot.time * 8.0, 12.0))
            scan.move(to: CGPoint(x: center.x - 15, y: scanY))
            scan.addLine(to: CGPoint(x: center.x + 15, y: scanY))
            let scanColor = (isGrayscale ? Color.white : (species == .robotcat ? Color.green : Color.cyan)).opacity(0.2)
            context.stroke(scan, with: .color(scanColor), lineWidth: 1.0)

            let ledColor = isGrayscale ? Color.white : (species == .robotcat ? Color.green : Color.cyan)

            if isClosed {
                // Dimmed horizontal LED slit during blink/sleep
                let lSlit = Rectangle().path(in: CGRect(x: leftEyeX - 3.5, y: gazeY - 0.75, width: 7, height: 1.5))
                let rSlit = Rectangle().path(in: CGRect(x: rightEyeX - 3.5, y: gazeY - 0.75, width: 7, height: 1.5))
                context.fill(lSlit, with: .color(ledColor.opacity(0.4)))
                context.fill(rSlit, with: .color(ledColor.opacity(0.4)))
            } else {
                // Two clearly visible glowing LED eyes: ●  ●
                let openHeight = animState == .shock ? layout.eyeHeight * 1.25 : layout.eyeHeight
                let h = max(2.0, openHeight * (1.0 - snapshot.blinkProgress))
                let w = layout.eyeWidth

                let lEye = RoundedRectangle(cornerRadius: 3).path(in: CGRect(x: leftEyeX - w/2, y: gazeY - h/2, width: w, height: h))
                let rEye = RoundedRectangle(cornerRadius: 3).path(in: CGRect(x: rightEyeX - w/2, y: gazeY - h/2, width: w, height: h))

                // Soft outer LED halo
                context.fill(lEye, with: .color(ledColor.opacity(0.35)))
                context.fill(rEye, with: .color(ledColor.opacity(0.35)))

                // Crisp vibrant LED core
                let lCore = RoundedRectangle(cornerRadius: 2).path(in: CGRect(x: leftEyeX - (w - 2)/2, y: gazeY - (h - 2)/2, width: w - 2, height: max(1.5, h - 2)))
                let rCore = RoundedRectangle(cornerRadius: 2).path(in: CGRect(x: rightEyeX - (w - 2)/2, y: gazeY - (h - 2)/2, width: w - 2, height: max(1.5, h - 2)))
                context.fill(lCore, with: .color(ledColor))
                context.fill(rCore, with: .color(ledColor))

                // Highlight pixel
                if h > 3 {
                    let lPixel = Rectangle().path(in: CGRect(x: leftEyeX - 1.5, y: gazeY - 2, width: 2, height: 2))
                    let rPixel = Rectangle().path(in: CGRect(x: rightEyeX - 1.5, y: gazeY - 2, width: 2, height: 2))
                    context.fill(lPixel, with: .color(Color.white))
                    context.fill(rPixel, with: .color(Color.white))
                }
            }

        case .spectral:
            if isClosed {
                var lArc = Path()
                lArc.addArc(center: CGPoint(x: leftEyeX, y: eyeY), radius: 4.5, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                context.stroke(lArc, with: .color(Color(white: 0.15)), lineWidth: 2.0)

                var rArc = Path()
                rArc.addArc(center: CGPoint(x: rightEyeX, y: eyeY), radius: 4.5, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                context.stroke(rArc, with: .color(Color(white: 0.15)), lineWidth: 2.0)
            } else {
                let openHeight = animState == .shock ? layout.eyeHeight * 1.3 : layout.eyeHeight
                let h = max(1.5, openHeight * (1.0 - snapshot.blinkProgress))
                let w = layout.eyeWidth

                let lEye = Ellipse().path(in: CGRect(x: leftEyeX - w/2, y: gazeY - h/2, width: w, height: h))
                let rEye = Ellipse().path(in: CGRect(x: rightEyeX - w/2, y: gazeY - h/2, width: w, height: h))
                context.fill(lEye, with: .color(Color(white: 0.12)))
                context.fill(rEye, with: .color(Color(white: 0.12)))

                // Inner spectral blue-cyan glow
                if !isGrayscale && h > 4 {
                    let lGlow = Ellipse().path(in: CGRect(x: leftEyeX - (w - 3)/2, y: gazeY - (h - 3)/2, width: w - 3, height: h - 3))
                    let rGlow = Ellipse().path(in: CGRect(x: rightEyeX - (w - 3)/2, y: gazeY - (h - 3)/2, width: w - 3, height: h - 3))
                    context.fill(lGlow, with: .color(Color.cyan.opacity(0.25)))
                    context.fill(rGlow, with: .color(Color.cyan.opacity(0.25)))
                }

                if h > 3.5 {
                    let lSpark = Circle().path(in: CGRect(x: leftEyeX - 1.5, y: gazeY - 2.5, width: 3, height: 3))
                    let rSpark = Circle().path(in: CGRect(x: rightEyeX - 1.5, y: gazeY - 2.5, width: 3, height: 3))
                    context.fill(lSpark, with: .color(Color.white))
                    context.fill(rSpark, with: .color(Color.white))
                }
            }

        case .reptilian:
            if isClosed {
                var lArc = Path()
                lArc.addArc(center: CGPoint(x: leftEyeX, y: eyeY), radius: 4.5, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                context.stroke(lArc, with: .color(Color(white: 0.15)), lineWidth: 2.0)

                var rArc = Path()
                rArc.addArc(center: CGPoint(x: rightEyeX, y: eyeY), radius: 4.5, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                context.stroke(rArc, with: .color(Color(white: 0.15)), lineWidth: 2.0)
            } else {
                let openHeight = animState == .shock ? layout.eyeHeight * 1.25 : layout.eyeHeight
                let h = max(1.5, openHeight * (1.0 - snapshot.blinkProgress))
                let w = layout.eyeWidth

                // Amber / Gold iris
                let lIris = Ellipse().path(in: CGRect(x: leftEyeX - w/2, y: gazeY - h/2, width: w, height: h))
                let rIris = Ellipse().path(in: CGRect(x: rightEyeX - w/2, y: gazeY - h/2, width: w, height: h))
                context.fill(lIris, with: .color(isGrayscale ? Color.white : Color(red: 1.0, green: 0.72, blue: 0.18)))
                context.stroke(lIris, with: .color(Color(white: 0.15)), lineWidth: 1.0)
                context.stroke(rIris, with: .color(Color(white: 0.15)), lineWidth: 1.0)

                // Vertical slit pupil
                if h > 2.5 {
                    let pupilW: CGFloat = animState == .shock ? 3.0 : 1.8
                    let lPupil = Capsule().path(in: CGRect(x: leftEyeX - pupilW/2, y: gazeY - (h - 2)/2, width: pupilW, height: max(1.5, h - 2)))
                    let rPupil = Capsule().path(in: CGRect(x: rightEyeX - pupilW/2, y: gazeY - (h - 2)/2, width: pupilW, height: max(1.5, h - 2)))
                    context.fill(lPupil, with: .color(Color(white: 0.08)))
                    context.fill(rPupil, with: .color(Color(white: 0.08)))

                    let lGleam = Circle().path(in: CGRect(x: leftEyeX - 1.5, y: gazeY - 2.5, width: 2.5, height: 2.5))
                    let rGleam = Circle().path(in: CGRect(x: rightEyeX - 1.5, y: gazeY - 2.5, width: 2.5, height: 2.5))
                    context.fill(lGleam, with: .color(Color.white.opacity(0.85)))
                    context.fill(rGleam, with: .color(Color.white.opacity(0.85)))
                }
            }

        case .standard:
            if isClosed {
                var lArc = Path()
                lArc.addArc(center: CGPoint(x: leftEyeX, y: eyeY), radius: 4.5, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                context.stroke(lArc, with: .color(Color(white: 0.15)), lineWidth: 2.2)

                var rArc = Path()
                rArc.addArc(center: CGPoint(x: rightEyeX, y: eyeY), radius: 4.5, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                context.stroke(rArc, with: .color(Color(white: 0.15)), lineWidth: 2.2)
            } else {
                let openHeight = animState == .shock ? layout.eyeHeight * 1.3 : layout.eyeHeight
                let h = max(1.5, openHeight * (1.0 - snapshot.blinkProgress))
                let w = layout.eyeWidth

                let lEye = Ellipse().path(in: CGRect(x: leftEyeX - w/2, y: gazeY - h/2, width: w, height: h))
                let rEye = Ellipse().path(in: CGRect(x: rightEyeX - w/2, y: gazeY - h/2, width: w, height: h))

                context.fill(lEye, with: .color(Color(white: 0.12)))
                context.fill(rEye, with: .color(Color(white: 0.12)))

                // Specular gleams for expressive kawaii eyes
                if h > 4 {
                    let lSpark = Circle().path(in: CGRect(x: leftEyeX - 2, y: gazeY - 3, width: 3.2, height: 3.2))
                    let rSpark = Circle().path(in: CGRect(x: rightEyeX - 2, y: gazeY - 3, width: 3.2, height: 3.2))
                    context.fill(lSpark, with: .color(Color.white))
                    context.fill(rSpark, with: .color(Color.white))

                    let lSub = Circle().path(in: CGRect(x: leftEyeX + 1, y: gazeY + 1, width: 1.6, height: 1.6))
                    let rSub = Circle().path(in: CGRect(x: rightEyeX + 1, y: gazeY + 1, width: 1.6, height: 1.6))
                    context.fill(lSub, with: .color(Color.white.opacity(0.8)))
                    context.fill(rSub, with: .color(Color.white.opacity(0.8)))
                }
            }
        }
    }

    private static func drawCharacterNose(
        context: inout GraphicsContext,
        center: CGPoint,
        species: PetSpecies,
        layout: CharacterFaceLayout,
        isGrayscale: Bool
    ) {
        guard let nY = layout.noseOffsetY else { return }
        let noseY = center.y + nY

        switch species {
        case .bunny:
            // Soft pink triangle nose
            var nose = Path()
            nose.move(to: CGPoint(x: center.x - 3, y: noseY - 1.5))
            nose.addLine(to: CGPoint(x: center.x + 3, y: noseY - 1.5))
            nose.addLine(to: CGPoint(x: center.x, y: noseY + 2))
            nose.closeSubpath()
            context.fill(nose, with: .color(isGrayscale ? Color(white: 0.25) : Color(red: 1.0, green: 0.55, blue: 0.65)))

        case .cat:
            // Tiny inverted pink/dark triangle nose
            var nose = Path()
            nose.move(to: CGPoint(x: center.x - 2.5, y: noseY - 1))
            nose.addLine(to: CGPoint(x: center.x + 2.5, y: noseY - 1))
            nose.addLine(to: CGPoint(x: center.x, y: noseY + 1.8))
            nose.closeSubpath()
            context.fill(nose, with: .color(isGrayscale ? Color(white: 0.2) : Color(red: 0.95, green: 0.5, blue: 0.6)))

        case .dragon:
            // Two dark nostril dots on snout
            let lNostril = Circle().path(in: CGRect(x: center.x - 3.5, y: noseY - 1, width: 2, height: 2))
            let rNostril = Circle().path(in: CGRect(x: center.x + 1.5, y: noseY - 1, width: 2, height: 2))
            context.fill(lNostril, with: .color(Color(white: 0.15)))
            context.fill(rNostril, with: .color(Color(white: 0.15)))

        case .robotcat:
            // Metallic sensor bar
            let bar = RoundedRectangle(cornerRadius: 1).path(in: CGRect(x: center.x - 2.5, y: noseY - 1, width: 5, height: 2))
            context.fill(bar, with: .color(isGrayscale ? Color.white : Color.green.opacity(0.8)))

        case .fox:
            // Black glossy nose on snout tip
            let nose = Circle().path(in: CGRect(x: center.x - 2.5, y: noseY - 2.5, width: 5, height: 5))
            context.fill(nose, with: .color(Color.black))

        default:
            break
        }
    }

    private static func drawCharacterMouth(
        context: inout GraphicsContext,
        center: CGPoint,
        species: PetSpecies,
        layout: CharacterFaceLayout,
        animState: PetAnimState,
        snapshot: AnimationSnapshot,
        isGrayscale: Bool
    ) {
        let mouthY = center.y + layout.mouthOffsetY
        let halfW = layout.mouthWidth / 2

        if layout.eyeStyle == .led {
            // Digital LED smile or segmented line
            var ledMouth = Path()
            ledMouth.move(to: CGPoint(x: center.x - halfW, y: mouthY))
            ledMouth.addQuadCurve(to: CGPoint(x: center.x + halfW, y: mouthY), control: CGPoint(x: center.x, y: mouthY + 2.5))
            let mColor = isGrayscale ? Color.white : (species == .robotcat ? Color.green : Color.cyan)
            context.stroke(ledMouth, with: .color(mColor), lineWidth: 1.6)
            return
        }

        if animState == .shock {
            let oMouth = Ellipse().path(in: CGRect(x: center.x - 3.5, y: mouthY - 3, width: 7, height: 8))
            context.fill(oMouth, with: .color(Color(white: 0.12)))
            return
        }

        var mouth = Path()
        if species == .bunny || species == .cat {
            // Kawaii W-mouth (3-shaped)
            mouth.move(to: CGPoint(x: center.x - halfW, y: mouthY - 1))
            mouth.addQuadCurve(to: CGPoint(x: center.x, y: mouthY), control: CGPoint(x: center.x - halfW/2, y: mouthY + 2.5))
            mouth.addQuadCurve(to: CGPoint(x: center.x + halfW, y: mouthY - 1), control: CGPoint(x: center.x + halfW/2, y: mouthY + 2.5))
        } else {
            // Sweet smiling curve
            mouth.move(to: CGPoint(x: center.x - halfW, y: mouthY))
            mouth.addQuadCurve(to: CGPoint(x: center.x + halfW, y: mouthY), control: CGPoint(x: center.x, y: mouthY + 3.0))
        }
        context.stroke(mouth, with: .color(Color(white: 0.18)), lineWidth: 1.8)
    }

    private static func drawBlush(
        context: inout GraphicsContext,
        center: CGPoint,
        layout: CharacterFaceLayout,
        isGrayscale: Bool
    ) {
        guard layout.hasBlush && !isGrayscale else { return }
        let blushY = center.y + layout.blushOffsetY
        let lBlush = Ellipse().path(in: CGRect(x: center.x - layout.blushSpacing - 4, y: blushY - 2.5, width: 8, height: 5))
        let rBlush = Ellipse().path(in: CGRect(x: center.x + layout.blushSpacing - 4, y: blushY - 2.5, width: 8, height: 5))
        context.fill(lBlush, with: .color(Color.pink.opacity(0.35)))
        context.fill(rBlush, with: .color(Color.pink.opacity(0.35)))
    }

    // MARK: - Layer 4 & 5: Optional Particles & Weather Overlay

    private static func drawParticles(context: inout GraphicsContext, size: CGSize, snapshot: AnimationSnapshot) {
        for spark in snapshot.thoughtSparks {
            let path = Circle().path(in: CGRect(x: spark.x - spark.size/2, y: spark.y - spark.size/2, width: spark.size, height: spark.size))
            context.fill(path, with: .color(Color(hue: spark.hue, saturation: 0.8, brightness: 1.0).opacity(spark.alpha)))
        }

        for conf in snapshot.confettiList {
            var confCtx = context
            confCtx.translateBy(x: conf.x, y: conf.y)
            confCtx.rotate(by: .degrees(conf.rotation))
            let r = CGRect(x: -conf.size.width/2, y: -conf.size.height/2, width: conf.size.width, height: conf.size.height)
            confCtx.fill(Rectangle().path(in: r), with: .color(conf.color.opacity(conf.alpha)))
        }
    }

    private static func drawWeatherOverlay(context: inout GraphicsContext, snapshot: AnimationSnapshot) {
        for p in snapshot.weatherParticles {
            if p.length > 0 {
                // Rain streak
                var rain = Path()
                rain.move(to: CGPoint(x: p.x, y: p.y))
                rain.addLine(to: CGPoint(x: p.x - 2, y: p.y + p.length))
                context.stroke(rain, with: .color(Color.cyan.opacity(p.alpha)), lineWidth: p.size)
            } else {
                // Snow flake
                let flake = Circle().path(in: CGRect(x: p.x - p.size/2, y: p.y - p.size/2, width: p.size, height: p.size))
                context.fill(flake, with: .color(Color.white.opacity(p.alpha)))
            }
        }
    }
}
