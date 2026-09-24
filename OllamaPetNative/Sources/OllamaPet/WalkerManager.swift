import Foundation
import AppKit
import SwiftUI

@MainActor
public class WalkerManager: ObservableObject {
    public static let shared = WalkerManager()

    private var walkerPanel: NSPanel?
    private var isWalking = false

    public init() {}

    public func startWalk(species: PetSpecies) {
        guard !isWalking else { return }
        isWalking = true

        guard let screen = NSScreen.main else {
            isWalking = false
            return
        }

        let screenFrame = screen.visibleFrame
        let panelHeight: CGFloat = 100
        let panelFrame = NSRect(
            x: screenFrame.minX,
            y: screenFrame.minY + 10,
            width: screenFrame.width,
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

        let walkSvg = PetSVGProvider.walkSvg(for: species)
        let walkView = WalkerAnimationView(
            svgString: walkSvg,
            screenWidth: screenFrame.width,
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
    let svgString: String
    let screenWidth: CGFloat
    let onComplete: () -> Void

    @State private var xOffset: CGFloat = -100
    @State private var isFlipped: Bool = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear

            if let data = svgString.data(using: .utf8), let nsImg = NSImage(data: data) {
                Image(nsImage: nsImg)
                    .resizable()
                    .frame(width: 60, height: 60)
                    .scaleEffect(x: isFlipped ? -1 : 1, y: 1)
                    .offset(x: xOffset, y: -10)
            }
        }
        .frame(width: screenWidth, height: 100)
        .onAppear {
            runWalkSequence()
        }
    }

    private func runWalkSequence() {
        let forwardDuration = Double.random(in: 6.0...8.0)
        let backwardDuration = Double.random(in: 6.0...8.0)

        // Phase 1: Forward walk (left to right)
        withAnimation(.linear(duration: forwardDuration)) {
            xOffset = screenWidth + 50
        }

        // Phase 2: Pause 200ms, flip, then walk backward (right to left)
        Task {
            try? await Task.sleep(nanoseconds: UInt64(forwardDuration * 1_000_000_000))
            isFlipped = true
            try? await Task.sleep(nanoseconds: 200_000_000)

            withAnimation(.linear(duration: backwardDuration)) {
                xOffset = -100
            }

            try? await Task.sleep(nanoseconds: UInt64(backwardDuration * 1_000_000_000))
            onComplete()
        }
    }
}
