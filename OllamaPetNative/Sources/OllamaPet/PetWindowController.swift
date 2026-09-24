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
    private var initialWindowOrigin: NSPoint = .zero
    private var isDragging = false
    private let dragThreshold: CGFloat = 5.0
    private var clickCount = 0
    private var clickTimer: Timer?

    override public func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }
        initialMouseLocation = NSEvent.mouseLocation
        initialWindowOrigin = window.frame.origin
        isDragging = false
    }

    override public func mouseDragged(with event: NSEvent) {
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
            var newOrigin = NSPoint(
                x: initialWindowOrigin.x + dx,
                y: initialWindowOrigin.y + dy
            )

            // Clamp to screen bounds
            if let screen = window.screen ?? NSScreen.main {
                let screenFrame = screen.visibleFrame
                let winFrame = window.frame

                let minX = screenFrame.minX
                let maxX = screenFrame.maxX - winFrame.width
                let minY = screenFrame.minY
                let maxY = screenFrame.maxY - winFrame.height

                newOrigin.x = max(minX, min(maxX, newOrigin.x))
                newOrigin.y = max(minY, min(maxY, newOrigin.y))
            }

            window.setFrameOrigin(newOrigin)
        }
    }

    override public func mouseUp(with event: NSEvent) {
        guard let window = self.window else { return }

        if isDragging {
            isDragging = false
            // Snap to corner if within 25px
            snapToCornerIfNeeded(window: window)
            // Persist position
            DataManager.shared.updatePosition(x: Double(window.frame.origin.x), y: Double(window.frame.origin.y))
        } else {
            // It was a click!
            handleClick()
        }
    }

    private func snapToCornerIfNeeded(window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        var origin = window.frame.origin
        let snapDist: CGFloat = 25.0

        if abs(origin.x - screenFrame.minX) < snapDist {
            origin.x = screenFrame.minX
        } else if abs(origin.x - (screenFrame.maxX - window.frame.width)) < snapDist {
            origin.x = screenFrame.maxX - window.frame.width
        }

        if abs(origin.y - screenFrame.minY) < snapDist {
            origin.y = screenFrame.minY
        } else if abs(origin.y - (screenFrame.maxY - window.frame.height)) < snapDist {
            origin.y = screenFrame.maxY - window.frame.height
        }

        window.setFrameOrigin(origin)
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
        let initialWidth: CGFloat = 140
        let initialHeight: CGFloat = 140

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        // Saved position or default bottom right
        var originX = screenFrame.maxX - initialWidth - 30
        var originY = screenFrame.minY + 40

        if let savedPos = DataManager.shared.savedData.position {
            // Verify within visible bounds
            originX = CGFloat(savedPos.x)
            originY = CGFloat(savedPos.y)

            // Clamp to screen
            originX = max(screenFrame.minX, min(screenFrame.maxX - initialWidth, originX))
            originY = max(screenFrame.minY, min(screenFrame.maxY - initialHeight, originY))
        }

        let contentRect = NSRect(x: originX, y: originY, width: initialWidth, height: initialHeight)

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

    @objc private func screenParametersChanged() {
        guard let win = window else { return }
        let currentOrigin = win.frame.origin
        var targetScreen: NSScreen? = nil

        for s in NSScreen.screens {
            if s.frame.contains(currentOrigin) {
                targetScreen = s
                break
            }
        }

        let activeScreen = targetScreen ?? NSScreen.main
        if let screen = activeScreen {
            let sFrame = screen.visibleFrame
            var clampedX = currentOrigin.x
            var clampedY = currentOrigin.y

            clampedX = max(sFrame.minX, min(sFrame.maxX - win.frame.width, clampedX))
            clampedY = max(sFrame.minY, min(sFrame.maxY - win.frame.height, clampedY))

            win.setFrameOrigin(NSPoint(x: clampedX, y: clampedY))
        }
    }

    public func adjustWindowSize(open: Bool) {
        guard let win = window else { return }
        let width: CGFloat = open ? 340 : 140
        let height: CGFloat = open ? 620 : 140

        var frame = win.frame
        let oldHeight = frame.height

        frame.size.width = width
        frame.size.height = height

        // When expanding upwards
        frame.origin.y -= (height - oldHeight)

        // Keep on screen
        if let screen = win.screen ?? NSScreen.main {
            let sFrame = screen.visibleFrame
            if frame.minY < sFrame.minY {
                frame.origin.y = sFrame.minY
            }
            if frame.maxX > sFrame.maxX {
                frame.origin.x = sFrame.maxX - frame.width
            }
        }

        win.setFrame(frame, display: true, animate: true)
    }

    public func setCompanionMode(clickThrough: Bool) {
        isCompanionClickThrough = clickThrough
        window?.ignoresMouseEvents = clickThrough
    }
}
