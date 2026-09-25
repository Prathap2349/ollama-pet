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
        mood: PetMood = .happy,
        snapshot: AnimationSnapshot,
        perf: PerformanceManager
    ) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        // 1. LAYER 1: AURA (Optional, low cost)
        if !perf.isSafeMode && (perf.dynamicLightingEnabled || perf.cpuReactiveGlowEnabled) && !perf.grayscaleTestMode {
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
            mood: mood,
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
            mood: mood,
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
        mood: PetMood = .happy,
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
            // DRAGON (Ember): Fantasy dragon silhouette with large wings, horned dragon head, glowing chest core, claws, spade tail
            drawDragonAnatomy(context: &context, center: center, primary: primaryColor, secondary: secondaryColor, mood: mood, snapshot: snapshot)

        case .robot:
            // ROBOT (ARIA): Mechanical rectangular head and torso, antenna, articulated limbs with joints, chest core (NOT an animal body!)
            drawRobotAnatomy(context: &context, center: center, primary: primaryColor, snapshot: snapshot)

        case .robotcat:
            // ROBOT CAT (NEO): Hybrid with cat ears, robotic face plate, cyber panel body, segmented tail
            drawRobotCatAnatomy(context: &context, center: center, primary: primaryColor, secondary: secondaryColor, snapshot: snapshot)

        case .ghost:
            // GHOST (Boo): NO LEGS AT ALL! Floating body, wavy lower sheet/skirt, small arms, floating wave
            drawGhostAnatomy(context: &context, center: center, primary: primaryColor, mood: mood, snapshot: snapshot)

        case .fox:
            // FOX (Kita): Pointed ears with dark rims, elongated muzzle, fox ruff, 4 legs, giant fluffy tail
            drawFoxAnatomy(context: &context, center: center, primary: primaryColor, secondary: secondaryColor, snapshot: snapshot)

        case .bunny:
            // BUNNY (Pochi): Very tall ears, chubby round body, short front paws, large hind hopping legs, cotton puff tail
            drawBunnyAnatomy(context: &context, center: center, primary: primaryColor, mood: mood, snapshot: snapshot)
        }
    }

    // MARK: - Species Anatomy Implementations (Distinct Silhouettes)

    // 1. CAT — MOCHI
    private static func drawCatAnatomy(context: inout GraphicsContext, center: CGPoint, primary: Color, belly: Color, snapshot: AnimationSnapshot) {
        let earTwitch = CGFloat(snapshot.earTwitchAngle.degrees * 0.4)

        // Long curved cat tail with dynamic wag
        var tail = Path()
        let tailEnd = CGPoint(x: center.x - 34 + CGFloat(snapshot.tailWagAngle.degrees * 0.6), y: center.y - 6)
        tail.move(to: CGPoint(x: center.x - 22, y: center.y + 16))
        tail.addQuadCurve(to: tailEnd, control: CGPoint(x: center.x - 40, y: center.y + 20))
        context.stroke(tail, with: .color(primary), lineWidth: 5.0)

        // Body (feline sitting posture)
        let bodyRect = CGRect(x: center.x - 26, y: center.y - 12, width: 52, height: 42)
        context.fill(RoundedRectangle(cornerRadius: 18).path(in: bodyRect), with: .color(primary))

        // Belly patch
        let bellyRect = CGRect(x: center.x - 14, y: center.y - 4, width: 28, height: 26)
        context.fill(Ellipse().path(in: bellyRect), with: .color(belly))

        // Head (compact feline head)
        let headRect = CGRect(x: center.x - 22, y: center.y - 34, width: 44, height: 34)
        context.fill(RoundedRectangle(cornerRadius: 16).path(in: headRect), with: .color(primary))

        // Triangular Upright Cat Ears (with inner pink & twitch)
        var lEar = Path()
        lEar.move(to: CGPoint(x: center.x - 20, y: center.y - 30))
        lEar.addLine(to: CGPoint(x: center.x - 26 + earTwitch, y: center.y - 48))
        lEar.addLine(to: CGPoint(x: center.x - 10, y: center.y - 32))
        lEar.closeSubpath()
        context.fill(lEar, with: .color(primary))

        var lInner = Path()
        lInner.move(to: CGPoint(x: center.x - 19, y: center.y - 31))
        lInner.addLine(to: CGPoint(x: center.x - 24 + earTwitch, y: center.y - 44))
        lInner.addLine(to: CGPoint(x: center.x - 12, y: center.y - 32))
        lInner.closeSubpath()
        context.fill(lInner, with: .color(Color.pink.opacity(0.45)))

        var rEar = Path()
        rEar.move(to: CGPoint(x: center.x + 10, y: center.y - 32))
        rEar.addLine(to: CGPoint(x: center.x + 26 - earTwitch, y: center.y - 48))
        rEar.addLine(to: CGPoint(x: center.x + 20, y: center.y - 30))
        rEar.closeSubpath()
        context.fill(rEar, with: .color(primary))

        var rInner = Path()
        rInner.move(to: CGPoint(x: center.x + 12, y: center.y - 32))
        rInner.addLine(to: CGPoint(x: center.x + 24 - earTwitch, y: center.y - 44))
        rInner.addLine(to: CGPoint(x: center.x + 19, y: center.y - 31))
        rInner.closeSubpath()
        context.fill(rInner, with: .color(Color.pink.opacity(0.45)))

        // Whiskers (3 left, 3 right)
        var whiskers = Path()
        whiskers.move(to: CGPoint(x: center.x - 16, y: center.y - 12))
        whiskers.addLine(to: CGPoint(x: center.x - 32, y: center.y - 14))
        whiskers.move(to: CGPoint(x: center.x - 16, y: center.y - 10))
        whiskers.addLine(to: CGPoint(x: center.x - 33, y: center.y - 10))
        whiskers.move(to: CGPoint(x: center.x - 16, y: center.y - 8))
        whiskers.addLine(to: CGPoint(x: center.x - 31, y: center.y - 6))

        whiskers.move(to: CGPoint(x: center.x + 16, y: center.y - 12))
        whiskers.addLine(to: CGPoint(x: center.x + 32, y: center.y - 14))
        whiskers.move(to: CGPoint(x: center.x + 16, y: center.y - 10))
        whiskers.addLine(to: CGPoint(x: center.x + 33, y: center.y - 10))
        whiskers.move(to: CGPoint(x: center.x + 16, y: center.y - 8))
        whiskers.addLine(to: CGPoint(x: center.x + 31, y: center.y - 6))
        context.stroke(whiskers, with: .color(Color.white.opacity(0.65)), lineWidth: 1.2)

        // Short front feline paws
        let pawY = center.y + 22 + snapshot.pawOffset * 0.4
        let lPaw = Capsule().path(in: CGRect(x: center.x - 18, y: pawY, width: 12, height: 10))
        let rPaw = Capsule().path(in: CGRect(x: center.x + 6, y: pawY, width: 12, height: 10))
        context.fill(lPaw, with: .color(primary.opacity(0.95)))
        context.fill(rPaw, with: .color(primary.opacity(0.95)))
    }

    // 2. DRAGON — EMBER (Distinct from cat: Horns, wings, elongated snout, claws, spade tail)
    // 2. DRAGON — EMBER (Full Fantasy Dragon Silhouette: Sweeping Horns, Obvious Wings, Glowing Chest Core, 4 Claws, Sinuous Spade Tail)
    private static func drawDragonAnatomy(context: inout GraphicsContext, center: CGPoint, primary: Color, secondary: Color, mood: PetMood, snapshot: AnimationSnapshot) {
        // Dynamic color palette based on mood
        let bodyColor: Color
        let wingColor: Color
        let hornColor: Color
        let coreColor: Color

        switch mood {
        case .happy:
            bodyColor = Color(red: 0.86, green: 0.28, blue: 0.12)
            wingColor = Color(red: 0.98, green: 0.58, blue: 0.16)
            hornColor = Color(red: 1.0, green: 0.82, blue: 0.28)
            coreColor = Color(red: 1.0, green: 0.90, blue: 0.40)
        case .excited:
            bodyColor = Color(red: 0.95, green: 0.26, blue: 0.08)
            wingColor = Color(red: 1.0, green: 0.50, blue: 0.10)
            hornColor = Color(red: 1.0, green: 0.86, blue: 0.25)
            coreColor = Color(red: 1.0, green: 0.95, blue: 0.50)
        case .angry:
            bodyColor = Color(red: 0.65, green: 0.08, blue: 0.08)
            wingColor = Color(red: 0.85, green: 0.18, blue: 0.08)
            hornColor = Color(red: 0.45, green: 0.08, blue: 0.08)
            coreColor = Color(red: 1.0, green: 0.35, blue: 0.10)
        case .sleepy:
            bodyColor = Color(red: 0.45, green: 0.12, blue: 0.25)
            wingColor = Color(red: 0.35, green: 0.10, blue: 0.30)
            hornColor = Color(red: 0.55, green: 0.35, blue: 0.45)
            coreColor = Color(red: 0.60, green: 0.30, blue: 0.40).opacity(0.5)
        case .proud:
            bodyColor = Color(red: 0.78, green: 0.16, blue: 0.12)
            wingColor = Color(red: 0.96, green: 0.60, blue: 0.15)
            hornColor = Color(red: 1.0, green: 0.85, blue: 0.22)
            coreColor = Color(red: 1.0, green: 0.90, blue: 0.30)
        default:
            bodyColor = Color(red: 0.74, green: 0.16, blue: 0.12) // deep crimson
            wingColor = Color(red: 0.92, green: 0.46, blue: 0.14) // warm amber orange
            hornColor = Color(red: 0.96, green: 0.74, blue: 0.22) // warm gold
            coreColor = Color(red: 1.0, green: 0.78, blue: 0.22)
        }

        // 1. Two Large Obvious Dragon Wings (Behind body, with finger ribs & scalloped membrane)
        let wingSpan = CGFloat(snapshot.wingFlapAngle.degrees * 0.55)
        
        // Left Wing
        var lWing = Path()
        let lElbow = CGPoint(x: center.x - 22, y: center.y - 20)
        let lTip1 = CGPoint(x: center.x - 52, y: center.y - 44 + wingSpan)
        let lTip2 = CGPoint(x: center.x - 48, y: center.y - 24 + wingSpan * 0.7)
        let lTip3 = CGPoint(x: center.x - 34, y: center.y - 8 + wingSpan * 0.4)
        lWing.move(to: CGPoint(x: center.x - 14, y: center.y - 6))
        lWing.addLine(to: lElbow)
        lWing.addLine(to: lTip1)
        lWing.addQuadCurve(to: lTip2, control: CGPoint(x: center.x - 42, y: center.y - 32 + wingSpan * 0.8))
        lWing.addQuadCurve(to: lTip3, control: CGPoint(x: center.x - 38, y: center.y - 14 + wingSpan * 0.5))
        lWing.addQuadCurve(to: CGPoint(x: center.x - 18, y: center.y + 6), control: CGPoint(x: center.x - 24, y: center.y))
        lWing.closeSubpath()
        context.fill(lWing, with: .color(wingColor.opacity(0.88)))
        context.stroke(lWing, with: .color(hornColor.opacity(0.6)), lineWidth: 1.2)

        // Wing Struts / Bones (Left)
        var lStruts = Path()
        lStruts.move(to: lElbow)
        lStruts.addLine(to: lTip1)
        lStruts.move(to: lElbow)
        lStruts.addLine(to: lTip2)
        lStruts.move(to: lElbow)
        lStruts.addLine(to: lTip3)
        context.stroke(lStruts, with: .color(bodyColor), lineWidth: 1.5)

        // Right Wing
        var rWing = Path()
        let rElbow = CGPoint(x: center.x + 22, y: center.y - 20)
        let rTip1 = CGPoint(x: center.x + 52, y: center.y - 44 + wingSpan)
        let rTip2 = CGPoint(x: center.x + 48, y: center.y - 24 + wingSpan * 0.7)
        let rTip3 = CGPoint(x: center.x + 34, y: center.y - 8 + wingSpan * 0.4)
        rWing.move(to: CGPoint(x: center.x + 14, y: center.y - 6))
        rWing.addLine(to: rElbow)
        rWing.addLine(to: rTip1)
        rWing.addQuadCurve(to: rTip2, control: CGPoint(x: center.x + 42, y: center.y - 32 + wingSpan * 0.8))
        rWing.addQuadCurve(to: rTip3, control: CGPoint(x: center.x + 38, y: center.y - 14 + wingSpan * 0.5))
        rWing.addQuadCurve(to: CGPoint(x: center.x + 18, y: center.y + 6), control: CGPoint(x: center.x + 24, y: center.y))
        rWing.closeSubpath()
        context.fill(rWing, with: .color(wingColor.opacity(0.88)))
        context.stroke(rWing, with: .color(hornColor.opacity(0.6)), lineWidth: 1.2)

        // Wing Struts / Bones (Right)
        var rStruts = Path()
        rStruts.move(to: rElbow)
        rStruts.addLine(to: rTip1)
        rStruts.move(to: rElbow)
        rStruts.addLine(to: rTip2)
        rStruts.move(to: rElbow)
        rStruts.addLine(to: rTip3)
        context.stroke(rStruts, with: .color(bodyColor), lineWidth: 1.5)

        // 2. Long Sinuous Dragon Tail with 3-Pointed Flame/Spade Tip
        var tail = Path()
        let tailTip = CGPoint(x: center.x - 42 + CGFloat(snapshot.tailWagAngle.degrees * 0.45), y: center.y + 6)
        tail.move(to: CGPoint(x: center.x - 22, y: center.y + 20))
        tail.addCurve(to: tailTip,
                      control1: CGPoint(x: center.x - 44, y: center.y + 32),
                      control2: CGPoint(x: center.x - 52, y: center.y + 14))
        context.stroke(tail, with: .color(bodyColor), lineWidth: 6.5)

        // Dragon Spade / Flame at tail tip
        var spade = Path()
        spade.move(to: tailTip)
        spade.addLine(to: CGPoint(x: tailTip.x - 12, y: tailTip.y - 8))
        spade.addLine(to: CGPoint(x: tailTip.x - 7, y: tailTip.y))
        spade.addLine(to: CGPoint(x: tailTip.x - 14, y: tailTip.y + 8))
        spade.addLine(to: CGPoint(x: tailTip.x - 2, y: tailTip.y + 4))
        spade.closeSubpath()
        context.fill(spade, with: .color(hornColor))
        context.stroke(spade, with: .color(wingColor), lineWidth: 1.2)

        // 3. Robust Fantasy Dragon Body (Muscular, compact torso)
        let bodyRect = CGRect(x: center.x - 26, y: center.y - 12, width: 52, height: 38)
        context.fill(RoundedRectangle(cornerRadius: 16).path(in: bodyRect), with: .color(bodyColor))

        // 4. Segmented Dragon Ventral Belly Plates (Warm golden amber scutes)
        for i in 0..<4 {
            let scuteY = center.y - 2 + CGFloat(i * 7)
            let scuteWidth: CGFloat = CGFloat(24 - i * 2)
            let scuteRect = CGRect(x: center.x - scuteWidth / 2, y: scuteY, width: scuteWidth, height: 5.5)
            context.fill(RoundedRectangle(cornerRadius: 3).path(in: scuteRect), with: .color(hornColor.opacity(0.85)))
            context.stroke(RoundedRectangle(cornerRadius: 3).path(in: scuteRect), with: .color(Color.black.opacity(0.15)), lineWidth: 0.8)
        }

        // 5. Glowing Ember Chest Core (Radiant Diamond)
        let coreY = center.y - 4
        var coreDiamond = Path()
        coreDiamond.move(to: CGPoint(x: center.x, y: coreY - 6))
        coreDiamond.addLine(to: CGPoint(x: center.x + 6, y: coreY))
        coreDiamond.addLine(to: CGPoint(x: center.x, y: coreY + 6))
        coreDiamond.addLine(to: CGPoint(x: center.x - 6, y: coreY))
        coreDiamond.closeSubpath()
        context.fill(coreDiamond, with: .color(coreColor))
        // Ambient core glow
        let coreGlow = Circle().path(in: CGRect(x: center.x - 10, y: coreY - 10, width: 20, height: 20))
        context.fill(coreGlow, with: .color(coreColor.opacity(0.35)))

        // 6. Arched Dragon Neck & Sculpted Dragon Head
        var neck = Path()
        neck.move(to: CGPoint(x: center.x - 15, y: center.y - 8))
        neck.addLine(to: CGPoint(x: center.x - 18, y: center.y - 28))
        neck.addLine(to: CGPoint(x: center.x + 18, y: center.y - 28))
        neck.addLine(to: CGPoint(x: center.x + 15, y: center.y - 8))
        neck.closeSubpath()
        context.fill(neck, with: .color(bodyColor))

        // Sculpted Dragon Head (Slightly larger head for expressive fantasy dragon silhouette)
        let headRect = CGRect(x: center.x - 24, y: center.y - 40, width: 48, height: 30)
        context.fill(RoundedRectangle(cornerRadius: 13).path(in: headRect), with: .color(bodyColor))

        // Elongated Dragon Snout & Muzzle
        let snoutRect = CGRect(x: center.x - 15, y: center.y - 23, width: 30, height: 14)
        context.fill(RoundedRectangle(cornerRadius: 7).path(in: snoutRect), with: .color(bodyColor))

        // Dragon Nostrils
        let lNostril = Ellipse().path(in: CGRect(x: center.x - 8, y: center.y - 15, width: 3, height: 2.5))
        let rNostril = Ellipse().path(in: CGRect(x: center.x + 5, y: center.y - 15, width: 3, height: 2.5))
        context.fill(lNostril, with: .color(Color.black.opacity(0.6)))
        context.fill(rNostril, with: .color(Color.black.opacity(0.6)))

        // 7. Sweeping Dragon Horns (Curving backward & upward with golden ridge stripes)
        var lHorn = Path()
        lHorn.move(to: CGPoint(x: center.x - 16, y: center.y - 34))
        lHorn.addCurve(to: CGPoint(x: center.x - 34, y: center.y - 58),
                       control1: CGPoint(x: center.x - 26, y: center.y - 42),
                       control2: CGPoint(x: center.x - 36, y: center.y - 50))
        lHorn.addCurve(to: CGPoint(x: center.x - 8, y: center.y - 36),
                       control1: CGPoint(x: center.x - 28, y: center.y - 52),
                       control2: CGPoint(x: center.x - 14, y: center.y - 44))
        lHorn.closeSubpath()
        context.fill(lHorn, with: .color(hornColor))
        context.stroke(lHorn, with: .color(Color(white: 0.15)), lineWidth: 1.0)

        var rHorn = Path()
        rHorn.move(to: CGPoint(x: center.x + 8, y: center.y - 36))
        rHorn.addCurve(to: CGPoint(x: center.x + 34, y: center.y - 58),
                       control1: CGPoint(x: center.x + 14, y: center.y - 44),
                       control2: CGPoint(x: center.x + 28, y: center.y - 52))
        rHorn.addCurve(to: CGPoint(x: center.x + 16, y: center.y - 34),
                       control1: CGPoint(x: center.x + 36, y: center.y - 50),
                       control2: CGPoint(x: center.x + 26, y: center.y - 42))
        rHorn.closeSubpath()
        context.fill(rHorn, with: .color(hornColor))
        context.stroke(rHorn, with: .color(Color(white: 0.15)), lineWidth: 1.0)

        // Smaller cheek frills/horns
        var lFrill = Path()
        lFrill.move(to: CGPoint(x: center.x - 20, y: center.y - 24))
        lFrill.addLine(to: CGPoint(x: center.x - 30, y: center.y - 26))
        lFrill.addLine(to: CGPoint(x: center.x - 22, y: center.y - 18))
        lFrill.closeSubpath()
        context.fill(lFrill, with: .color(hornColor.opacity(0.85)))

        var rFrill = Path()
        rFrill.move(to: CGPoint(x: center.x + 20, y: center.y - 24))
        rFrill.addLine(to: CGPoint(x: center.x + 30, y: center.y - 26))
        rFrill.addLine(to: CGPoint(x: center.x + 22, y: center.y - 18))
        rFrill.closeSubpath()
        context.fill(rFrill, with: .color(hornColor.opacity(0.85)))

        // 8. Dorsal Spine Spikes along spine
        for i in 0..<3 {
            let sx = center.x - 8 + CGFloat(i * 8)
            var spike = Path()
            spike.move(to: CGPoint(x: sx - 3, y: center.y - 14))
            spike.addLine(to: CGPoint(x: sx, y: center.y - 22))
            spike.addLine(to: CGPoint(x: sx + 3, y: center.y - 14))
            spike.closeSubpath()
            context.fill(spike, with: .color(hornColor))
        }

        // 9. Four Limbs with Integrated Dragon Talons
        // Front Forearms & Claws
        let pawY = center.y + 16 + snapshot.pawOffset * 0.35
        let lForearm = RoundedRectangle(cornerRadius: 3).path(in: CGRect(x: center.x - 22, y: pawY, width: 11, height: 12))
        let rForearm = RoundedRectangle(cornerRadius: 3).path(in: CGRect(x: center.x + 11, y: pawY, width: 11, height: 12))
        context.fill(lForearm, with: .color(bodyColor))
        context.fill(rForearm, with: .color(bodyColor))

        // Integrated sharp talons (curved triangular dragon claws)
        for i in 0..<3 {
            let lx = center.x - 22 + CGFloat(i) * 3.5
            let rx = center.x + 12 + CGFloat(i) * 3.5
            var lTalon = Path()
            lTalon.move(to: CGPoint(x: lx, y: pawY + 11))
            lTalon.addLine(to: CGPoint(x: lx + 1.5, y: pawY + 16))
            lTalon.addLine(to: CGPoint(x: lx + 3, y: pawY + 11))
            lTalon.closeSubpath()
            context.fill(lTalon, with: .color(hornColor))
            context.stroke(lTalon, with: .color(Color.black.opacity(0.5)), lineWidth: 0.8)

            var rTalon = Path()
            rTalon.move(to: CGPoint(x: rx, y: pawY + 11))
            rTalon.addLine(to: CGPoint(x: rx + 1.5, y: pawY + 16))
            rTalon.addLine(to: CGPoint(x: rx + 3, y: pawY + 11))
            rTalon.closeSubpath()
            context.fill(rTalon, with: .color(hornColor))
            context.stroke(rTalon, with: .color(Color.black.opacity(0.5)), lineWidth: 0.8)
        }

        // Rear Crouching Haunches with Hind Claws
        let lHaunch = Capsule().path(in: CGRect(x: center.x - 28, y: center.y + 18, width: 13, height: 14))
        let rHaunch = Capsule().path(in: CGRect(x: center.x + 15, y: center.y + 18, width: 13, height: 14))
        context.fill(lHaunch, with: .color(bodyColor.opacity(0.95)))
        context.fill(rHaunch, with: .color(bodyColor.opacity(0.95)))

        var lRearClaw = Path()
        lRearClaw.move(to: CGPoint(x: center.x - 27, y: center.y + 30))
        lRearClaw.addLine(to: CGPoint(x: center.x - 24, y: center.y + 34))
        lRearClaw.addLine(to: CGPoint(x: center.x - 21, y: center.y + 30))
        lRearClaw.closeSubpath()
        context.fill(lRearClaw, with: .color(hornColor))

        var rRearClaw = Path()
        rRearClaw.move(to: CGPoint(x: center.x + 21, y: center.y + 30))
        rRearClaw.addLine(to: CGPoint(x: center.x + 24, y: center.y + 34))
        rRearClaw.addLine(to: CGPoint(x: center.x + 27, y: center.y + 30))
        rRearClaw.closeSubpath()
        context.fill(rRearClaw, with: .color(hornColor))
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

    // 5. GHOST — BOO (Floating mascot spirit: crest wisp, floating sleeves, 3-fold undulating skirt, zero legs)
    private static func drawGhostAnatomy(context: inout GraphicsContext, center: CGPoint, primary: Color, mood: PetMood, snapshot: AnimationSnapshot) {
        let wave = CGFloat(snapshot.ghostWaveOffset)
        let crestSway = CGFloat(sin(snapshot.time * 2.8) * 4.0)

        // Incorporate curious companion drift kinematics
        let ghostX = center.x + snapshot.curiousDriftOffset.x
        let ghostY = center.y + snapshot.curiousDriftOffset.y

        // Dynamic spectral color palette based on mood
        let spectralTint: Color
        let auraGlow: Color
        switch mood {
        case .happy:
            spectralTint = Color(red: 0.94, green: 0.90, blue: 1.0)
            auraGlow = Color(red: 0.88, green: 0.82, blue: 1.0)
        case .excited:
            spectralTint = Color(red: 0.98, green: 0.94, blue: 1.0)
            auraGlow = Color(red: 1.0, green: 0.88, blue: 0.50)
        case .sad, .concerned:
            spectralTint = Color(red: 0.80, green: 0.86, blue: 0.96)
            auraGlow = Color(red: 0.65, green: 0.75, blue: 0.94)
        case .sleepy:
            spectralTint = Color(red: 0.78, green: 0.76, blue: 0.88)
            auraGlow = Color(red: 0.55, green: 0.52, blue: 0.72)
        case .proud:
            spectralTint = Color(red: 0.96, green: 0.92, blue: 0.98)
            auraGlow = Color(red: 1.0, green: 0.86, blue: 0.40)
        default:
            spectralTint = primary
            auraGlow = Color(red: 0.82, green: 0.78, blue: 0.98)
        }

        // 0. Soft Ethereal Outer Aura Glow
        let auraRect = CGRect(x: ghostX - 38, y: ghostY - 44, width: 76, height: 76)
        context.fill(Circle().path(in: auraRect), with: .color(auraGlow.opacity(0.18)))

        // 1. Ghost Cowl Crest Wisp / Ethereal Flame atop the head
        var crest = Path()
        let crestTip = CGPoint(x: ghostX + 7 + crestSway, y: ghostY - 50)
        crest.move(to: CGPoint(x: ghostX - 8, y: ghostY - 32))
        crest.addCurve(to: crestTip,
                       control1: CGPoint(x: ghostX - 11, y: ghostY - 42),
                       control2: CGPoint(x: ghostX - 2, y: ghostY - 49))
        crest.addCurve(to: CGPoint(x: ghostX + 8, y: ghostY - 32),
                       control1: CGPoint(x: ghostX + 13 + crestSway, y: ghostY - 44),
                       control2: CGPoint(x: ghostX + 9, y: ghostY - 38))
        crest.closeSubpath()
        context.fill(crest, with: .color(spectralTint.opacity(0.92)))
        context.stroke(crest, with: .color(Color.white.opacity(0.75)), lineWidth: 1.2)

        // 2. Main Ghost Cowl & Flowing Body (Dome head, tapered waist, flowing outward)
        var ghost = Path()
        let topCenter = CGPoint(x: ghostX, y: ghostY - 36)

        // Start left shoulder
        ghost.move(to: CGPoint(x: ghostX - 26, y: ghostY - 8))
        // Rounded Head Dome
        ghost.addCurve(to: CGPoint(x: ghostX + 26, y: ghostY - 8),
                       control1: CGPoint(x: ghostX - 26, y: topCenter.y - 2),
                       control2: CGPoint(x: ghostX + 26, y: topCenter.y - 2))
        // Right flank extending downward into skirt
        ghost.addCurve(to: CGPoint(x: ghostX + 28, y: ghostY + 18),
                       control1: CGPoint(x: ghostX + 27, y: ghostY + 2),
                       control2: CGPoint(x: ghostX + 29, y: ghostY + 10))

        // 3-Fold Flowing Scalloped Liquid Skirt (Left, Center, Right ripples)
        let bY = ghostY + 22
        // Right ripple fold
        ghost.addCurve(to: CGPoint(x: ghostX + 10, y: bY + wave * 0.8),
                       control1: CGPoint(x: ghostX + 25, y: bY + 8 + wave),
                       control2: CGPoint(x: ghostX + 16, y: bY + 4))
        // Center ripple fold
        ghost.addCurve(to: CGPoint(x: ghostX - 10, y: bY - wave * 0.8),
                       control1: CGPoint(x: ghostX + 4, y: bY - 6),
                       control2: CGPoint(x: ghostX - 4, y: bY + 8 - wave))
        // Left ripple fold
        ghost.addCurve(to: CGPoint(x: ghostX - 28, y: ghostY + 18),
                       control1: CGPoint(x: ghostX - 18, y: bY + 4),
                       control2: CGPoint(x: ghostX - 26, y: bY + 7 - wave))

        // Left flank returning upward
        ghost.addCurve(to: CGPoint(x: ghostX - 26, y: ghostY - 8),
                       control1: CGPoint(x: ghostX - 29, y: ghostY + 10),
                       control2: CGPoint(x: ghostX - 27, y: ghostY + 2))
        ghost.closeSubpath()

        // Ghost Base fill with subtle ethereal translucent gradient
        context.fill(ghost, with: .color(primary.opacity(0.90)))
        context.stroke(ghost, with: .color(Color.white.opacity(0.85)), lineWidth: 1.6)

        // 3. Inner Ethereal Glow Core (Gives 3D volumetric depth)
        var innerCore = Path()
        innerCore.move(to: CGPoint(x: ghostX - 18, y: ghostY - 6))
        innerCore.addCurve(to: CGPoint(x: ghostX + 18, y: ghostY - 6),
                           control1: CGPoint(x: ghostX - 18, y: ghostY - 28),
                           control2: CGPoint(x: ghostX + 18, y: ghostY - 28))
        innerCore.addQuadCurve(to: CGPoint(x: ghostX, y: ghostY + 14),
                               control: CGPoint(x: ghostX + 16, y: ghostY + 10))
        innerCore.addQuadCurve(to: CGPoint(x: ghostX - 18, y: ghostY - 6),
                               control: CGPoint(x: ghostX - 16, y: ghostY + 10))
        innerCore.closeSubpath()
        context.fill(innerCore, with: .color(Color.white.opacity(0.22)))

        // 4. Floating Wispy Arms / Mittens (Kinematic floating with wave offset & arm gestures)
        let armFloat = CGFloat(cos(snapshot.time * 2.5) * 3.0)

        // Left Arm Wisp
        var lArm = Path()
        let lArmCenter = CGPoint(x: ghostX - 30 + snapshot.armGestureOffset.x,
                                 y: ghostY + 4 + armFloat + snapshot.armGestureOffset.y)
        lArm.move(to: CGPoint(x: ghostX - 24, y: ghostY))
        lArm.addCurve(to: CGPoint(x: lArmCenter.x - 7, y: lArmCenter.y + 4),
                      control1: CGPoint(x: ghostX - 32, y: ghostY - 2),
                      control2: CGPoint(x: lArmCenter.x - 10, y: lArmCenter.y - 2))
        lArm.addCurve(to: CGPoint(x: ghostX - 22, y: ghostY + 8),
                      control1: CGPoint(x: lArmCenter.x - 2, y: lArmCenter.y + 8),
                      control2: CGPoint(x: ghostX - 22, y: ghostY + 8))
        lArm.closeSubpath()
        context.fill(lArm, with: .color(primary.opacity(0.92)))
        context.stroke(lArm, with: .color(Color.white.opacity(0.75)), lineWidth: 1.2)

        // Right Arm Wisp
        var rArm = Path()
        let rArmCenter = CGPoint(x: ghostX + 30 - snapshot.armGestureOffset.x,
                                 y: ghostY + 4 - armFloat + snapshot.armGestureOffset.y)
        rArm.move(to: CGPoint(x: ghostX + 24, y: ghostY))
        rArm.addCurve(to: CGPoint(x: rArmCenter.x + 7, y: rArmCenter.y + 4),
                      control1: CGPoint(x: ghostX + 32, y: ghostY - 2),
                      control2: CGPoint(x: rArmCenter.x + 10, y: rArmCenter.y - 2))
        rArm.addCurve(to: CGPoint(x: ghostX + 22, y: ghostY + 8),
                      control1: CGPoint(x: rArmCenter.x + 2, y: rArmCenter.y + 8),
                      control2: CGPoint(x: ghostX + 22, y: ghostY + 8))
        rArm.closeSubpath()
        context.fill(rArm, with: .color(primary.opacity(0.92)))
        context.stroke(rArm, with: .color(Color.white.opacity(0.75)), lineWidth: 1.2)
    }

    // 6. FOX — KITA (Pointed ears with dark rims, elongated muzzle, fox ruff, giant fluffy tail)
    private static func drawFoxAnatomy(context: inout GraphicsContext, center: CGPoint, primary: Color, secondary: Color, snapshot: AnimationSnapshot) {
        let earTwitch = CGFloat(snapshot.earTwitchAngle.degrees * 0.5)

        // Large Fluffy Fox Tail (prominent behind body)
        var tail = Path()
        let tailEnd = CGPoint(x: center.x - 44 + CGFloat(snapshot.tailWagAngle.degrees * 0.7), y: center.y - 4)
        tail.move(to: CGPoint(x: center.x - 18, y: center.y + 14))
        tail.addQuadCurve(to: tailEnd, control: CGPoint(x: center.x - 50, y: center.y + 28))
        context.stroke(tail, with: .color(primary), lineWidth: 15.0)

        // White fluffy tip of fox tail
        let tailTip = Circle().path(in: CGRect(x: tailEnd.x - 7, y: tailEnd.y - 7, width: 14, height: 14))
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

        // Fox Head with Elongated Muzzle & Cheek Tuft Ruffs
        let headRect = CGRect(x: center.x - 24, y: center.y - 34, width: 48, height: 32)
        context.fill(RoundedRectangle(cornerRadius: 14).path(in: headRect), with: .color(primary))

        // Cheek fluff ruffs (left and right)
        var lRuff = Path()
        lRuff.move(to: CGPoint(x: center.x - 22, y: center.y - 20))
        lRuff.addLine(to: CGPoint(x: center.x - 31, y: center.y - 14))
        lRuff.addLine(to: CGPoint(x: center.x - 22, y: center.y - 8))
        lRuff.closeSubpath()
        context.fill(lRuff, with: .color(primary))

        var rRuff = Path()
        rRuff.move(to: CGPoint(x: center.x + 22, y: center.y - 20))
        rRuff.addLine(to: CGPoint(x: center.x + 31, y: center.y - 14))
        rRuff.addLine(to: CGPoint(x: center.x + 22, y: center.y - 8))
        rRuff.closeSubpath()
        context.fill(rRuff, with: .color(primary))

        // Pointed Fox Snout/Muzzle
        var muzzle = Path()
        muzzle.move(to: CGPoint(x: center.x - 12, y: center.y - 18))
        muzzle.addLine(to: CGPoint(x: center.x, y: center.y - 6))
        muzzle.addLine(to: CGPoint(x: center.x + 12, y: center.y - 18))
        muzzle.closeSubpath()
        context.fill(muzzle, with: .color(Color.white))

        let nose = Circle().path(in: CGRect(x: center.x - 2.5, y: center.y - 8, width: 5, height: 5))
        context.fill(nose, with: .color(Color.black))

        // Large Pointed Fox Ears with Dark Rims & Twitch Kinematics
        var lEar = Path()
        lEar.move(to: CGPoint(x: center.x - 22, y: center.y - 30))
        lEar.addLine(to: CGPoint(x: center.x - 28 + earTwitch, y: center.y - 54))
        lEar.addLine(to: CGPoint(x: center.x - 8, y: center.y - 32))
        lEar.closeSubpath()
        context.fill(lEar, with: .color(primary))
        context.stroke(lEar, with: .color(Color(white: 0.15)), lineWidth: 1.5)

        var lEarInner = Path()
        lEarInner.move(to: CGPoint(x: center.x - 20, y: center.y - 31))
        lEarInner.addLine(to: CGPoint(x: center.x - 25 + earTwitch, y: center.y - 48))
        lEarInner.addLine(to: CGPoint(x: center.x - 11, y: center.y - 32))
        lEarInner.closeSubpath()
        context.fill(lEarInner, with: .color(Color.white.opacity(0.85)))

        var rEar = Path()
        rEar.move(to: CGPoint(x: center.x + 8, y: center.y - 32))
        rEar.addLine(to: CGPoint(x: center.x + 28 - earTwitch, y: center.y - 54))
        rEar.addLine(to: CGPoint(x: center.x + 22, y: center.y - 30))
        rEar.closeSubpath()
        context.fill(rEar, with: .color(primary))
        context.stroke(rEar, with: .color(Color(white: 0.15)), lineWidth: 1.5)

        var rEarInner = Path()
        rEarInner.move(to: CGPoint(x: center.x + 11, y: center.y - 32))
        rEarInner.addLine(to: CGPoint(x: center.x + 25 - earTwitch, y: center.y - 48))
        rEarInner.addLine(to: CGPoint(x: center.x + 20, y: center.y - 31))
        rEarInner.closeSubpath()
        context.fill(rEarInner, with: .color(Color.white.opacity(0.85)))

        // Four Slender Legs with Dark Paws
        let pawY = center.y + 24 + snapshot.pawOffset * 0.4
        let lPaw = Capsule().path(in: CGRect(x: center.x - 16, y: pawY, width: 8, height: 10))
        let rPaw = Capsule().path(in: CGRect(x: center.x + 8, y: pawY, width: 8, height: 10))
        context.fill(lPaw, with: .color(Color(white: 0.15)))
        context.fill(rPaw, with: .color(Color(white: 0.15)))
    }

    // 7. BUNNY — POCHI (Very tall curved ears, chubby cheeks, soft muzzle, tucked front paws, large hind hopping legs, cotton puff tail)
    private static func drawBunnyAnatomy(context: inout GraphicsContext, center: CGPoint, primary: Color, mood: PetMood, snapshot: AnimationSnapshot) {
        let earTwitch = snapshot.earTwitchAngle.degrees
        let isDroopy = mood == .sleepy || mood == .sad
        let isPerky = mood == .happy || mood == .excited

        // 1. Round Cotton Puff Tail (Multi-lobed fluffy pom-pom behind left hip)
        let tailBaseX = center.x - 30 + CGFloat(snapshot.tailWagAngle.degrees * 0.25)
        let tailBaseY = center.y + 14
        let p1 = Circle().path(in: CGRect(x: tailBaseX - 7, y: tailBaseY - 6, width: 14, height: 14))
        let p2 = Circle().path(in: CGRect(x: tailBaseX - 3, y: tailBaseY - 10, width: 12, height: 12))
        let p3 = Circle().path(in: CGRect(x: tailBaseX - 2, y: tailBaseY - 2, width: 11, height: 11))
        context.fill(p1, with: .color(Color.white.opacity(0.95)))
        context.fill(p2, with: .color(Color.white.opacity(0.95)))
        context.fill(p3, with: .color(Color.white.opacity(0.95)))

        // 2. Very Tall Curved Rabbit Ears (With mood-reactive droop and independent twitch kinematics)
        let earHeightOffset: CGFloat = isDroopy ? 24.0 : (isPerky ? -4.0 : 0.0)
        let earCurveSpread: CGFloat = isDroopy ? 16.0 : 0.0

        // Left Ear
        var lEar = Path()
        let lTip = CGPoint(x: center.x - 22 - earCurveSpread + CGFloat(earTwitch * 0.6), y: center.y - 66 + earHeightOffset)
        lEar.move(to: CGPoint(x: center.x - 17, y: center.y - 28))
        lEar.addCurve(to: lTip,
                      control1: CGPoint(x: center.x - 28 - earCurveSpread * 0.5, y: center.y - 42 + earHeightOffset * 0.5),
                      control2: CGPoint(x: center.x - 30 - earCurveSpread, y: center.y - 58 + earHeightOffset * 0.8))
        lEar.addCurve(to: CGPoint(x: center.x - 7, y: center.y - 28),
                      control1: CGPoint(x: center.x - 14, y: center.y - 60 + earHeightOffset * 0.8),
                      control2: CGPoint(x: center.x - 6, y: center.y - 44))
        lEar.closeSubpath()
        context.fill(lEar, with: .color(primary))

        // Left Inner Ear Channel (soft blush pink)
        var lInner = Path()
        let lInnerTip = CGPoint(x: center.x - 21 - earCurveSpread + CGFloat(earTwitch * 0.6), y: center.y - 62 + earHeightOffset)
        lInner.move(to: CGPoint(x: center.x - 15, y: center.y - 30))
        lInner.addCurve(to: lInnerTip,
                        control1: CGPoint(x: center.x - 24 - earCurveSpread * 0.5, y: center.y - 42 + earHeightOffset * 0.5),
                        control2: CGPoint(x: center.x - 26 - earCurveSpread, y: center.y - 56 + earHeightOffset * 0.8))
        lInner.addCurve(to: CGPoint(x: center.x - 9, y: center.y - 30),
                        control1: CGPoint(x: center.x - 16, y: center.y - 58 + earHeightOffset * 0.8),
                        control2: CGPoint(x: center.x - 10, y: center.y - 44))
        lInner.closeSubpath()
        context.fill(lInner, with: .color(Color.pink.opacity(0.55)))

        // Right Ear
        var rEar = Path()
        let rTip = CGPoint(x: center.x + 22 + earCurveSpread - CGFloat(earTwitch * 0.4), y: center.y - 66 + earHeightOffset)
        rEar.move(to: CGPoint(x: center.x + 7, y: center.y - 28))
        rEar.addCurve(to: rTip,
                      control1: CGPoint(x: center.x + 6, y: center.y - 44),
                      control2: CGPoint(x: center.x + 14, y: center.y - 60 + earHeightOffset * 0.8))
        rEar.addCurve(to: CGPoint(x: center.x + 17, y: center.y - 28),
                      control1: CGPoint(x: center.x + 30 + earCurveSpread, y: center.y - 58 + earHeightOffset * 0.8),
                      control2: CGPoint(x: center.x + 28 + earCurveSpread * 0.5, y: center.y - 42 + earHeightOffset * 0.5))
        rEar.closeSubpath()
        context.fill(rEar, with: .color(primary))

        // Right Inner Ear Channel
        var rInner = Path()
        let rInnerTip = CGPoint(x: center.x + 21 + earCurveSpread - CGFloat(earTwitch * 0.4), y: center.y - 62 + earHeightOffset)
        rInner.move(to: CGPoint(x: center.x + 9, y: center.y - 30))
        rInner.addCurve(to: rInnerTip,
                        control1: CGPoint(x: center.x + 10, y: center.y - 44),
                        control2: CGPoint(x: center.x + 16, y: center.y - 58 + earHeightOffset * 0.8))
        rInner.addCurve(to: CGPoint(x: center.x + 15, y: center.y - 30),
                        control1: CGPoint(x: center.x + 26 + earCurveSpread, y: center.y - 56 + earHeightOffset * 0.8),
                        control2: CGPoint(x: center.x + 24 + earCurveSpread * 0.5, y: center.y - 42 + earHeightOffset * 0.5))
        rInner.closeSubpath()
        context.fill(rInner, with: .color(Color.pink.opacity(0.55)))

        // 3. Pear-Shaped Rabbit Body (Narrower chest curving smoothly into plump, rounded hips)
        var pearBody = Path()
        pearBody.move(to: CGPoint(x: center.x - 16, y: center.y - 8))
        pearBody.addQuadCurve(to: CGPoint(x: center.x + 16, y: center.y - 8), control: CGPoint(x: center.x, y: center.y - 11))
        pearBody.addCurve(to: CGPoint(x: center.x + 29, y: center.y + 24),
                          control1: CGPoint(x: center.x + 20, y: center.y + 4),
                          control2: CGPoint(x: center.x + 30, y: center.y + 14))
        pearBody.addQuadCurve(to: CGPoint(x: center.x - 29, y: center.y + 24), control: CGPoint(x: center.x, y: center.y + 32))
        pearBody.addCurve(to: CGPoint(x: center.x - 16, y: center.y - 8),
                          control1: CGPoint(x: center.x - 30, y: center.y + 14),
                          control2: CGPoint(x: center.x - 20, y: center.y + 4))
        pearBody.closeSubpath()
        context.fill(pearBody, with: .color(primary))

        // Tummy patch (soft warm white pear highlight)
        let tummyRect = CGRect(x: center.x - 18, y: center.y - 2, width: 36, height: 30)
        context.fill(Ellipse().path(in: tummyRect), with: .color(Color.white.opacity(0.35)))

        // 4. Bunny Head with Chubby Fluffy Cheeks (Wider at bottom cheeks)
        var headPath = Path()
        headPath.move(to: CGPoint(x: center.x - 18, y: center.y - 34))
        headPath.addQuadCurve(to: CGPoint(x: center.x + 18, y: center.y - 34), control: CGPoint(x: center.x, y: center.y - 38))
        headPath.addCurve(to: CGPoint(x: center.x, y: center.y - 6),
                          control1: CGPoint(x: center.x + 26, y: center.y - 26),
                          control2: CGPoint(x: center.x + 25, y: center.y - 10))
        headPath.addCurve(to: CGPoint(x: center.x - 18, y: center.y - 34),
                          control1: CGPoint(x: center.x - 25, y: center.y - 10),
                          control2: CGPoint(x: center.x - 26, y: center.y - 26))
        headPath.closeSubpath()
        context.fill(headPath, with: .color(primary))

        // Subtle Soft Cheek Blush
        let lCheek = Circle().path(in: CGRect(x: center.x - 23, y: center.y - 16, width: 11, height: 9))
        let rCheek = Circle().path(in: CGRect(x: center.x + 12, y: center.y - 16, width: 11, height: 9))
        context.fill(lCheek, with: .color(Color.pink.opacity(0.24)))
        context.fill(rCheek, with: .color(Color.pink.opacity(0.24)))

        // Delicate Whiskers (3 on each cheek)
        for i in -1...1 {
            let wy = center.y - 14 + CGFloat(i * 3)
            var lWhisker = Path()
            lWhisker.move(to: CGPoint(x: center.x - 14, y: wy))
            lWhisker.addLine(to: CGPoint(x: center.x - 28, y: wy + CGFloat(i * 2)))
            context.stroke(lWhisker, with: .color(Color.white.opacity(0.70)), lineWidth: 1.0)

            var rWhisker = Path()
            rWhisker.move(to: CGPoint(x: center.x + 14, y: wy))
            rWhisker.addLine(to: CGPoint(x: center.x + 28, y: wy + CGFloat(i * 2)))
            context.stroke(rWhisker, with: .color(Color.white.opacity(0.70)), lineWidth: 1.0)
        }

        // 5. Short front bunny paws held near chest (reacts to pawOffset)
        let pawY = center.y + 8 + snapshot.pawOffset * 0.5
        let lFront = Capsule().path(in: CGRect(x: center.x - 12, y: pawY, width: 9, height: 13))
        let rFront = Capsule().path(in: CGRect(x: center.x + 3, y: pawY, width: 9, height: 13))
        context.fill(lFront, with: .color(primary.opacity(0.92)))
        context.stroke(lFront, with: .color(Color.white.opacity(0.3)), lineWidth: 1.0)
        context.fill(rFront, with: .color(primary.opacity(0.92)))
        context.stroke(rFront, with: .color(Color.white.opacity(0.3)), lineWidth: 1.0)

        // 6. Large Hind Hopping Feet (Signature rabbit silhouette, well-integrated with base)
        let lFoot = Capsule().path(in: CGRect(x: center.x - 30, y: center.y + 23, width: 22, height: 11))
        let rFoot = Capsule().path(in: CGRect(x: center.x + 8, y: center.y + 23, width: 22, height: 11))
        context.fill(lFoot, with: .color(primary))
        context.stroke(lFoot, with: .color(Color.black.opacity(0.12)), lineWidth: 1.0)
        context.fill(rFoot, with: .color(primary))
        context.stroke(rFoot, with: .color(Color.black.opacity(0.12)), lineWidth: 1.0)
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
            // Head: [-40, -10], Snout: [-23, -9]
            return CharacterFaceLayout(
                eyeCenterY: -26,
                eyeSpacing: 13,
                eyeWidth: 8.0,
                eyeHeight: 9.0,
                eyeStyle: .reptilian,
                noseOffsetY: -15,
                mouthOffsetY: -9,
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
        mood: PetMood,
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
            mood: mood,
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
            mood: mood,
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
        mood: PetMood,
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

            var ledColor = isGrayscale ? Color.white : (species == .robotcat ? Color.green : Color.cyan)
            if mood == .proud {
                ledColor = Color(red: 1.0, green: 0.85, blue: 0.2)
            } else if mood == .concerned {
                ledColor = Color.orange
            } else if mood == .angry {
                ledColor = Color.red
            }

            if isClosed {
                // Dimmed horizontal LED slit during blink/sleep
                let lSlit = Rectangle().path(in: CGRect(x: leftEyeX - 3.5, y: gazeY - 0.75, width: 7, height: 1.5))
                let rSlit = Rectangle().path(in: CGRect(x: rightEyeX - 3.5, y: gazeY - 0.75, width: 7, height: 1.5))
                context.fill(lSlit, with: .color(ledColor.opacity(0.4)))
                context.fill(rSlit, with: .color(ledColor.opacity(0.4)))
            } else if mood == .proud || animState == .dance {
                // Happy chevron/arch LED (^ ^)
                var lArc = Path()
                lArc.move(to: CGPoint(x: leftEyeX - 4, y: gazeY + 2))
                lArc.addLine(to: CGPoint(x: leftEyeX, y: gazeY - 3))
                lArc.addLine(to: CGPoint(x: leftEyeX + 4, y: gazeY + 2))
                context.stroke(lArc, with: .color(ledColor), lineWidth: 2.2)

                var rArc = Path()
                rArc.move(to: CGPoint(x: rightEyeX - 4, y: gazeY + 2))
                rArc.addLine(to: CGPoint(x: rightEyeX, y: gazeY - 3))
                rArc.addLine(to: CGPoint(x: rightEyeX + 4, y: gazeY + 2))
                context.stroke(rArc, with: .color(ledColor), lineWidth: 2.2)
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
            } else if mood == .proud || animState == .dance {
                // Happy curved squint arcs (^ ^)
                var lArc = Path()
                lArc.addArc(center: CGPoint(x: leftEyeX, y: eyeY + 1.5), radius: 4.5, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                context.stroke(lArc, with: .color(Color(white: 0.15)), lineWidth: 2.2)

                var rArc = Path()
                rArc.addArc(center: CGPoint(x: rightEyeX, y: eyeY + 1.5), radius: 4.5, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                context.stroke(rArc, with: .color(Color(white: 0.15)), lineWidth: 2.2)
            } else {
                let openHeight = animState == .shock ? layout.eyeHeight * 1.3 : layout.eyeHeight
                let h = max(1.5, openHeight * (1.0 - snapshot.blinkProgress))
                let w = layout.eyeWidth

                // Upward curious gaze during thinking
                let finalGazeY = animState == .thinking ? gazeY - 2.0 : gazeY

                let lEye = Ellipse().path(in: CGRect(x: leftEyeX - w/2, y: finalGazeY - h/2, width: w, height: h))
                let rEye = Ellipse().path(in: CGRect(x: rightEyeX - w/2, y: finalGazeY - h/2, width: w, height: h))
                context.fill(lEye, with: .color(Color(white: 0.12)))
                context.fill(rEye, with: .color(Color(white: 0.12)))

                // Inner spectral blue-cyan glow
                if !isGrayscale && h > 4 {
                    let lGlow = Ellipse().path(in: CGRect(x: leftEyeX - (w - 3)/2, y: finalGazeY - (h - 3)/2, width: w - 3, height: h - 3))
                    let rGlow = Ellipse().path(in: CGRect(x: rightEyeX - (w - 3)/2, y: finalGazeY - (h - 3)/2, width: w - 3, height: h - 3))
                    context.fill(lGlow, with: .color(Color.cyan.opacity(0.25)))
                    context.fill(rGlow, with: .color(Color.cyan.opacity(0.25)))
                }

                if h > 3.5 {
                    // Primary specular sparkle
                    let lSpark = Circle().path(in: CGRect(x: leftEyeX - 1.5, y: finalGazeY - 2.5, width: 3, height: 3))
                    let rSpark = Circle().path(in: CGRect(x: rightEyeX - 1.5, y: finalGazeY - 2.5, width: 3, height: 3))
                    context.fill(lSpark, with: .color(Color.white))
                    context.fill(rSpark, with: .color(Color.white))

                    // Secondary twinkle sparkle
                    let lSubSpark = Circle().path(in: CGRect(x: leftEyeX + 1.0, y: finalGazeY + 1.0, width: 1.5, height: 1.5))
                    let rSubSpark = Circle().path(in: CGRect(x: rightEyeX + 1.0, y: finalGazeY + 1.0, width: 1.5, height: 1.5))
                    context.fill(lSubSpark, with: .color(Color.white.opacity(0.85)))
                    context.fill(rSubSpark, with: .color(Color.white.opacity(0.85)))
                }

                if mood == .concerned {
                    var lBrow = Path()
                    lBrow.move(to: CGPoint(x: leftEyeX - 4, y: finalGazeY - 7))
                    lBrow.addLine(to: CGPoint(x: leftEyeX + 4, y: finalGazeY - 9))
                    context.stroke(lBrow, with: .color(Color(white: 0.2)), lineWidth: 1.5)

                    var rBrow = Path()
                    rBrow.move(to: CGPoint(x: rightEyeX - 4, y: finalGazeY - 9))
                    rBrow.addLine(to: CGPoint(x: rightEyeX + 4, y: finalGazeY - 7))
                    context.stroke(rBrow, with: .color(Color(white: 0.2)), lineWidth: 1.5)
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
            } else if mood == .proud {
                var lArc = Path()
                lArc.addArc(center: CGPoint(x: leftEyeX, y: eyeY + 1.5), radius: 4.5, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                context.stroke(lArc, with: .color(Color(white: 0.15)), lineWidth: 2.2)

                var rArc = Path()
                rArc.addArc(center: CGPoint(x: rightEyeX, y: eyeY + 1.5), radius: 4.5, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                context.stroke(rArc, with: .color(Color(white: 0.15)), lineWidth: 2.2)
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
            } else if mood == .proud || animState == .dance {
                // Cheerful closed smiling crescent arcs (^ ^)
                var lArc = Path()
                lArc.addArc(center: CGPoint(x: leftEyeX, y: gazeY + 1.5), radius: 4.5, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                context.stroke(lArc, with: .color(Color(white: 0.15)), lineWidth: 2.4)

                var rArc = Path()
                rArc.addArc(center: CGPoint(x: rightEyeX, y: gazeY + 1.5), radius: 4.5, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                context.stroke(rArc, with: .color(Color(white: 0.15)), lineWidth: 2.4)
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

                // Mood overlays
                if mood == .concerned {
                    var lBrow = Path()
                    lBrow.move(to: CGPoint(x: leftEyeX - 4, y: gazeY - 7))
                    lBrow.addLine(to: CGPoint(x: leftEyeX + 4, y: gazeY - 9))
                    context.stroke(lBrow, with: .color(Color(white: 0.2)), lineWidth: 1.5)

                    var rBrow = Path()
                    rBrow.move(to: CGPoint(x: rightEyeX - 4, y: gazeY - 9))
                    rBrow.addLine(to: CGPoint(x: rightEyeX + 4, y: gazeY - 7))
                    context.stroke(rBrow, with: .color(Color(white: 0.2)), lineWidth: 1.5)
                } else if mood == .angry {
                    var lBrow = Path()
                    lBrow.move(to: CGPoint(x: leftEyeX - 4, y: gazeY - 9))
                    lBrow.addLine(to: CGPoint(x: leftEyeX + 4, y: gazeY - 6))
                    context.stroke(lBrow, with: .color(Color(white: 0.15)), lineWidth: 1.8)

                    var rBrow = Path()
                    rBrow.move(to: CGPoint(x: rightEyeX - 4, y: gazeY - 6))
                    rBrow.addLine(to: CGPoint(x: rightEyeX + 4, y: gazeY - 9))
                    context.stroke(rBrow, with: .color(Color(white: 0.15)), lineWidth: 1.8)
                } else if (mood == .sad || mood == .crying) && !isGrayscale {
                    let tearY = gazeY + 5 + CGFloat(fmod(snapshot.time * 6.0, 8.0))
                    let lTear = Ellipse().path(in: CGRect(x: leftEyeX - 1.5, y: tearY, width: 3, height: 4.5))
                    context.fill(lTear, with: .color(Color(red: 0.4, green: 0.7, blue: 1.0).opacity(0.85)))
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
        mood: PetMood,
        snapshot: AnimationSnapshot,
        isGrayscale: Bool
    ) {
        let mouthY = center.y + layout.mouthOffsetY
        let halfW = layout.mouthWidth / 2

        if layout.eyeStyle == .led {
            // Digital LED smile or segmented line
            var ledMouth = Path()
            ledMouth.move(to: CGPoint(x: center.x - halfW, y: mouthY))
            ledMouth.addQuadCurve(to: CGPoint(x: center.x + halfW, y: mouthY), control: CGPoint(x: center.x, y: mouthY + (mood == .angry ? -2.0 : (mood == .concerned ? 0.0 : 2.5))))
            var mColor = isGrayscale ? Color.white : (species == .robotcat ? Color.green : Color.cyan)
            if mood == .proud { mColor = Color.yellow }
            context.stroke(ledMouth, with: .color(mColor), lineWidth: 1.6)
            return
        }

        if animState == .shock {
            let oMouth = Ellipse().path(in: CGRect(x: center.x - 3.5, y: mouthY - 3, width: 7, height: 8))
            context.fill(oMouth, with: .color(Color(white: 0.12)))
            return
        }

        if mood == .proud {
            // Broad cheerful beaming smile with tongue
            var smile = Path()
            smile.move(to: CGPoint(x: center.x - halfW - 1, y: mouthY))
            smile.addQuadCurve(to: CGPoint(x: center.x + halfW + 1, y: mouthY), control: CGPoint(x: center.x, y: mouthY + 5.5))
            smile.closeSubpath()
            context.fill(smile, with: .color(Color(white: 0.15)))
            if !isGrayscale {
                let tongue = Ellipse().path(in: CGRect(x: center.x - 2.5, y: mouthY + 2.0, width: 5, height: 3.5))
                context.fill(tongue, with: .color(Color.pink.opacity(0.85)))
            }
            return
        }

        if mood == .concerned {
            // Worried wavy mouth
            var wavy = Path()
            wavy.move(to: CGPoint(x: center.x - halfW, y: mouthY))
            wavy.addQuadCurve(to: CGPoint(x: center.x, y: mouthY - 1.5), control: CGPoint(x: center.x - halfW/2, y: mouthY - 2.5))
            wavy.addQuadCurve(to: CGPoint(x: center.x + halfW, y: mouthY + 1.0), control: CGPoint(x: center.x + halfW/2, y: mouthY + 2.0))
            context.stroke(wavy, with: .color(Color(white: 0.18)), lineWidth: 1.6)
            return
        }

        if mood == .angry {
            // Stern downturned mouth
            var frown = Path()
            frown.move(to: CGPoint(x: center.x - halfW, y: mouthY + 2.0))
            frown.addQuadCurve(to: CGPoint(x: center.x + halfW, y: mouthY + 2.0), control: CGPoint(x: center.x, y: mouthY - 1.5))
            context.stroke(frown, with: .color(Color(white: 0.18)), lineWidth: 1.8)
            return
        }

        if mood == .sad || mood == .crying {
            // Downturned sad mouth
            var sadMouth = Path()
            sadMouth.move(to: CGPoint(x: center.x - halfW, y: mouthY + 1.5))
            sadMouth.addQuadCurve(to: CGPoint(x: center.x + halfW, y: mouthY + 1.5), control: CGPoint(x: center.x, y: mouthY - 2.0))
            context.stroke(sadMouth, with: .color(Color(white: 0.18)), lineWidth: 1.6)
            return
        }

        if species == .ghost {
            if animState == .dance {
                // Open cheerful smile with pink tongue
                var smile = Path()
                smile.move(to: CGPoint(x: center.x - halfW - 1, y: mouthY))
                smile.addQuadCurve(to: CGPoint(x: center.x + halfW + 1, y: mouthY), control: CGPoint(x: center.x, y: mouthY + 5.5))
                smile.closeSubpath()
                context.fill(smile, with: .color(Color(white: 0.15)))
                if !isGrayscale {
                    let tongue = Ellipse().path(in: CGRect(x: center.x - 2.5, y: mouthY + 2.0, width: 5, height: 3.5))
                    context.fill(tongue, with: .color(Color.pink.opacity(0.85)))
                }
                return
            } else if animState == .thinking {
                // Curious small side curve / smirk
                var curiousMouth = Path()
                curiousMouth.move(to: CGPoint(x: center.x - halfW * 0.6, y: mouthY + 1))
                curiousMouth.addQuadCurve(to: CGPoint(x: center.x + halfW, y: mouthY - 1.5), control: CGPoint(x: center.x + 1, y: mouthY + 2))
                context.stroke(curiousMouth, with: .color(Color(white: 0.18)), lineWidth: 1.8)
                return
            }
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
