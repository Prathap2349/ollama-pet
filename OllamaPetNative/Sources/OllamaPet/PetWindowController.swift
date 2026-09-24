import Foundation
import AppKit
import SwiftUI

public class CustomPetPanel: NSPanel {
    override public var canBecomeKey: Bool {
        return true
    }

    override public var canBecomeMain: Bool {
        return true
    }
}

public class DraggableHostingView<Content: View>: NSHostingView<Content> {
    private var initialMouseLocation: NSPoint = .zero
    private var initialPetOrigin: NSPoint = .zero
    private var isDragging = false
    private let dragThreshold: CGFloat = 5.0
    private var clickCount = 0
    private var clickTimer: Timer?

    /// Checks if a mouse event is within the pet 140x140 area
    private func isEventInPetArea(_ event: NSEvent) -> Bool {
        let localLoc = convert(event.locationInWindow, from: nil)
        let petRect = PetWindowController.shared.currentPetRectInWindow()
        return petRect.contains(localLoc)
    }

    override public func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        // If chat is open and click is outside pet stage and outside panel content, ignore
        return hit
    }

    override public func mouseDown(with event: NSEvent) {
        if !isEventInPetArea(event) {
            // Mouse down inside chat panel or settings — let SwiftUI handle it normally
            super.mouseDown(with: event)
            return
        }

        // Mouse down inside pet area — prepare for drag or pet click
        initialMouseLocation = NSEvent.mouseLocation
        initialPetOrigin = PetWindowController.shared.petOrigin
        isDragging = false
    }

    override public func mouseDragged(with event: NSEvent) {
        if !isEventInPetArea(event) && !isDragging {
            super.mouseDragged(with: event)
            return
        }

        guard let window = self.window else { return }
        let currentMouseLocation = NSEvent.mouseLocation
        let dx = currentMouseLocation.x - initialMouseLocation.x
        let dy = currentMouseLocation.y - initialMouseLocation.y

        if !isDragging {
            let dist = sqrt(dx * dx + dy * dy)
            if dist > dragThreshold {
                isDragging = true
            }
        }

        if isDragging {
            var newPetOrigin = NSPoint(
                x: initialPetOrigin.x + dx,
                y: initialPetOrigin.y + dy
            )

            // Clamp pet coordinates to screen bounds (pet is 140x140)
            if let screen = window.screen ?? NSScreen.main {
                let screenFrame = screen.visibleFrame
                let minX = screenFrame.minX
                let maxX = screenFrame.maxX - 140
                let minY = screenFrame.minY
                let maxY = screenFrame.maxY - 140

                newPetOrigin.x = max(minX, min(maxX, newPetOrigin.x))
                newPetOrigin.y = max(minY, min(maxY, newPetOrigin.y))
            }

            PetWindowController.shared.updatePetOriginFromDrag(newPetOrigin)
        }
    }

    override public func mouseUp(with event: NSEvent) {
        if !isEventInPetArea(event) && !isDragging {
            super.mouseUp(with: event)
            return
        }

        guard let window = self.window else { return }

        if isDragging {
            isDragging = false
            snapPetToCornerIfNeeded(window: window)
            let origin = PetWindowController.shared.petOrigin
            DataManager.shared.updatePosition(x: Double(origin.x), y: Double(origin.y))
        } else {
            // Click inside pet area!
            handleClick()
        }
    }

    private func snapPetToCornerIfNeeded(window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        var origin = PetWindowController.shared.petOrigin
        let snapDist: CGFloat = 25.0

        if abs(origin.x - screenFrame.minX) < snapDist {
            origin.x = screenFrame.minX
        } else if abs(origin.x - (screenFrame.maxX - 140)) < snapDist {
            origin.x = screenFrame.maxX - 140
        }

        if abs(origin.y - screenFrame.minY) < snapDist {
            origin.y = screenFrame.minY
        } else if abs(origin.y - (screenFrame.maxY - 140)) < snapDist {
            origin.y = screenFrame.maxY - 140
        }

        PetWindowController.shared.updatePetOriginFromDrag(origin)
    }

    private func handleClick() {
        let petState = PetState.shared
        if petState.animState == .sleep {
            petState.animState = .idle
            petState.showBubble("*yawns* 😴")
            SoundEffect.wake.play()
            petState.resetSleepTimer()
            return
        }

        clickCount += 1
        clickTimer?.invalidate()
        clickTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
            self?.clickCount = 0
        }

        if clickCount >= 5 {
            clickCount = 0
            petState.animState = .dance
            petState.showBubble("Wheee! 🎉")
            SoundEffect.receive.play()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 4_500_000_000)
                if petState.animState == .dance {
                    petState.animState = .idle
                }
            }
            return
        }

        SoundEffect.click.play()
        petState.isChatOpen.toggle()

        if petState.isChatOpen {
            petState.resetSleepTimer()
            petState.showBubble(petState.currentSpecies.greetings.randomElement() ?? "Hello!")
            petState.moodPoints = min(100.0, petState.moodPoints + 8.0)
            DataManager.shared.updateStreak()
        }

        PetWindowController.shared.adjustWindowSize(open: petState.isChatOpen)
    }
}

@MainActor
public class PetWindowController: NSObject, NSWindowDelegate {
    public static let shared = PetWindowController()

    public var window: CustomPetPanel?
    private var isCompanionClickThrough = false

    /// Authoritative screen coordinates of the 140x140 pet stage
    public private(set) var petOrigin: NSPoint = .zero

    /// Active layout anchor: determines which side panel appears relative to pet
    public private(set) var currentAnchor = PanelAnchor(isLeft: false, isTop: false)

    override public init() {
        super.init()
    }

    public func showWindow() {
        if window == nil {
            setupWindow()
        }
        window?.orderFrontRegardless()
    }

    public func toggleVisibility() {
        guard let win = window else {
            showWindow()
            return
        }
        if win.isVisible {
            win.orderOut(nil)
        } else {
            win.orderFrontRegardless()
            PetState.shared.showBubble("👋 I'm back!", duration: 1.5)
        }
    }

    private func setupWindow() {
        let petSize: CGFloat = 140
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        // Saved position or default bottom right
        var originX = screenFrame.maxX - petSize - 30
        var originY = screenFrame.minY + 40

        if let savedPos = DataManager.shared.savedData.position {
            originX = CGFloat(savedPos.x)
            originY = CGFloat(savedPos.y)

            // Clamp to screen
            originX = max(screenFrame.minX, min(screenFrame.maxX - petSize, originX))
            originY = max(screenFrame.minY, min(screenFrame.maxY - petSize, originY))
        }

        self.petOrigin = NSPoint(x: originX, y: originY)
        recomputeAnchor()

        let contentRect = NSRect(x: originX, y: originY, width: petSize, height: petSize)

        let panel = CustomPetPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.delegate = self

        let stageView = PetStageView()
        let hostingView = DraggableHostingView(rootView: stageView)
        panel.contentView = hostingView

        self.window = panel

        // Listen for screen layout changes (multi-monitor disconnects/reconnects)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    public func recomputeAnchor() {
        guard let screen = window?.screen ?? NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        // If pet is on left half of screen, anchor panel to its right (isLeft = true)
        // If pet is on upper half of screen, anchor panel below it (isTop = true)
        let isLeft = petOrigin.x < screenFrame.midX
        let isTop = petOrigin.y > screenFrame.midY
        self.currentAnchor = PanelAnchor(isLeft: isLeft, isTop: isTop)
        PetState.shared.activeAnchor = self.currentAnchor
    }

    /// Returns the local CGRect of the 140x140 pet stage within the window's content view
    public func currentPetRectInWindow() -> NSRect {
        guard let win = window else { return NSRect(x: 0, y: 0, width: 140, height: 140) }
        let petSize: CGFloat = 140
        if !PetState.shared.isChatOpen {
            return NSRect(x: 0, y: 0, width: petSize, height: petSize)
        }

        // When open, compute based on currentAnchor
        // Window size: width 340, height 620
        // Pet stage is 140x140
        let localX: CGFloat = currentAnchor.isLeft ? 0 : (win.frame.width - petSize)
        let localY: CGFloat = currentAnchor.isTop ? (win.frame.height - petSize) : 0
        return NSRect(x: localX, y: localY, width: petSize, height: petSize)
    }

    public func updatePetOriginFromDrag(_ newPetOrigin: NSPoint) {
        self.petOrigin = newPetOrigin
        recomputeAnchor()
        guard let win = window else { return }

        if !PetState.shared.isChatOpen {
            win.setFrameOrigin(newPetOrigin)
        } else {
            // Position full window such that the pet subrect stays at petOrigin
            let winFrame = calculateWindowFrame(forPetOrigin: newPetOrigin, open: true)
            win.setFrame(winFrame, display: true, animate: false)
        }
    }

    private func calculateWindowFrame(forPetOrigin origin: NSPoint, open: Bool) -> NSRect {
        let petSize: CGFloat = 140
        if !open {
            return NSRect(x: origin.x, y: origin.y, width: petSize, height: petSize)
        }

        let width: CGFloat = 340
        let height: CGFloat = 620

        // Window origin is bottom-left corner of the window in screen coords
        // If currentAnchor.isLeft: pet is at left edge of window -> window.origin.x = petOrigin.x
        // If !currentAnchor.isLeft: pet is at right edge of window -> window.origin.x = petOrigin.x + petSize - width
        let winX: CGFloat = currentAnchor.isLeft ? origin.x : (origin.x + petSize - width)

        // If currentAnchor.isTop: pet is at top of window -> window.origin.y = petOrigin.y + petSize - height
        // If !currentAnchor.isTop: pet is at bottom of window -> window.origin.y = petOrigin.y
        let winY: CGFloat = currentAnchor.isTop ? (origin.y + petSize - height) : origin.y

        return NSRect(x: winX, y: winY, width: width, height: height)
    }

    public func adjustWindowSize(open: Bool) {
        guard let win = window else { return }
        recomputeAnchor()
        let targetFrame = calculateWindowFrame(forPetOrigin: petOrigin, open: open)
        win.setFrame(targetFrame, display: true, animate: false)
    }

    public func closePanel() {
        PetState.shared.isChatOpen = false
        adjustWindowSize(open: false)
    }

    @objc private func screenParametersChanged() {
        guard let win = window else { return }
        var targetScreen: NSScreen? = nil

        for s in NSScreen.screens {
            if s.frame.contains(petOrigin) {
                targetScreen = s
                break
            }
        }

        let activeScreen = targetScreen ?? NSScreen.main
        if let screen = activeScreen {
            let sFrame = screen.visibleFrame
            var clampedX = petOrigin.x
            var clampedY = petOrigin.y

            clampedX = max(sFrame.minX, min(sFrame.maxX - 140, clampedX))
            clampedY = max(sFrame.minY, min(sFrame.maxY - 140, clampedY))

            self.petOrigin = NSPoint(x: clampedX, y: clampedY)
            recomputeAnchor()
            let frame = calculateWindowFrame(forPetOrigin: petOrigin, open: PetState.shared.isChatOpen)
            win.setFrame(frame, display: true, animate: false)
        }
    }

    public func setCompanionMode(clickThrough: Bool) {
        isCompanionClickThrough = clickThrough
        window?.ignoresMouseEvents = clickThrough
    }
}
