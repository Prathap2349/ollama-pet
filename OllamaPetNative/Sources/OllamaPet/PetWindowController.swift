import Foundation
import AppKit
import SwiftUI

@MainActor
public enum PetWindowLayout {
    public static let basePetSize: CGFloat = 140
    public static let baseViewportSize: CGFloat = 120
    public static let baseIndicatorSize: CGFloat = 116
    public static let baseBubbleOffset: CGFloat = 58
    public static let baseThermalOffset: CGFloat = 52
    public static let baseChatWidth: CGFloat = 360
    public static let baseChatHeight: CGFloat = 620
    public static let baseChatContentHeight: CGFloat = 466
    public static let basePulseSize: CGFloat = 122
    public static let baseClosedBubbleClearance: CGFloat = 106

    public static var scale: CGFloat { PetWindowController.shared.petLayoutScale }
    public static var petSize: CGFloat { basePetSize * scale }
    public static var viewportSize: CGFloat { baseViewportSize * scale }
    public static var indicatorSize: CGFloat { baseIndicatorSize * scale }
    public static var pulseSize: CGFloat { basePulseSize * scale }
    public static var bubbleOffset: CGFloat {
        guard let screen = PetWindowController.shared.screenContainingPet else { return baseBubbleOffset * scale }
        let roomAbovePet = screen.visibleFrame.maxY - (PetWindowController.shared.petOrigin.y + petSize)
        return roomAbovePet < baseClosedBubbleClearance * scale ? 0 : baseBubbleOffset * scale
    }
    public static var thermalOffset: CGFloat { baseThermalOffset * scale }
    public static var chatScale: CGFloat { PetWindowController.shared.chatContentScale }
    public static var chatWidth: CGFloat { baseChatWidth * chatScale }
    public static var chatContentHeight: CGFloat { baseChatContentHeight * chatScale }
    public static var chatWindowWidth: CGFloat { max(petSize, chatWidth) }
    public static var chatWindowHeight: CGFloat { petSize + (baseChatHeight - basePetSize) * chatScale }
    public static var closedWindowHeight: CGFloat { petSize + baseClosedBubbleClearance * scale }
}

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

    /// Checks if a mouse event is within the visible pet stage.
    private func isEventInPetArea(_ event: NSEvent) -> Bool {
        let petRect = PetWindowController.shared.currentPetInteractiveRectInWindow()
        return petRect.contains(event.locationInWindow)
    }

    override public func hitTest(_ point: NSPoint) -> NSView? {
        if PetWindowController.shared.isCompanionClickThrough {
            return nil
        }

        let pointInWindow = superview?.convert(point, to: nil) ?? point
        let petRect = PetWindowController.shared.currentPetInteractiveRectInWindow()

        if !PetState.shared.isChatOpen {
            if petRect.contains(pointInWindow) { return self }
            return nil // Complete pass-through for transparent corners to underlying desktop
        }

        // Chat is open
        if petRect.contains(pointInWindow) {
            return self
        }

        let chatRect = PetWindowController.shared.currentChatPanelRectInWindow()
        if chatRect.contains(pointInWindow) {
            return super.hitTest(point)
        }

        // Point is in the transparent cutout area beside the pet stage — complete pass-through!
        return nil
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

        guard self.window != nil else { return }
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

            // Clamp the tracked pet stage, not the taller transparent bubble buffer.
            if let screen = PetWindowController.shared.screenForPetOrigin(newPetOrigin) ?? PetWindowController.shared.screenContainingPet {
                let screenFrame = screen.visibleFrame
                let minX = screenFrame.minX
                let maxX = max(minX, screenFrame.maxX - PetWindowLayout.petSize)
                let minY = screenFrame.minY
                let maxY = max(minY, screenFrame.maxY - PetWindowLayout.petSize)

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

        guard PetWindowController.shared.window != nil else { return }

        if isDragging {
            isDragging = false
            snapPetToCornerIfNeeded()
            let origin = PetWindowController.shared.petOrigin
            DataManager.shared.updatePosition(x: Double(origin.x), y: Double(origin.y))
        } else {
            // Click inside pet area!
            handleClick()
        }
    }

    private func snapPetToCornerIfNeeded() {
        guard let screen = PetWindowController.shared.screenContainingPet else { return }
        let screenFrame = screen.visibleFrame
        var origin = PetWindowController.shared.petOrigin
        let snapDist: CGFloat = 25.0

        if abs(origin.x - screenFrame.minX) < snapDist {
            origin.x = screenFrame.minX
        } else if abs(origin.x - (screenFrame.maxX - PetWindowLayout.petSize)) < snapDist {
            origin.x = screenFrame.maxX - PetWindowLayout.petSize
        }

        if abs(origin.y - screenFrame.minY) < snapDist {
            origin.y = screenFrame.minY
        } else if abs(origin.y - (screenFrame.maxY - PetWindowLayout.petSize)) < snapDist {
            origin.y = screenFrame.maxY - PetWindowLayout.petSize
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

        if clickCount >= 5 {
            // 5th click: dance, and cancel the pending chat toggle for this click sequence.
            clickCount = 0
            clickTimer = nil
            petState.startTimedDance(duration: 4.5)
            petState.showBubble("Wheee! 🎉")
            SoundEffect.receive.play()
            return
        }

        SoundEffect.click.play()

        // Wait for the click sequence to end (0.6s with no further click) before toggling the chat.
        clickTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.finishClickSequence()
            }
        }
    }

    /// Runs once, after the last click of a sequence that stayed below 5 clicks.
    private func finishClickSequence() {
        // A newer click already restarted the timer: this call belongs to an older sequence.
        if clickTimer?.isValid == true { return }
        clickTimer = nil
        clickCount = 0

        let petState = PetState.shared
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
public class PetWindowController: NSObject, ObservableObject, NSWindowDelegate {
    public static let shared = PetWindowController()

    public var window: CustomPetPanel?
    public var isCompanionClickThrough = false

    /// Authoritative screen coordinates of the scaled pet stage.
    public private(set) var petOrigin: NSPoint = .zero

    /// Active layout anchor: determines which side panel appears relative to pet
    public private(set) var currentAnchor = PanelAnchor(isLeft: false, isTop: false)
    @Published public private(set) var petLayoutScale: CGFloat = 1.0
    @Published public private(set) var chatContentScale: CGFloat = 1.0
    @Published public private(set) var layoutVersion: Int = 0

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
        let savedPosition = DataManager.shared.savedData.position.map { NSPoint(x: $0.x, y: $0.y) }
        let screen = savedPosition.flatMap { screenContainingPoint($0) }
            ?? screenUnderMouse
            ?? NSScreen.main
        guard let screen else { return }
        updatePetLayoutScale(for: screen)
        let screenFrame = screen.visibleFrame
        let petSize = PetWindowLayout.petSize

        let preferred = savedPosition ?? NSPoint(x: screenFrame.maxX - petSize - 30, y: screenFrame.minY + 40)
        self.petOrigin = clampedPetOrigin(preferred, to: screenFrame)
        recomputeAnchor()

        let contentRect = NSRect(x: petOrigin.x, y: petOrigin.y, width: petSize, height: PetWindowLayout.closedWindowHeight)

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
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
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
        guard let screen = screenContainingPet else { return }
        let screenFrame = screen.visibleFrame
        let petSize = PetWindowLayout.petSize
        let spaceRight = max(0, screenFrame.maxX - petOrigin.x)
        let spaceLeft = max(0, petOrigin.x + petSize - screenFrame.minX)
        let spaceBelow = max(0, petOrigin.y - screenFrame.minY)
        let spaceAbove = max(0, screenFrame.maxY - (petOrigin.y + petSize))
        let requestedScale = max(0.1, PetWindowLayout.scale)
        let verticalScale = max(spaceBelow, spaceAbove) / (PetWindowLayout.baseChatHeight - PetWindowLayout.basePetSize)
        let horizontalScale = max(spaceRight, spaceLeft) / PetWindowLayout.baseChatWidth
        let nextChatScale = min(requestedScale, verticalScale, horizontalScale)
        self.chatContentScale = max(0.1, nextChatScale)
        let panelWidth = max(petSize, PetWindowLayout.baseChatWidth * chatContentScale)
        let isLeft = spaceRight >= panelWidth || (spaceLeft < panelWidth && spaceRight >= spaceLeft)
        let requiredChatHeight = (PetWindowLayout.baseChatHeight - PetWindowLayout.basePetSize) * chatContentScale
        let isTop: Bool
        if spaceBelow >= requiredChatHeight {
            isTop = true
        } else if spaceAbove >= requiredChatHeight {
            isTop = false
        } else {
            isTop = spaceBelow >= spaceAbove
        }
        self.currentAnchor = PanelAnchor(isLeft: isLeft, isTop: isTop)
        PetState.shared.activeAnchor = self.currentAnchor
        layoutVersion &+= 1
    }

    public var screenContainingPet: NSScreen? {
        let petSize = PetWindowLayout.petSize
        let petRect = NSRect(x: petOrigin.x, y: petOrigin.y, width: petSize, height: petSize)
        var best: (screen: NSScreen, overlap: CGFloat)?
        for screen in NSScreen.screens {
            let intersection = screen.frame.intersection(petRect)
            guard !intersection.isNull else { continue }
            let area = intersection.width * intersection.height
            if area > (best?.overlap ?? 0) { best = (screen, area) }
        }
        return best?.screen ?? screenUnderMouse ?? NSScreen.main
    }

    public func screenForPetOrigin(_ origin: NSPoint) -> NSScreen? {
        screenContainingPoint(origin)
    }

    private var screenUnderMouse: NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouse) })
    }

    private func screenContainingPoint(_ point: NSPoint) -> NSScreen? {
        let size = CGSize(width: PetWindowLayout.basePetSize, height: PetWindowLayout.basePetSize)
        let rect = NSRect(origin: point, size: size)
        return NSScreen.screens.max { lhs, rhs in
            let l = lhs.frame.intersection(rect)
            let r = rhs.frame.intersection(rect)
            return (l.isNull ? 0 : l.width * l.height) < (r.isNull ? 0 : r.width * r.height)
        }.flatMap { screen in
            let intersection = screen.frame.intersection(rect)
            return intersection.isNull ? nil : screen
        }
    }

    private func updatePetLayoutScale(for screen: NSScreen) {
        let requested = CGFloat(max(0.5, min(2.0, DataManager.shared.savedData.petScale ?? 1.0)))
        let frame = screen.visibleFrame
        let fitWidth = frame.width / PetWindowLayout.basePetSize
        let fitHeight = frame.height / (PetWindowLayout.basePetSize + PetWindowLayout.baseClosedBubbleClearance)
        petLayoutScale = max(0.1, min(requested, fitWidth, fitHeight))
    }

    private func clampedPetOrigin(_ origin: NSPoint, to frame: NSRect) -> NSPoint {
        let maxX = max(frame.minX, frame.maxX - PetWindowLayout.petSize)
        let maxY = max(frame.minY, frame.maxY - PetWindowLayout.petSize)
        return NSPoint(x: max(frame.minX, min(maxX, origin.x)), y: max(frame.minY, min(maxY, origin.y)))
    }

    public func updateLayoutForScale() {
        guard let screen = screenContainingPet else { return }
        updatePetLayoutScale(for: screen)
        petOrigin = clampedPetOrigin(petOrigin, to: screen.visibleFrame)
        recomputeAnchor()
        if let win = window {
            win.setFrame(calculateWindowFrame(forPetOrigin: petOrigin, open: PetState.shared.isChatOpen), display: true, animate: false)
        }
    }

    /// Returns the local rectangle of the scaled pet stage within the window content.
    public func currentPetRectInWindow() -> NSRect {
        let petSize = PetWindowLayout.petSize
        guard let win = window else { return NSRect(x: 0, y: 0, width: petSize, height: petSize) }
        if !PetState.shared.isChatOpen {
            return NSRect(x: 0, y: 0, width: petSize, height: petSize)
        }
        let localX: CGFloat = currentAnchor.isLeft ? 0 : (win.frame.width - petSize)
        let localY: CGFloat = currentAnchor.isTop ? (win.frame.height - petSize) : 0
        return NSRect(x: localX, y: localY, width: petSize, height: petSize)
    }

    public func currentPetInteractiveRectInWindow() -> NSRect {
        let petRect = currentPetRectInWindow()
        let inset = max(0, (petRect.width - PetWindowLayout.viewportSize) / 2)
        return petRect.insetBy(dx: inset, dy: inset)
    }

    /// Side lengths (points) of the pet stage as the window actually lays it out.
    /// Anything that needs the pet's real size (e.g. WalkerManager) should read this instead of
    /// assuming a constant, so it follows whatever size the window uses.
    public var petStageSize: CGSize {
        return currentPetRectInWindow().size
    }

    /// Returns the local CGRect of the chat panel within the window's content view
    public func currentChatPanelRectInWindow() -> NSRect {
        guard let win = window, PetState.shared.isChatOpen else { return .zero }
        let width = PetWindowLayout.chatWidth
        let height = PetWindowLayout.chatContentHeight
        let localX = max(0, (win.frame.width - width) / 2)
        let localY: CGFloat = currentAnchor.isTop
            ? (win.frame.height - PetWindowLayout.petSize - height - 4 * chatContentScale)
            : (PetWindowLayout.petSize + 4 * chatContentScale)
        return NSRect(x: localX, y: localY, width: width, height: height)
    }

    public func updatePetOriginFromDrag(_ newPetOrigin: NSPoint) {
        let screen = screenContainingPoint(newPetOrigin) ?? screenContainingPet ?? NSScreen.main
        if let screen { updatePetLayoutScale(for: screen) }
        self.petOrigin = screen.map { clampedPetOrigin(newPetOrigin, to: $0.visibleFrame) } ?? newPetOrigin
        recomputeAnchor()
        guard let win = window else { return }

        if !PetState.shared.isChatOpen {
            win.setFrame(calculateWindowFrame(forPetOrigin: petOrigin, open: false), display: true, animate: false)
        } else {
            // Position full window such that the pet subrect stays at petOrigin
            let winFrame = calculateWindowFrame(forPetOrigin: petOrigin, open: true)
            win.setFrame(winFrame, display: true, animate: false)
        }
    }

    private func calculateWindowFrame(forPetOrigin origin: NSPoint, open: Bool) -> NSRect {
        let petSize = PetWindowLayout.petSize
        if !open {
            return NSRect(x: origin.x, y: origin.y, width: petSize, height: PetWindowLayout.closedWindowHeight)
        }

        let width = PetWindowLayout.chatWindowWidth
        let height = PetWindowLayout.chatWindowHeight

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
        guard let screen = screenContainingPet else { return }
        updatePetLayoutScale(for: screen)
        let oldOrigin = petOrigin
        petOrigin = clampedPetOrigin(petOrigin, to: screen.visibleFrame)
        recomputeAnchor()
        win.setFrame(calculateWindowFrame(forPetOrigin: petOrigin, open: PetState.shared.isChatOpen), display: true, animate: false)
        if oldOrigin != petOrigin { DataManager.shared.updatePosition(x: Double(petOrigin.x), y: Double(petOrigin.y)) }
    }

    public func setCompanionMode(clickThrough: Bool) {
        isCompanionClickThrough = clickThrough
        window?.ignoresMouseEvents = clickThrough
    }
}
