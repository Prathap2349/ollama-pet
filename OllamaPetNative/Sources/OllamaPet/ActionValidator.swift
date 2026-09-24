import Foundation
import AppKit

// MARK: - Validation Result

public enum ActionValidationResult: Equatable {
    case valid(MacAction)
    case requiresConfirmation(MacAction)
    case blocked(String)
    case needsClarification(String)
}

// MARK: - Safe Action Validator

public struct ActionValidator {

    // Strictly blocked applications to prevent arbitrary command execution or privilege escalation
    private static let dangerousAppKeywords: Set<String> = [
        "terminal", "iterm", "iterm2", "alacritty", "kitty", "hyper",
        "sh", "bash", "zsh", "csh", "fish", "sudo",
        "activity monitor", "disk utility", "installer"
    ]

    public static func validate(
        action: MacAction,
        settings: MacControlSettings,
        isSafeMode: Bool
    ) -> ActionValidationResult {

        // 1. Global Mac Control Toggle
        guard settings.macControlEnabled else {
            return .blocked("Mac Control is currently turned OFF. Enable it in Settings.")
        }

        // 2. Safe Mode Check
        guard !isSafeMode else {
            return .blocked("Performance Safe Mode is active. System control actions are disabled.")
        }

        // 3. Allowlist & Feature-Specific Checks
        switch action.type {

        case .openApp:
            guard settings.openAppsEnabled else {
                return .blocked("Opening applications is disabled in Settings.")
            }
            guard let appName = action.app?.trimmingCharacters(in: .whitespacesAndNewlines), !appName.isEmpty else {
                return .needsClarification("Which application would you like me to open?")
            }

            let lower = appName.lowercased()
            // Never allow opening terminal/shell wrappers
            for danger in dangerousAppKeywords {
                if lower == danger || lower.contains("\(danger).app") {
                    return .blocked("Opening terminal or system utility '\(appName)' is prohibited for safety.")
                }
            }

            var verifiedAction = action
            verifiedAction.app = appName
            return .valid(verifiedAction)

        case .openURL:
            guard settings.openURLsEnabled else {
                return .blocked("Opening websites is disabled in Settings.")
            }
            guard let rawURL = action.url?.trimmingCharacters(in: .whitespacesAndNewlines), !rawURL.isEmpty else {
                return .needsClarification("What website URL would you like me to open?")
            }

            // Normalise URL if user gave e.g. "youtube.com" or "github.com"
            let formattedURLString: String
            if !rawURL.lowercased().hasPrefix("http://") && !rawURL.lowercased().hasPrefix("https://") {
                formattedURLString = "https://\(rawURL)"
            } else {
                formattedURLString = rawURL
            }

            guard let url = URL(string: formattedURLString), let scheme = url.scheme?.lowercased() else {
                return .blocked("Invalid web address.")
            }

            // Strict scheme check: only https and http are permitted
            guard scheme == "https" || scheme == "http" else {
                return .blocked("Only secure web URLs (https/http) are allowed.")
            }

            var verifiedAction = action
            verifiedAction.url = formattedURLString
            return .valid(verifiedAction)

        case .searchWeb:
            guard settings.webSearchEnabled else {
                return .blocked("Web search is disabled in Settings.")
            }
            guard let query = action.query?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty else {
                return .needsClarification("What would you like me to search for?")
            }

            var verifiedAction = action
            verifiedAction.query = query
            return .valid(verifiedAction)

        case .createReminder:
            guard settings.remindersEnabled else {
                return .blocked("Reminders are disabled in Settings.")
            }
            guard let title = action.reminderTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
                return .needsClarification("What should the reminder note say?")
            }

            let delay = action.delaySeconds ?? 60
            guard delay > 0 else {
                return .blocked("Reminder duration must be greater than zero.")
            }

            // Limit to at most 365 days
            guard delay <= (365 * 86400) else {
                return .blocked("Reminder time exceeds 1 year limit.")
            }

            var verifiedAction = action
            verifiedAction.reminderTitle = title
            verifiedAction.delaySeconds = delay
            return .valid(verifiedAction)

        case .openReminders:
            guard settings.remindersEnabled else {
                return .blocked("Reminders integration is disabled in Settings.")
            }
            return .valid(action)

        case .openCalendar:
            guard settings.calendarEnabled else {
                return .blocked("Calendar integration is disabled in Settings.")
            }
            return .valid(action)

        case .openWhatsApp:
            guard settings.whatsappEnabled else {
                return .blocked("WhatsApp integration is disabled in Settings.")
            }
            return .valid(action)

        case .openMessages:
            guard settings.messagesEnabled else {
                return .blocked("Messages integration is disabled in Settings.")
            }
            return .valid(action)

        case .openSystemSettings:
            return .valid(action)

        case .showActionHistory:
            return .valid(action)

        case .runApprovedShortcut:
            guard settings.shortcutsEnabled else {
                return .blocked("Shortcuts execution is disabled in Settings.")
            }
            guard let name = action.shortcutName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
                return .needsClarification("Which shortcut would you like to run?")
            }

            // Check against approved shortcuts list
            let isApproved = settings.approvedShortcuts.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
            guard isApproved else {
                return .blocked("Shortcut '\(name)' is not in your approved shortcuts list.")
            }

            var verifiedAction = action
            verifiedAction.shortcutName = name

            // If confirmation is required for external actions
            if settings.alwaysConfirmExternalActions || action.requiresConfirmation {
                verifiedAction.requiresConfirmation = true
                return .requiresConfirmation(verifiedAction)
            } else {
                return .valid(verifiedAction)
            }

        case .sendMessage:
            guard settings.messagesEnabled || settings.whatsappEnabled else {
                return .blocked("Messaging integration is disabled in Settings.")
            }
            guard let recipient = action.recipient?.trimmingCharacters(in: .whitespacesAndNewlines), !recipient.isEmpty else {
                return .needsClarification("Who would you like to send the message to?")
            }
            guard let text = action.messageText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                return .needsClarification("What message would you like to send?")
            }

            var verifiedAction = action
            verifiedAction.recipient = recipient
            verifiedAction.messageText = text
            // Message sending ALWAYS requires user confirmation!
            verifiedAction.requiresConfirmation = true
            verifiedAction.riskLevel = .confirmationRequired
            return .requiresConfirmation(verifiedAction)

        case .needsClarification:
            return .needsClarification(action.clarificationPrompt ?? "Could you clarify what you'd like me to do?")

        case .unknown:
            return .blocked("I can't perform that action safely.")
        }
    }
}
