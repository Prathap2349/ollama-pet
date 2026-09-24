import Foundation
import AppKit

public enum ScreenActivityCategory: String {
    case coding = "Coding / IDE"
    case terminal = "Terminal"
    case document = "Document"
    case browser = "Browsing"
    case media = "Media / Video"
    case other = "General"
}

@MainActor
public class ScreenGuardian: ObservableObject {
    public static let shared = ScreenGuardian()

    @Published public var isMonitoring: Bool = false
    @Published public var permissionGranted: Bool = false
    @Published public var currentCategory: ScreenActivityCategory = .other
    @Published public var activeAppName: String = ""

    private var pollTimer: Timer?

    public init() {
        checkPermission()
    }

    public func checkPermission() {
        // CGPreflightScreenCaptureAccess checks without prompt
        if #available(macOS 11.0, *) {
            self.permissionGranted = CGPreflightScreenCaptureAccess()
        } else {
            self.permissionGranted = true
        }
    }

    public func requestPermission() {
        if #available(macOS 11.0, *) {
            self.permissionGranted = CGRequestScreenCaptureAccess()
        }
    }

    public func startMonitoring() {
        guard !isMonitoring else { return }
        checkPermission()

        if !permissionGranted {
            requestPermission()
            PetState.shared.showBubble("🖥 Screen Recording permission needed", duration: 2.5)
            return
        }

        isMonitoring = true
        updateActiveContext()

        // Lightweight periodic check every 5 seconds (zero screenshots, pure window title/app metadata)
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateActiveContext()
            }
        }
    }

    public func stopMonitoring() {
        isMonitoring = false
        pollTimer?.invalidate()
        pollTimer = nil
        currentCategory = .other
        activeAppName = ""
    }

    private func updateActiveContext() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let appName = frontApp.localizedName else { return }

        self.activeAppName = appName
        let lower = appName.lowercased()

        if lower.contains("xcode") || lower.contains("code") || lower.contains("studio") || lower.contains("sublime") || lower.contains("atom") || lower.contains("fleet") || lower.contains("cursor") {
            self.currentCategory = .coding
        } else if lower.contains("terminal") || lower.contains("iterm") || lower.contains("warp") || lower.contains("alacritty") || lower.contains("kitty") {
            self.currentCategory = .terminal
        } else if lower.contains("safari") || lower.contains("chrome") || lower.contains("brave") || lower.contains("firefox") || lower.contains("edge") || lower.contains("arc") {
            self.currentCategory = .browser
        } else if lower.contains("pages") || lower.contains("word") || lower.contains("notes") || lower.contains("notion") || lower.contains("obsidian") || lower.contains("preview") {
            self.currentCategory = .document
        } else if lower.contains("spotify") || lower.contains("music") || lower.contains("vlc") || lower.contains("quicktime") || lower.contains("tv") {
            self.currentCategory = .media
        } else {
            self.currentCategory = .other
        }
    }

    public var isWorkFocused: Bool {
        return currentCategory == .coding || currentCategory == .terminal || currentCategory == .document
    }

    deinit {
        pollTimer?.invalidate()
    }
}
