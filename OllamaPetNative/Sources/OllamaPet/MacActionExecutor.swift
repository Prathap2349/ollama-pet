import Foundation
import AppKit

// MARK: - Safe Mac Action Executor

@MainActor
public class MacActionExecutor {
    public static let shared = MacActionExecutor()

    public func processAction(_ action: MacAction, userText: String? = nil) async -> String {
        let settings = DataManager.shared.savedData.macControlSettings ?? MacControlSettings()
        let isSafeMode = PerformanceManager.shared.isSafeMode

        // 1. Validation & Allowlist Check
        let validation = ActionValidator.validate(action: action, settings: settings, isSafeMode: isSafeMode)

        switch validation {
        case .blocked(let reason):
            ActionHistoryManager.shared.record(
                actionType: action.type.rawValue,
                summary: action.summaryDescription,
                status: .blocked,
                detail: reason
            )
            if settings.showActionStatus {
                PetState.shared.showBubble("⚠️ \(reason)", duration: 4.0)
                SoundEffect.alert.play()
            }
            return "I couldn't perform that action: \(reason)"

        case .needsClarification(let prompt):
            ActionHistoryManager.shared.record(
                actionType: action.type.rawValue,
                summary: action.summaryDescription,
                status: .needsClarification,
                detail: prompt
            )
            PetState.shared.showBubble(prompt, duration: 4.0)
            return prompt

        case .requiresConfirmation(let verifiedAction):
            ActionHistoryManager.shared.record(
                actionType: verifiedAction.type.rawValue,
                summary: verifiedAction.summaryDescription,
                status: .needsConfirmation,
                detail: "Waiting for user confirmation..."
            )
            _ = await ActionConfirmationManager.shared.requestConfirmation(for: verifiedAction)
            return "Please confirm if you want me to perform this action."

        case .valid(let verifiedAction):
            return await executeConfirmedAction(verifiedAction)
        }
    }

    // MARK: - Execution Engine

    public func executeConfirmedAction(_ action: MacAction) async -> String {
        let settings = DataManager.shared.savedData.macControlSettings ?? MacControlSettings()

        UserDefaults.standard.set(true, forKey: "isExecutingMacAction")
        defer {
            UserDefaults.standard.removeObject(forKey: "isExecutingMacAction")
        }

        do {
            // Enforce 5.0s maximum timeout to guarantee main thread never hangs
            let result = try await withThrowingTimeout(seconds: 5.0) {
                try await self.performActionInternal(action, settings: settings)
            }

            ActionHistoryManager.shared.record(
                actionType: action.type.rawValue,
                summary: action.summaryDescription,
                status: .success,
                detail: result
            )

            if settings.showActionStatus {
                PetState.shared.showBubble("✓ \(result)", duration: 3.0)
                SoundEffect.receive.play()
            }

            return result
        } catch {
            let errorMsg = error.localizedDescription
            ActionHistoryManager.shared.record(
                actionType: action.type.rawValue,
                summary: action.summaryDescription,
                status: .failed,
                detail: errorMsg
            )

            if settings.showActionStatus {
                PetState.shared.showBubble("❌ Failed: \(errorMsg)", duration: 3.5)
                SoundEffect.alert.play()
            }

            return "Could not complete action: \(errorMsg)"
        }
    }

    // MARK: - Native Subsystem Operations

    private func performActionInternal(_ action: MacAction, settings: MacControlSettings) async throws -> String {
        switch action.type {

        case .openApp:
            guard let appName = action.app else {
                throw NSError(domain: "MacAction", code: 400, userInfo: [NSLocalizedDescriptionKey: "No application specified."])
            }
            return try await launchApplication(named: appName)

        case .openURL:
            guard let urlStr = action.url, let url = URL(string: urlStr) else {
                throw NSError(domain: "MacAction", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid website URL."])
            }
            if let browserName = action.browser, !browserName.isEmpty {
                guard let browserURL = findBrowserAppURL(browserName: browserName) else {
                    throw NSError(domain: "MacAction", code: 404, userInfo: [NSLocalizedDescriptionKey: "\(browserName) is not installed."])
                }
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                _ = try await NSWorkspace.shared.open([url], withApplicationAt: browserURL, configuration: config)
                return "Opened \(urlStr) in \(browserName)"
            } else {
                let success = NSWorkspace.shared.open(url)
                if success {
                    return "Opened \(urlStr)"
                } else {
                    throw NSError(domain: "MacAction", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unable to open URL in browser."])
                }
            }

        case .searchWeb:
            guard let query = action.query, !query.isEmpty else {
                throw NSError(domain: "MacAction", code: 400, userInfo: [NSLocalizedDescriptionKey: "Empty search query."])
            }
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let searchURL = URL(string: "https://www.google.com/search?q=\(encoded)")!
            if let browserName = action.browser, !browserName.isEmpty {
                guard let browserURL = findBrowserAppURL(browserName: browserName) else {
                    throw NSError(domain: "MacAction", code: 404, userInfo: [NSLocalizedDescriptionKey: "\(browserName) is not installed."])
                }
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                _ = try await NSWorkspace.shared.open([searchURL], withApplicationAt: browserURL, configuration: config)
                return "Searched web for '\(query)' in \(browserName)"
            } else {
                let success = NSWorkspace.shared.open(searchURL)
                if success {
                    return "Searched web for '\(query)'"
                } else {
                    throw NSError(domain: "MacAction", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unable to open browser search."])
                }
            }

        case .createReminder:
            guard let title = action.reminderTitle else {
                throw NSError(domain: "MacAction", code: 400, userInfo: [NSLocalizedDescriptionKey: "No reminder title specified."])
            }
            let delay = action.delaySeconds ?? 60
            DataManager.shared.addReminder(text: title, seconds: delay)
            let formattedDelay = formatSeconds(delay)
            return "Reminder set: '\(title)' in \(formattedDelay)"

        case .setTimer:
            let delay = action.delaySeconds ?? 60
            let formattedDelay = formatSeconds(delay)
            let timerId = UUID().uuidString
            NotificationScheduler.shared.scheduleTimer(
                timerId: timerId,
                title: "Timer Finished",
                body: "Your \(formattedDelay) timer has ended.",
                inSeconds: delay
            )
            return "Timer set for \(formattedDelay)"

        case .openReminders:
            if let url = URL(string: "x-apple-reminderkit:") {
                _ = NSWorkspace.shared.open(url)
            }
            _ = try? await launchApplication(named: "Reminders")
            return "Opened Reminders"

        case .openCalendar:
            if let url = URL(string: "ical:") {
                _ = NSWorkspace.shared.open(url)
            }
            _ = try? await launchApplication(named: "Calendar")
            return "Opened Calendar"

        case .openWhatsApp:
            return try await launchApplication(named: "WhatsApp")

        case .openMessages:
            return try await launchApplication(named: "Messages")

        case .openSystemSettings:
            if let url = URL(string: "x-apple.systempreferences:") {
                _ = NSWorkspace.shared.open(url)
            }
            return "Opened System Settings"

        case .showActionHistory:
            SettingsWindowController.shared.showTab(.actionHistory)
            return "Opened Action History"

        case .runApprovedShortcut:
            guard let name = action.shortcutName else {
                throw NSError(domain: "MacAction", code: 400, userInfo: [NSLocalizedDescriptionKey: "No shortcut specified."])
            }
            let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
            if let url = URL(string: "shortcuts://run-shortcut?name=\(encodedName)") {
                let success = NSWorkspace.shared.open(url)
                if success {
                    return "Running approved shortcut '\(name)'"
                }
            }
            throw NSError(domain: "MacAction", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not launch macOS Shortcuts."])

        case .sendMessage:
            let service = action.service ?? "Messages"
            let recipient = action.recipient ?? "Recipient"
            let text = action.messageText ?? ""

            // Open service with draft ready
            let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
            if service.lowercased() == "whatsapp" {
                if let url = URL(string: "whatsapp://send?text=\(encodedText)"), NSWorkspace.shared.open(url) {
                    return "WhatsApp opened with your message draft for \(recipient). Click Send to deliver."
                }
                _ = try? await launchApplication(named: "WhatsApp")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                return "WhatsApp opened. Message copied to clipboard for \(recipient)."
            } else {
                if let url = URL(string: "sms:&body=\(encodedText)"), NSWorkspace.shared.open(url) {
                    return "Messages opened with your draft for \(recipient). Click Send to deliver."
                }
                _ = try? await launchApplication(named: "Messages")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                return "Messages opened. Message copied to clipboard for \(recipient)."
            }

        case .querySystemVitals:
            let sys = SystemMonitor.shared
            if let q = action.query?.lowercased() {
                if q.contains("ram") || q.contains("memory") {
                    return "You are using \(String(format: "%.1f", sys.memoryUsedGB)) GB of \(String(format: "%.1f", sys.memoryTotalGB)) GB RAM (\(String(format: "%.0f%%", sys.memoryPercent))). CPU load is currently \(String(format: "%.1f%%", sys.cpuPercent))."
                }
                if q.contains("battery") || q.contains("power") {
                    let state = sys.isCharging ? "charging" : "on battery"
                    return "Battery is at \(sys.batteryPercent)% and \(state). Thermal state is \(sys.thermalStateDescription)."
                }
                if q.contains("app") {
                    let topNames = sys.topApplications.prefix(5).map { $0.name }.joined(separator: ", ")
                    return "Active app is \(sys.frontmostApp). Top running apps: \(topNames)."
                }
            }
            return "Mac: \(sys.macModel). RAM: \(String(format: "%.1f", sys.memoryUsedGB))/\(String(format: "%.1f", sys.memoryTotalGB)) GB. CPU: \(String(format: "%.1f%%", sys.cpuPercent)). Battery: \(sys.batteryPercent)%."

        case .controlFocus:
            let durationSecs = action.durationSeconds ?? (25 * 60)
            FocusGuardian.shared.applyPreset(seconds: durationSecs)
            FocusGuardian.shared.startFocusSession()
            let mins = durationSecs / 60
            return "Started a \(mins) minute focus session. Let's do this!"

        case .controlMonitoring:
            PresenceMonitor.shared.stop()
            return "Presence monitoring stopped."

        case .needsClarification:
            return action.clarificationPrompt ?? "Please clarify your request."

        case .unknown:
            throw NSError(domain: "MacAction", code: 403, userInfo: [NSLocalizedDescriptionKey: "Action is not permitted."])
        }
    }

    private func launchApplication(named appName: String) async throws -> String {
        let trimmed = appName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try direct launch via NSWorkspace
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId(for: trimmed)) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            _ = try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
            return "Launched \(trimmed)"
        }

        // Search standard app paths
        let standardPaths = [
            "/Applications/\(trimmed).app",
            "/System/Applications/\(trimmed).app",
            "/System/Applications/Utilities/\(trimmed).app",
            "/Applications/Google Chrome.app",
            "/Applications/Safari.app"
        ]

        for path in standardPaths {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                _ = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
                return "Launched \(trimmed)"
            }
        }

        let userAppUrl = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications/\(trimmed).app")
        if FileManager.default.fileExists(atPath: userAppUrl.path) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            _ = try await NSWorkspace.shared.openApplication(at: userAppUrl, configuration: config)
            return "Launched \(trimmed)"
        }

        throw NSError(
            domain: "MacAction",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: "Application '\(trimmed)' not found."]
        )
    }

    private func findBrowserAppURL(browserName: String) -> URL? {
        let bId = bundleId(for: browserName)
        if !bId.isEmpty, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bId) {
            return url
        }
        let candidates = [
            "/Applications/\(browserName).app",
            "/Applications/Google Chrome.app",
            "/Applications/Safari.app",
            "/Applications/Firefox.app",
            "/Applications/Microsoft Edge.app",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/\(browserName).app").path
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    private func bundleId(for appName: String) -> String {
        let lower = appName.lowercased()
        switch lower {
        case "safari": return "com.apple.Safari"
        case "chrome", "google chrome": return "com.google.Chrome"
        case "firefox": return "org.mozilla.firefox"
        case "edge", "microsoft edge": return "com.microsoft.edgemac"
        case "messages": return "com.apple.MobileSMS"
        case "whatsapp": return "net.whatsapp.WhatsApp"
        case "calendar": return "com.apple.iCal"
        case "reminders": return "com.apple.reminders"
        case "notes": return "com.apple.Notes"
        case "mail": return "com.apple.mail"
        case "music": return "com.apple.Music"
        case "settings", "system settings": return "com.apple.systempreferences"
        case "slack": return "com.tinyspeck.slackmacgap"
        case "vscode", "vs code", "visual studio code": return "com.microsoft.VSCode"
        default: return ""
        }
    }

    private func formatSeconds(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            return "\(seconds / 60)m"
        } else if seconds < 86400 {
            let h = seconds / 3600
            let m = (seconds % 3600) / 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        } else {
            return "\(seconds / 86400)d"
        }
    }

    private func withThrowingTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(
                    domain: "MacAction",
                    code: 408,
                    userInfo: [NSLocalizedDescriptionKey: "Action timed out after \(Int(seconds))s."]
                )
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
