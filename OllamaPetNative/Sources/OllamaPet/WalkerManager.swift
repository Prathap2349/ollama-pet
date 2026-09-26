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
        let panelHeight: CGFloat = 140
        let panelWidth = isTest ? min(480, screenFrame.width) : screenFrame.width
        let panelX = isTest ? (screenFrame.midX - panelWidth / 2) : screenFrame.minX

        let panelFrame = NSRect(
            x: panelX,
            y: screenFrame.minY + 8,
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

        PetState.shared.animState = .walk

        let walkView = WalkerAnimationView(
            species: species,
            screenWidth: panelWidth,
            speedMultiplier: speedMultiplier,
            isTest: isTest,
            onComplete: { [weak self] in
                Task { @MainActor in
                    self?.walkerPanel?.close()
                    self?.walkerPanel = nil
                    self?.isWalking = false
                    PetState.shared.animState = .idle
                    CharacterMotionStateMachine.shared.transitionTo(.idle)
                }
            }
        )

        panel.contentView = NSHostingView(rootView: walkView)
        panel.orderFrontRegardless()
        self.walkerPanel = panel
    }
}

// MARK: - Unified 3D Walker View (Requirement 6 - Same 3D Character Throughout)

struct WalkerAnimationView: View {
    let species: PetSpecies
    let screenWidth: CGFloat
    let speedMultiplier: Double
    let isTest: Bool
    let onComplete: () -> Void

    @State private var xOffset: CGFloat = -100
    @State private var isFlipped: Bool = false
    @ObservedObject var petState = PetState.shared
    @ObservedObject var perf = PerformanceManager.shared

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear

            // Uses the EXACT same 3D Character Rig, SceneKit Engine, Lighting, and Accessories
            Pet3DSceneView()
                .frame(width: 120, height: 120)
                .scaleEffect(x: isFlipped ? -1 : 1, y: 1)
                .offset(x: xOffset, y: 0)
        }
        .frame(width: screenWidth, height: 130)
        .onAppear {
            petState.animState = .walk
            runWalkSequence()
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
                xOffset = -100
            }

            try? await Task.sleep(nanoseconds: UInt64(effectiveDuration * 1_000_000_000))
            onComplete()
        }
    }
}
