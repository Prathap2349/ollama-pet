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
        let panelHeight: CGFloat = 110
        let panelWidth = isTest ? min(480, screenFrame.width) : screenFrame.width
        let panelX = isTest ? (screenFrame.midX - panelWidth / 2) : screenFrame.minX

        let panelFrame = NSRect(
            x: panelX,
            y: screenFrame.minY + 15,
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
    let screenWidth: CGFloat
    let speedMultiplier: Double
    let isTest: Bool
    let onComplete: () -> Void

    @State private var xOffset: CGFloat = -80
    @State private var isFlipped: Bool = false
    @State private var animTime: Double = 0.0
    @State private var timer: Timer?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear

            let svgStr = PetSVGProvider.walkSvg(for: species, t: animTime)
            if let data = svgStr.data(using: .utf8), let nsImg = NSImage(data: data) {
                Image(nsImage: nsImg)
                    .resizable()
                    .frame(width: 70, height: 70)
                    .scaleEffect(x: isFlipped ? -1 : 1, y: 1)
                    .offset(x: xOffset, y: -10)
            }
        }
        .frame(width: screenWidth, height: 100)
        .onAppear {
            startAnimationLoop()
            runWalkSequence()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func startAnimationLoop() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            Task { @MainActor in
                self.animTime += 1.0 / 30.0
            }
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
            timer?.invalidate()
            timer = nil
            onComplete()
        }
    }
}
