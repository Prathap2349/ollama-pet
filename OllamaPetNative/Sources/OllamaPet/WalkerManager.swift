import Foundation
import AppKit
import SwiftUI

@MainActor
public class WalkerManager: ObservableObject {
    public static let shared = WalkerManager()

    private var walkerPanel: NSPanel?
    private var isWalking = false

    public init() {}

    public func startWalk(species: PetSpecies, isTest: Bool = false) {
        guard !isWalking else { return }
        isWalking = true

        guard let screen = NSScreen.main else {
            isWalking = false
            return
        }

        let screenFrame = screen.visibleFrame
        let panelHeight: CGFloat = 120
        let panelWidth = isTest ? min(480, screenFrame.width) : screenFrame.width
        let panelX = isTest ? (screenFrame.midX - panelWidth / 2) : screenFrame.minX

        let panelFrame = NSRect(
            x: panelX,
            y: screenFrame.minY + 12,
            width: panelWidth,
            height: panelHeight
        )

        let panel = NSPanel(
            contentRect: panelFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let speedMultiplier = DataManager.shared.savedData.walkSpeed ?? 1.0
        let gaitPreset = CharacterMotionStateMachine.shared.gaitPreset

        let walkView = WalkerAnimationView(
            species: species,
            gait: gaitPreset,
            screenWidth: panelWidth,
            speedMultiplier: speedMultiplier,
            isTest: isTest,
            onComplete: { [weak self] in
                Task { @MainActor in
                    self?.walkerPanel?.close()
                    self?.walkerPanel = nil
                    self?.isWalking = false
                    CharacterMotionStateMachine.shared.transitionTo(.idle)
                }
            }
        )

        panel.contentView = NSHostingView(rootView: walkView)
        panel.orderFrontRegardless()
        self.walkerPanel = panel
    }
}

struct WalkerAnimationView: View {
    let species: PetSpecies
    let gait: WalkGaitPreset
    let screenWidth: CGFloat
    let speedMultiplier: Double
    let isTest: Bool
    let onComplete: () -> Void

    @State private var xOffset: CGFloat = -80
    @State private var isFlipped: Bool = false
    @ObservedObject var motion = CharacterMotionStateMachine.shared
    @ObservedObject var sysMon = SystemMonitor.shared
    @ObservedObject var perf = PerformanceManager.shared

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
            walkerCanvasView
        }
        .frame(width: screenWidth, height: 110)
        .onAppear {
            motion.transitionTo(.walking(gait: gait))
            runWalkSequence()
        }
    }

    private var walkerCanvasView: some View {
        TimelineView(.animation(minimumInterval: perf.minimumRenderInterval)) { (timeline: TimelineViewDefaultContext) in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let snapshot = motion.evaluateSnapshot(
                    at: t,
                    animState: .idle,
                    atmosphere: perf.weatherEffectsEnabled ? WeatherService.shared.activeAtmosphere : .clearDay,
                    isSafeMode: perf.isSafeMode
                )
                let model = CharacterStructuralModel.model(for: species)

                // Secondary Inertial Lag angle
                let inertialAngle: Angle
                switch gait {
                case .bouncyMarch:
                    inertialAngle = .degrees(isFlipped ? -4 : 4)
                case .stealthProwl:
                    inertialAngle = .degrees(isFlipped ? 8 : -8)
                case .hoverGlide:
                    inertialAngle = .degrees(isFlipped ? 12 : -12)
                }

                var walkerContext = context
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                walkerContext.translateBy(x: center.x, y: center.y)
                if isFlipped {
                    walkerContext.scaleBy(x: -1, y: 1)
                }
                walkerContext.rotate(by: inertialAngle)
                walkerContext.translateBy(x: -center.x, y: -center.y)

                PetCanvasRenderer.draw(
                    context: &walkerContext,
                    size: size,
                    species: species,
                    model: model,
                    animState: .idle,
                    mood: PetState.shared.currentMood,
                    snapshot: snapshot,
                    perf: perf
                )
            }
            .frame(width: 80, height: 80)
            .offset(x: xOffset, y: -10)
        }
    }

    private func runWalkSequence() {
        let baseDuration: Double = isTest ? 3.5 : 7.0
        let effectiveDuration = max(1.5, baseDuration / max(0.5, speedMultiplier))

        // Phase 1: Forward walk (left to right)
        withAnimation(.linear(duration: effectiveDuration)) {
            xOffset = screenWidth + 20
        }

        Task {
            try? await Task.sleep(nanoseconds: UInt64(effectiveDuration * 1_000_000_000))
            isFlipped = true
            try? await Task.sleep(nanoseconds: 200_000_000)

            // Phase 2: Walk backward (right to left)
            withAnimation(.linear(duration: effectiveDuration)) {
                xOffset = -80
            }

            try? await Task.sleep(nanoseconds: UInt64(effectiveDuration * 1_000_000_000))
            onComplete()
        }
    }
}
