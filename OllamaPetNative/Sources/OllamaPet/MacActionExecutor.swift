import Foundation
import AppKit

// MARK: - Action Execution Result

public struct ActionExecutionResult {
    public let message: String
    public let status: ActionExecutionStatus

    public init(_ message: String, status: ActionExecutionStatus = .success) {
        self.message = message
        self.status = status
    }
}

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

    private func timeout(for actionType: MacActionType) -> TimeInterval {
        switch actionType {
        case .openApp: return 5.0
        case .openURL, .searchWeb: return 8.0
        case .sendMessage: return 10.0
        case .createReminder, .setTimer: return 5.0
        case .querySystemVitals: return 3.0
        case .openReminders, .openCalendar, .openWhatsApp, .openMessages, .openSystemSettings: return 5.0
        default: return 5.0
        }
    }

    public func executeConfirmedAction(_ action: MacAction) async -> String {
        let settings = DataManager.shared.savedData.macControlSettings ?? MacControlSettings()

        UserDefaults.standard.set(true, forKey: "isExecutingMacAction")
        defer {
            UserDefaults.standard.removeObject(forKey: "isExecutingMacAction")
        }

        let timeoutSecs = timeout(for: action.type)

        do {
            let result = try await withThrowingTimeout(seconds: timeoutSecs) {
                try await self.performActionInternal(action, settings: settings)
            }

            ActionHistoryManager.shared.record(
                actionType: action.type.rawValue,
                summary: action.summaryDescription,
                status: result.status,
                detail: result.message
            )

            if settings.showActionStatus {
                let icon = result.status == .partial ? "⚠️" : "✓"
                PetState.shared.showBubble("\(icon) \(result.message)", duration: 3.5)
                if result.status == .partial {
                    SoundEffect.alert.play()
                } else {
                    SoundEffect.receive.play()
                }
            }

            return result.message
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

    private func performActionInternal(_ action: MacAction, settings: MacControlSettings) async throws -> ActionExecutionResult {
        switch action.type {

        case .openApp:
            guard let appName = action.app else {
                throw NSError(domain: "MacAction", code: 400, userInfo: [NSLocalizedDescriptionKey: "No application specified."])
            }
            let launchMsg = try await launchApplication(named: appName)
            return ActionExecutionResult(launchMsg, status: .success)

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

                // Tab / Process Verification
                try? await Task.sleep(nanoseconds: 500_000_000)
                let bId = bundleId(for: browserName)
                let isRunning = !bId.isEmpty && !NSRunningApplication.runningApplications(withBundleIdentifier: bId).isEmpty
                if isRunning {
                    return ActionExecutionResult("Opened \(urlStr) in \(browserName)", status: .success)
                } else {
                    return ActionExecutionResult("Dispatched \(urlStr) to \(browserName) (window opening)", status: .partial)
                }
            } else {
                let success = NSWorkspace.shared.open(url)
                if success {
                    return ActionExecutionResult("Opened \(urlStr)", status: .success)
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

                try? await Task.sleep(nanoseconds: 500_000_000)
                let bId = bundleId(for: browserName)
                let isRunning = !bId.isEmpty && !NSRunningApplication.runningApplications(withBundleIdentifier: bId).isEmpty
                return ActionExecutionResult(
                    isRunning ? "Searched web for '\(query)' in \(browserName)" : "Sent search for '\(query)' to \(browserName)",
                    status: isRunning ? .success : .partial
                )
            } else {
                let success = NSWorkspace.shared.open(searchURL)
                if success {
                    return ActionExecutionResult("Searched web for '\(query)'", status: .success)
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
            return ActionExecutionResult("Reminder set: '\(title)' in \(formattedDelay)", status: .success)

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
            return ActionExecutionResult("Timer set for \(formattedDelay)", status: .success)

        case .openReminders:
            if let url = URL(string: "x-apple-reminderkit:") {
                _ = NSWorkspace.shared.open(url)
            }
            _ = try? await launchApplication(named: "Reminders")
            return ActionExecutionResult("Opened Reminders", status: .success)

        case .openCalendar:
            if let url = URL(string: "ical:") {
                _ = NSWorkspace.shared.open(url)
            }
            _ = try? await launchApplication(named: "Calendar")
            return ActionExecutionResult("Opened Calendar", status: .success)

        case .openWhatsApp:
            let res = try await launchApplication(named: "WhatsApp")
            return ActionExecutionResult(res, status: .success)

        case .openMessages:
            let res = try await launchApplication(named: "Messages")
            return ActionExecutionResult(res, status: .success)

        case .openSystemSettings:
            if let url = URL(string: "x-apple.systempreferences:") {
                _ = NSWorkspace.shared.open(url)
            }
            return ActionExecutionResult("Opened System Settings", status: .success)

        case .showActionHistory:
            SettingsWindowController.shared.showTab(.actionHistory)
            return ActionExecutionResult("Opened Action History", status: .success)

        case .runApprovedShortcut:
            guard let name = action.shortcutName else {
                throw NSError(domain: "MacAction", code: 400, userInfo: [NSLocalizedDescriptionKey: "No shortcut specified."])
            }
            let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
            if let url = URL(string: "shortcuts://run-shortcut?name=\(encodedName)") {
                let success = NSWorkspace.shared.open(url)
                if success {
                    return ActionExecutionResult("Running approved shortcut '\(name)'", status: .success)
                }
            }
            throw NSError(domain: "MacAction", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not launch macOS Shortcuts."])

        case .sendMessage:
            let service = action.service ?? "Messages"
            let recipient = action.recipient ?? "Recipient"
            let text = action.messageText ?? ""

            // Open service with draft ready. We never claim "Message sent" without external delivery confirmation!
            let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
            if service.lowercased() == "whatsapp" {
                if let url = URL(string: "whatsapp://send?text=\(encodedText)"), NSWorkspace.shared.open(url) {
                    return ActionExecutionResult(
                        "WhatsApp opened with message draft for \(recipient). Please press Send in WhatsApp to deliver.",
                        status: .partial
                    )
                }
                _ = try? await launchApplication(named: "WhatsApp")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                return ActionExecutionResult(
                    "WhatsApp opened. Message draft copied to clipboard for \(recipient). Please paste and press Send.",
                    status: .partial
                )
            } else {
                if let url = URL(string: "sms:&body=\(encodedText)"), NSWorkspace.shared.open(url) {
                    return ActionExecutionResult(
                        "Messages opened with draft for \(recipient). Please press Send in Messages to deliver.",
                        status: .partial
                    )
                }
                _ = try? await launchApplication(named: "Messages")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                return ActionExecutionResult(
                    "Messages opened. Message draft copied to clipboard for \(recipient). Please paste and press Send.",
                    status: .partial
                )
            }

        case .querySystemVitals:
            let sys = SystemMonitor.shared
            if let q = action.query?.lowercased() {
                if q.contains("ram") || q.contains("memory") {
                    return ActionExecutionResult("RAM: \(String(format: "%.1f", sys.memoryUsedGB))/\(String(format: "%.1f", sys.memoryTotalGB)) GB (\(String(format: "%.0f%%", sys.memoryPercent))). CPU load: \(String(format: "%.1f%%", sys.cpuPercent)).", status: .success)
                }
                if q.contains("battery") || q.contains("power") {
                    let state = sys.isCharging ? "charging" : "on battery"
                    return ActionExecutionResult("Battery is at \(sys.batteryPercent)% (\(state)). Thermal state: \(sys.thermalStateDescription).", status: .success)
                }
                if q.contains("app") {
                    let topNames = sys.topApplications.prefix(5).map { $0.name }.joined(separator: ", ")
                    return ActionExecutionResult("Active app: \(sys.frontmostApp). Top running apps: \(topNames).", status: .success)
                }
            }
            return ActionExecutionResult("Mac: \(sys.macModel). RAM: \(String(format: "%.1f", sys.memoryUsedGB))/\(String(format: "%.1f", sys.memoryTotalGB)) GB. CPU: \(String(format: "%.1f%%", sys.cpuPercent)). Battery: \(sys.batteryPercent)%.", status: .success)

        case .controlFocus:
            let durationSecs = action.durationSeconds ?? (25 * 60)
            FocusGuardian.shared.applyPreset(seconds: durationSecs)
            FocusGuardian.shared.startFocusSession()
            let mins = durationSecs / 60
            return ActionExecutionResult("Started a \(mins) minute focus session.", status: .success)

        case .controlMonitoring:
            PresenceMonitor.shared.stop()
            return ActionExecutionResult("Presence monitoring stopped.", status: .success)

        case .needsClarification:
            return ActionExecutionResult(action.clarificationPrompt ?? "Please clarify your request.", status: .needsClarification)

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
            "/Applications/Brave Browser.app",
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
        case "brave", "brave browser": return "com.brave.Browser"
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
