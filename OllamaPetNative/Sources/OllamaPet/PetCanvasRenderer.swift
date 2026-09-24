import Foundation
import SwiftUI
import AppKit

// MARK: - Procedural Color & Lighting Engine

public struct ProceduralColorEngine {
    public struct LightingContext {
        public let primaryColor: Color
        public let secondaryColor: Color
        public let auraInner: Color
        public let auraOuter: Color
        public let rimLightColor: Color
        public let thermalIntensity: Double // 0.0 (cool) -> 1.0 (overclocked)
    }

    public static func evaluate(
        species: PetSpecies,
        model: CharacterStructuralModel,
        cpuPercent: Double,
        atmosphere: WeatherAtmosphere,
        localHour: Int = Calendar.current.component(.hour, from: Date())
    ) -> LightingContext {
        // Base color depending on structural model or species
        let baseColor: Color
        let secondary: Color

        switch model {
        case .kineticSlime:
            baseColor = Color(red: 52/255, green: 211/255, blue: 153/255) // Emerald jelly
            secondary = Color(red: 16/255, green: 185/255, blue: 129/255)
        case .cyberSentry:
            baseColor = Color(red: 56/255, green: 189/255, blue: 248/255) // Sky cyber
            secondary = Color(red: 99/255, green: 102/255, blue: 241/255)
        case .pixelChibiBeast:
            baseColor = Color(red: 251/255, green: 191/255, blue: 36/255)  // Golden amber
            secondary = Color(red: 245/255, green: 158/255, blue: 11/255)
        case .classicSpecies:
            baseColor = species.accentColor
            secondary = species.accentColor.opacity(0.7)
        }

        // 1. Reactive Thermal Shifts based on CPU load (SystemMonitor)
        let thermalNormalized = min(1.0, max(0.0, cpuPercent / 100.0))
        let thermalIntensity = thermalNormalized > 0.65 ? (thermalNormalized - 0.65) / 0.35 : 0.0

        let auraInner: Color
        let auraOuter: Color

        if cpuPercent > 70 {
            // Overclocked incandescent thermal fire
            auraInner = Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.45)
            auraOuter = Color(red: 249/255, green: 115/255, blue: 22/255).opacity(0.15)
        } else if cpuPercent > 40 {
            // Warm golden active state
            auraInner = Color(red: 245/255, green: 158/255, blue: 11/255).opacity(0.35)
            auraOuter = baseColor.opacity(0.12)
        } else {
            // Normal cool serene state
            auraInner = baseColor.opacity(0.25)
            auraOuter = baseColor.opacity(0.05)
        }

        // 2. Ambient Day / Night / Weather Rim Lighting
        let rimColor: Color
        switch atmosphere {
        case .goldenHour:
            rimColor = Color(red: 251/255, green: 191/255, blue: 36/255).opacity(0.8)
        case .nightClear:
            rimColor = Color(red: 147/255, green: 197/255, blue: 253/255).opacity(0.7)
        case .rain, .thunderstorm:
            rimColor = Color(red: 186/255, green: 230/255, blue: 253/255).opacity(0.75)
        case .snow:
            rimColor = Color(red: 241/255, green: 245/255, blue: 249/255).opacity(0.85)
        case .fog:
            rimColor = Color(red: 203/255, green: 213/255, blue: 225/255).opacity(0.5)
        case .clearDay:
            if localHour >= 6 && localHour < 18 {
                rimColor = Color.white.opacity(0.7)
            } else {
                rimColor = Color(red: 191/255, green: 219/255, blue: 254/255).opacity(0.6)
            }
        }

        return LightingContext(
            primaryColor: baseColor,
            secondaryColor: secondary,
            auraInner: auraInner,
            auraOuter: auraOuter,
            rimLightColor: rimColor,
            thermalIntensity: thermalIntensity
        )
    }
}

// MARK: - 5-Layer Composable Render Tree

@MainActor
public struct PetCanvasRenderer {
    public static func draw(
        context: inout GraphicsContext,
        size: CGSize,
        species: PetSpecies,
        model: CharacterStructuralModel,
        animState: PetAnimState,
        motion: CharacterMotionStateMachine,
        lighting: ProceduralColorEngine.LightingContext,
        atmosphere: WeatherAtmosphere,
        time: Double
    ) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        // LAYER 1: AURA & LIGHTING
        drawAuraLayer(
            context: &context,
            center: center,
            size: size,
            lighting: lighting,
            animState: animState,
            atmosphere: atmosphere,
            time: time
        )

        // Apply motion transforms (spring squash/stretch, levitation, breath, head tilt)
        var petContext = context
        let bodyY = center.y + motion.levitationOffset + motion.breathOffset
        petContext.translateBy(x: center.x, y: bodyY)
        petContext.rotate(by: motion.headTiltAngle)
        petContext.scaleBy(x: motion.squashStretch.width, y: motion.squashStretch.height)
        petContext.translateBy(x: -center.x, y: -bodyY)

        // LAYER 2: BODY SHELL
        drawBodyShellLayer(
            context: &petContext,
            center: CGPoint(x: center.x, y: bodyY),
            model: model,
            species: species,
            animState: animState,
            motion: motion,
            lighting: lighting,
            time: time
        )

        // LAYER 3: CLOTHING / SKIN / CIRCUITS
        drawClothingSkinLayer(
            context: &petContext,
            center: CGPoint(x: center.x, y: bodyY),
            model: model,
            species: species,
            lighting: lighting,
            time: time
        )

        // LAYER 4: FACIAL FEATURES & EYES
        drawFacialFeaturesLayer(
            context: &petContext,
            center: CGPoint(x: center.x, y: bodyY),
            model: model,
            species: species,
            animState: animState,
            motion: motion,
            lighting: lighting,
            time: time
        )

        // LAYER 5: FLOATING ACCESSORIES & PARTICLES
        drawAccessoriesLayer(
            context: &context,
            size: size,
            center: center,
            motion: motion,
            atmosphere: atmosphere,
            animState: animState,
            time: time
        )
    }

    // MARK: - Layer 1: Aura & Lighting

    private static func drawAuraLayer(
        context: inout GraphicsContext,
        center: CGPoint,
        size: CGSize,
        lighting: ProceduralColorEngine.LightingContext,
        animState: PetAnimState,
        atmosphere: WeatherAtmosphere,
        time: Double
    ) {
        // Base Ambient Glow
        let pulse = 1.0 + (sin(time * 3.0) * 0.08)
        let auraRadius: CGFloat = 55.0 * pulse

        var auraPath = Path()
        auraPath.addEllipse(in: CGRect(
            x: center.x - auraRadius,
            y: center.y - auraRadius,
            width: auraRadius * 2,
            height: auraRadius * 2
        ))

        let radialGradient = Gradient(colors: [lighting.auraInner, lighting.auraOuter, Color.clear])
        context.fill(
            auraPath,
            with: .radialGradient(
                radialGradient,
                center: center,
                startRadius: 5,
                endRadius: auraRadius
            )
        )

        // Thermal coronal flare if CPU is hot
        if lighting.thermalIntensity > 0 {
            let flareRadius = auraRadius * (1.0 + CGFloat(lighting.thermalIntensity) * 0.3)
            var flarePath = Path()
            flarePath.addEllipse(in: CGRect(
                x: center.x - flareRadius,
                y: center.y - flareRadius,
                width: flareRadius * 2,
                height: flareRadius * 2
            ))
            context.fill(flarePath, with: .color(Color.red.opacity(0.18 * lighting.thermalIntensity)))
        }

        // Atmospheric Golden-Hour Sunbeams
        if atmosphere == .goldenHour {
            for i in 0..<4 {
                let beamAngle = Double(i) * 0.45 + (sin(time * 0.5) * 0.1)
                var beamPath = Path()
                beamPath.move(to: CGPoint(x: 0, y: 0))
                beamPath.addLine(to: CGPoint(x: center.x + CGFloat(cos(beamAngle) * 90), y: center.y + CGFloat(sin(beamAngle) * 90)))
                beamPath.addLine(to: CGPoint(x: center.x + CGFloat(cos(beamAngle + 0.15) * 90), y: center.y + CGFloat(sin(beamAngle + 0.15) * 90)))
                beamPath.closeSubpath()
                context.fill(beamPath, with: .color(Color(red: 251/255, green: 191/255, blue: 36/255).opacity(0.08)))
            }
        }
    }

    // MARK: - Layer 2: Body Shell

    private static func drawBodyShellLayer(
        context: inout GraphicsContext,
        center: CGPoint,
        model: CharacterStructuralModel,
        species: PetSpecies,
        animState: PetAnimState,
        motion: CharacterMotionStateMachine,
        lighting: ProceduralColorEngine.LightingContext,
        time: Double
    ) {
        switch model {
        case .kineticSlime:
            drawKineticSlimeBody(context: &context, center: center, lighting: lighting, time: time)

        case .cyberSentry:
            drawCyberSentryBody(context: &context, center: center, lighting: lighting, time: time)

        case .pixelChibiBeast:
            drawPixelChibiBody(context: &context, center: center, motion: motion, lighting: lighting, time: time)

        case .classicSpecies:
            drawClassicSpeciesBody(context: &context, center: center, species: species, animState: animState, motion: motion, lighting: lighting, time: time)
        }
    }

    private static func drawKineticSlimeBody(
        context: inout GraphicsContext,
        center: CGPoint,
        lighting: ProceduralColorEngine.LightingContext,
        time: Double
    ) {
        // Elastic Bezier Morphing Blob
        let pointsCount = 8
        let baseRadius: CGFloat = 36.0
        var slimePath = Path()

        var pts: [CGPoint] = []
        for i in 0..<pointsCount {
            let angle = (Double(i) / Double(pointsCount)) * 2 * .pi
            let rMod = sin(time * 3.5 + Double(i) * 1.2) * 4.5
            let r = baseRadius + CGFloat(rMod)
            let px = center.x + CGFloat(cos(angle)) * r
            let py = center.y + CGFloat(sin(angle)) * (r * 0.9)
            pts.append(CGPoint(x: px, y: py))
        }

        slimePath.move(to: CGPoint(x: (pts[0].x + pts[pointsCount - 1].x) / 2, y: (pts[0].y + pts[pointsCount - 1].y) / 2))
        for i in 0..<pointsCount {
            let next = (i + 1) % pointsCount
            let mid = CGPoint(x: (pts[i].x + pts[next].x) / 2, y: (pts[i].y + pts[next].y) / 2)
            slimePath.addQuadCurve(to: mid, control: pts[i])
        }
        slimePath.closeSubpath()

        // Translucent jelly gradient with rim light
        context.fill(slimePath, with: .linearGradient(
            Gradient(colors: [lighting.primaryColor, lighting.secondaryColor]),
            startPoint: CGPoint(x: center.x - 20, y: center.y - 30),
            endPoint: CGPoint(x: center.x + 20, y: center.y + 35)
        ))

        context.stroke(slimePath, with: .color(lighting.rimLightColor), lineWidth: 2.0)
    }

    private static func drawCyberSentryBody(
        context: inout GraphicsContext,
        center: CGPoint,
        lighting: ProceduralColorEngine.LightingContext,
        time: Double
    ) {
        // Segmented levitating hull plates
        let hullRect = CGRect(x: center.x - 30, y: center.y - 25, width: 60, height: 50)
        let hull = RoundedRectangle(cornerRadius: 14).path(in: hullRect)

        context.fill(hull, with: .linearGradient(
            Gradient(colors: [Color(white: 0.22), Color(white: 0.12)]),
            startPoint: CGPoint(x: center.x, y: center.y - 25),
            endPoint: CGPoint(x: center.x, y: center.y + 25)
        ))
        context.stroke(hull, with: .color(lighting.primaryColor.opacity(0.8)), lineWidth: 2.0)

        // Floating Satellite Thrusters (Left & Right)
        let lThrusterY = center.y + CGFloat(sin(time * 4.0) * 3.0)
        let rThrusterY = center.y - CGFloat(sin(time * 4.0) * 3.0)

        let leftPod = Capsule().path(in: CGRect(x: center.x - 42, y: lThrusterY - 10, width: 9, height: 20))
        let rightPod = Capsule().path(in: CGRect(x: center.x + 33, y: rThrusterY - 10, width: 9, height: 20))

        context.fill(leftPod, with: .color(Color(white: 0.28)))
        context.stroke(leftPod, with: .color(lighting.primaryColor), lineWidth: 1.5)

        context.fill(rightPod, with: .color(Color(white: 0.28)))
        context.stroke(rightPod, with: .color(lighting.primaryColor), lineWidth: 1.5)
    }

    private static func drawPixelChibiBody(
        context: inout GraphicsContext,
        center: CGPoint,
        motion: CharacterMotionStateMachine,
        lighting: ProceduralColorEngine.LightingContext,
        time: Double
    ) {
        // Articulated Chibi Beast Body & Ears
        let bodyRect = CGRect(x: center.x - 28, y: center.y - 15, width: 56, height: 42)
        let body = RoundedRectangle(cornerRadius: 20).path(in: bodyRect)
        context.fill(body, with: .color(lighting.primaryColor))

        // Head
        let headRect = CGRect(x: center.x - 24, y: center.y - 38, width: 48, height: 40)
        let head = RoundedRectangle(cornerRadius: 18).path(in: headRect)
        context.fill(head, with: .color(lighting.primaryColor))
        context.stroke(head, with: .color(lighting.rimLightColor), lineWidth: 1.5)

        // Physics-driven floppy/pointed ears
        let earTilt = CGFloat(motion.headTiltAngle.degrees * 0.4)
        var leftEar = Path()
        leftEar.move(to: CGPoint(x: center.x - 20, y: center.y - 36))
        leftEar.addLine(to: CGPoint(x: center.x - 28 - earTilt, y: center.y - 56))
        leftEar.addLine(to: CGPoint(x: center.x - 10, y: center.y - 36))
        leftEar.closeSubpath()
        context.fill(leftEar, with: .color(lighting.primaryColor))

        var rightEar = Path()
        rightEar.move(to: CGPoint(x: center.x + 10, y: center.y - 36))
        rightEar.addLine(to: CGPoint(x: center.x + 28 - earTilt, y: center.y - 56))
        rightEar.addLine(to: CGPoint(x: center.x + 20, y: center.y - 36))
        rightEar.closeSubpath()
        context.fill(rightEar, with: .color(lighting.primaryColor))

        // Tail wag
        var tailPath = Path()
        let tailEnd = CGPoint(x: center.x - 36 + CGFloat(sin(time * 5.0) * 8.0), y: center.y + 6)
        tailPath.move(to: CGPoint(x: center.x - 24, y: center.y + 12))
        tailPath.addQuadCurve(to: tailEnd, control: CGPoint(x: center.x - 38, y: center.y + 20))
        context.stroke(tailPath, with: .color(lighting.secondaryColor), lineWidth: 4.0)
    }

    private static func drawClassicSpeciesBody(
        context: inout GraphicsContext,
        center: CGPoint,
        species: PetSpecies,
        animState: PetAnimState,
        motion: CharacterMotionStateMachine,
        lighting: ProceduralColorEngine.LightingContext,
        time: Double
    ) {
        // Render crisp native shapes for classic species
        let bodyRect = CGRect(x: center.x - 30, y: center.y - 20, width: 60, height: 48)
        let body = RoundedRectangle(cornerRadius: 22).path(in: bodyRect)
        context.fill(body, with: .color(species.accentColor))
        context.stroke(body, with: .color(lighting.rimLightColor), lineWidth: 1.5)

        // Species-specific appendages
        switch species {
        case .cat, .robotcat, .fox:
            // Ears
            var lEar = Path()
            lEar.move(to: CGPoint(x: center.x - 24, y: center.y - 20))
            lEar.addLine(to: CGPoint(x: center.x - 30, y: center.y - 38))
            lEar.addLine(to: CGPoint(x: center.x - 12, y: center.y - 20))
            lEar.closeSubpath()
            context.fill(lEar, with: .color(species.accentColor))

            var rEar = Path()
            rEar.move(to: CGPoint(x: center.x + 12, y: center.y - 20))
            rEar.addLine(to: CGPoint(x: center.x + 30, y: center.y - 38))
            rEar.addLine(to: CGPoint(x: center.x + 24, y: center.y - 20))
            rEar.closeSubpath()
            context.fill(rEar, with: .color(species.accentColor))

        case .bunny:
            // Long Bunny Ears
            let lEar = Capsule().path(in: CGRect(x: center.x - 20, y: center.y - 50, width: 12, height: 35))
            let rEar = Capsule().path(in: CGRect(x: center.x + 8, y: center.y - 50, width: 12, height: 35))
            context.fill(lEar, with: .color(species.accentColor))
            context.fill(rEar, with: .color(species.accentColor))

        case .dragon:
            // Dragon Horns
            var hornL = Path()
            hornL.move(to: CGPoint(x: center.x - 18, y: center.y - 20))
            hornL.addLine(to: CGPoint(x: center.x - 26, y: center.y - 40))
            hornL.addLine(to: CGPoint(x: center.x - 10, y: center.y - 20))
            hornL.closeSubpath()
            context.fill(hornL, with: .color(Color(red: 180/255, green: 83/255, blue: 9/255)))

            var hornR = Path()
            hornR.move(to: CGPoint(x: center.x + 10, y: center.y - 20))
            hornR.addLine(to: CGPoint(x: center.x + 26, y: center.y - 40))
            hornR.addLine(to: CGPoint(x: center.x + 18, y: center.y - 20))
            hornR.closeSubpath()
            context.fill(hornR, with: .color(Color(red: 180/255, green: 83/255, blue: 9/255)))

        case .robot:
            // Antenna with pulse dot
            var antenna = Path()
            antenna.move(to: CGPoint(x: center.x, y: center.y - 20))
            antenna.addLine(to: CGPoint(x: center.x, y: center.y - 38))
            context.stroke(antenna, with: .color(Color.gray), lineWidth: 2.5)

            let dot = Circle().path(in: CGRect(x: center.x - 5, y: center.y - 45, width: 10, height: 10))
            context.fill(dot, with: .color(Color.red))

        case .ghost:
            // Wavy bottom skirt
            break
        }
    }

    // MARK: - Layer 3: Clothing / Skin / Textures

    private static func drawClothingSkinLayer(
        context: inout GraphicsContext,
        center: CGPoint,
        model: CharacterStructuralModel,
        species: PetSpecies,
        lighting: ProceduralColorEngine.LightingContext,
        time: Double
    ) {
        switch model {
        case .kineticSlime:
            // Internal floating gelatinous nucleus and highlight
            let highlight = Ellipse().path(in: CGRect(x: center.x - 16, y: center.y - 22, width: 12, height: 7))
            context.fill(highlight, with: .color(Color.white.opacity(0.55)))

            let nucleus = Circle().path(in: CGRect(x: center.x - 7, y: center.y - 5, width: 14, height: 14))
            context.fill(nucleus, with: .color(Color.white.opacity(0.2)))

        case .cyberSentry:
            // Glowing neon circuit traces
            var circuits = Path()
            circuits.move(to: CGPoint(x: center.x - 18, y: center.y + 14))
            circuits.addLine(to: CGPoint(x: center.x - 8, y: center.y + 14))
            circuits.addLine(to: CGPoint(x: center.x, y: center.y + 20))
            circuits.addLine(to: CGPoint(x: center.x + 8, y: center.y + 14))
            circuits.addLine(to: CGPoint(x: center.x + 18, y: center.y + 14))
            context.stroke(circuits, with: .color(lighting.primaryColor.opacity(0.85)), lineWidth: 1.5)

        case .pixelChibiBeast, .classicSpecies:
            // Soft belly patch
            let belly = Ellipse().path(in: CGRect(x: center.x - 14, y: center.y + 2, width: 28, height: 20))
            context.fill(belly, with: .color(Color.white.opacity(0.35)))
        }
    }

    // MARK: - Layer 4: Facial Features & Gaze Tracking

    private static func drawFacialFeaturesLayer(
        context: inout GraphicsContext,
        center: CGPoint,
        model: CharacterStructuralModel,
        species: PetSpecies,
        animState: PetAnimState,
        motion: CharacterMotionStateMachine,
        lighting: ProceduralColorEngine.LightingContext,
        time: Double
    ) {
        if model == .cyberSentry {
            // High-Tech Cyber Visor with Audio/Scan Pulse
            let visorRect = CGRect(x: center.x - 22, y: center.y - 12, width: 44, height: 14)
            let visor = RoundedRectangle(cornerRadius: 6).path(in: visorRect)
            context.fill(visor, with: .color(Color.black.opacity(0.85)))

            let scanX = center.x - 18 + CGFloat(sin(time * 6.0) * 14.0)
            let scanDot = Rectangle().path(in: CGRect(x: scanX, y: center.y - 10, width: 8, height: 10))
            context.fill(scanDot, with: .color(lighting.primaryColor))
            return
        }

        let eyeY = center.y - 8
        let leftEyeX = center.x - 14 + motion.eyeOffset.x
        let rightEyeX = center.x + 14 + motion.eyeOffset.x
        let gazeY = eyeY + motion.eyeOffset.y

        // Organic Micro-Blink: when blinkProgress > 0, height squeezes to a flat arc
        let openEyeHeight: CGFloat = animState == .shock ? 14.0 : 10.0
        let eyeWidth: CGFloat = animState == .shock ? 12.0 : 9.0
        let currentEyeHeight = max(1.5, openEyeHeight * (1.0 - motion.blinkProgress))

        if animState == .sleep || motion.blinkProgress >= 0.85 {
            // Closed Sleeping/Blinking Eye Arcs
            var lArc = Path()
            lArc.addArc(center: CGPoint(x: leftEyeX, y: eyeY), radius: 5, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            context.stroke(lArc, with: .color(Color(white: 0.15)), lineWidth: 2.2)

            var rArc = Path()
            rArc.addArc(center: CGPoint(x: rightEyeX, y: eyeY), radius: 5, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            context.stroke(rArc, with: .color(Color(white: 0.15)), lineWidth: 2.2)
        } else {
            // Open Expressive Eyes
            let lEye = Ellipse().path(in: CGRect(x: leftEyeX - eyeWidth/2, y: gazeY - currentEyeHeight/2, width: eyeWidth, height: currentEyeHeight))
            let rEye = Ellipse().path(in: CGRect(x: rightEyeX - eyeWidth/2, y: gazeY - currentEyeHeight/2, width: eyeWidth, height: currentEyeHeight))

            context.fill(lEye, with: .color(Color(white: 0.12)))
            context.fill(rEye, with: .color(Color(white: 0.12)))

            // Gaze Highlights
            if currentEyeHeight > 4 {
                let lSpark = Circle().path(in: CGRect(x: leftEyeX - 2, y: gazeY - 3, width: 3.5, height: 3.5))
                let rSpark = Circle().path(in: CGRect(x: rightEyeX - 2, y: gazeY - 3, width: 3.5, height: 3.5))
                context.fill(lSpark, with: .color(Color.white))
                context.fill(rSpark, with: .color(Color.white))
            }
        }

        // Cute Blush Marks
        let lBlush = Ellipse().path(in: CGRect(x: center.x - 25, y: center.y - 1, width: 7, height: 4))
        let rBlush = Ellipse().path(in: CGRect(x: center.x + 18, y: center.y - 1, width: 7, height: 4))
        context.fill(lBlush, with: .color(Color.pink.opacity(0.45)))
        context.fill(rBlush, with: .color(Color.pink.opacity(0.45)))

        // Mouth (Conversational bounce when streaming, smile when idle)
        var mouth = Path()
        if motion.state == .streamingResponse {
            let mouthHeight = CGFloat(abs(sin(time * 12.0)) * 6.0)
            let mouthRect = CGRect(x: center.x - 4, y: center.y + 4, width: 8, height: mouthHeight + 2)
            context.fill(Ellipse().path(in: mouthRect), with: .color(Color(red: 180/255, green: 83/255, blue: 9/255)))
        } else {
            mouth.move(to: CGPoint(x: center.x - 4, y: center.y + 5))
            mouth.addQuadCurve(to: CGPoint(x: center.x + 4, y: center.y + 5), control: CGPoint(x: center.x, y: center.y + 8))
            context.stroke(mouth, with: .color(Color(white: 0.2)), lineWidth: 1.8)
        }
    }

    // MARK: - Layer 5: Floating Accessories & Weather

    private static func drawAccessoriesLayer(
        context: inout GraphicsContext,
        size: CGSize,
        center: CGPoint,
        motion: CharacterMotionStateMachine,
        atmosphere: WeatherAtmosphere,
        animState: PetAnimState,
        time: Double
    ) {
        // 1. Procedural Floating Thought Sparks (.thinking)
        for spark in motion.thoughtSparks {
            var sparkPath = Path()
            sparkPath.addEllipse(in: CGRect(x: spark.x - spark.size/2, y: spark.y - spark.size/2, width: spark.size, height: spark.size))
            let sparkColor = Color(hue: spark.hue, saturation: 0.8, brightness: 1.0)
            context.fill(sparkPath, with: .color(sparkColor.opacity(spark.alpha)))
        }

        // 2. Celebratory Confetti Bursts (.dancing)
        for conf in motion.confettiList {
            var confContext = context
            confContext.translateBy(x: conf.x, y: conf.y)
            confContext.rotate(by: .degrees(conf.rotation))
            let rect = CGRect(x: -conf.size.width/2, y: -conf.size.height/2, width: conf.size.width, height: conf.size.height)
            confContext.fill(Rectangle().path(in: rect), with: .color(conf.color.opacity(1.0 - conf.life)))
        }

        // 3. Dynamic Weather Atmosphere Overlay
        for p in motion.weatherParticles {
            switch atmosphere {
            case .rain, .thunderstorm:
                var rainPath = Path()
                rainPath.move(to: CGPoint(x: p.x, y: p.y))
                rainPath.addLine(to: CGPoint(x: p.x + p.vx * 0.05, y: p.y + p.length))
                context.stroke(rainPath, with: .color(Color(red: 186/255, green: 230/255, blue: 253/255).opacity(p.alpha)), lineWidth: p.size)

            case .snow:
                let flake = Circle().path(in: CGRect(x: p.x - p.size/2, y: p.y - p.size/2, width: p.size, height: p.size))
                context.fill(flake, with: .color(Color.white.opacity(p.alpha)))

            default:
                break
            }
        }
    }
}
