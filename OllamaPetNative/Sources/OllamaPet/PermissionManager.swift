import Foundation
import AppKit
import AVFoundation
import Speech
import UserNotifications

// MARK: - Permission Status

public enum SystemPermissionStatus: String {
    case granted = "Allowed"
    case denied = "Not Allowed"
    case notDetermined = "Not Requested"

    public var badgeColor: NSColor {
        switch self {
        case .granted: return .systemGreen
        case .denied: return .systemRed
        case .notDetermined: return .systemGray
        }
    }
}

// MARK: - Permission Manager

@MainActor
public class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()

    @Published public var microphoneStatus: SystemPermissionStatus = .notDetermined
    @Published public var speechStatus: SystemPermissionStatus = .notDetermined
    @Published public var cameraStatus: SystemPermissionStatus = .notDetermined
    @Published public var notificationsStatus: SystemPermissionStatus = .notDetermined

    public init() {
        checkAllPermissions()
    }

    public func checkAllPermissions() {
        // 1. Microphone
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphoneStatus = .granted
        case .denied, .restricted:
            microphoneStatus = .denied
        case .notDetermined:
            microphoneStatus = .notDetermined
        @unknown default:
            microphoneStatus = .denied
        }

        // 2. Speech Recognition
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            speechStatus = .granted
        case .denied, .restricted:
            speechStatus = .denied
        case .notDetermined:
            speechStatus = .notDetermined
        @unknown default:
            speechStatus = .denied
        }

        // 3. Camera
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraStatus = .granted
        case .denied, .restricted:
            cameraStatus = .denied
        case .notDetermined:
            cameraStatus = .notDetermined
        @unknown default:
            cameraStatus = .denied
        }

        // 4. Notifications
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    self?.notificationsStatus = .granted
                case .denied:
                    self?.notificationsStatus = .denied
                case .notDetermined:
                    self?.notificationsStatus = .notDetermined
                @unknown default:
                    self?.notificationsStatus = .denied
                }
            }
        }
    }

    public func openSystemSettings(pane: String? = nil) {
        if let pane = pane,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)"),
           NSWorkspace.shared.open(url) {
            return
        }

        // Fallback to opening System Settings main window
        if let url = URL(string: "x-apple.systempreferences:") {
            NSWorkspace.shared.open(url)
        }
    }
}
