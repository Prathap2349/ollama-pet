import Foundation

// MARK: - Safe Mac Action Types

public enum MacActionType: String, Codable, CaseIterable {
    case openApp = "OPEN_APP"
    case openURL = "OPEN_URL"
    case searchWeb = "SEARCH_WEB"
    case createReminder = "CREATE_REMINDER"
    case openReminders = "OPEN_REMINDERS"
    case openCalendar = "OPEN_CALENDAR"
    case openWhatsApp = "OPEN_WHATSAPP"
    case openMessages = "OPEN_MESSAGES"
    case openSystemSettings = "OPEN_SYSTEM_SETTINGS"
    case showActionHistory = "SHOW_ACTION_HISTORY"
    case runApprovedShortcut = "RUN_APPROVED_SHORTCUT"
    case sendMessage = "SEND_MESSAGE"
    case needsClarification = "NEEDS_CLARIFICATION"
    case unknown = "UNKNOWN"

    public var displayName: String {
        switch self {
        case .openApp: return "Open Application"
        case .openURL: return "Open Website"
        case .searchWeb: return "Search Web"
        case .createReminder: return "Create Reminder"
        case .openReminders: return "Open Reminders"
        case .openCalendar: return "Open Calendar"
        case .openWhatsApp: return "Open WhatsApp"
        case .openMessages: return "Open Messages"
        case .openSystemSettings: return "Open System Settings"
        case .showActionHistory: return "Show Action History"
        case .runApprovedShortcut: return "Run Approved Shortcut"
        case .sendMessage: return "Send Message"
        case .needsClarification: return "Needs Clarification"
        case .unknown: return "Unknown Action"
        }
    }
}

// MARK: - Risk Levels

public enum ActionRiskLevel: String, Codable {
    case safe
    case confirmationRequired

    public var displayName: String {
        switch self {
        case .safe: return "Safe"
        case .confirmationRequired: return "Confirmation Required"
        }
    }
}

// MARK: - Structured Mac Action Model

public struct MacAction: Identifiable, Codable, Equatable {
    public let id: UUID
    public let type: MacActionType
    public var app: String?
    public var url: String?
    public var query: String?
    public var reminderTitle: String?
    public var delaySeconds: Int?
    public var service: String?          // "WhatsApp" or "Messages"
    public var recipient: String?
    public var messageText: String?
    public var shortcutName: String?
    public var clarificationPrompt: String?
    public var requiresConfirmation: Bool
    public var riskLevel: ActionRiskLevel

    public init(
        id: UUID = UUID(),
        type: MacActionType,
        app: String? = nil,
        url: String? = nil,
        query: String? = nil,
        reminderTitle: String? = nil,
        delaySeconds: Int? = nil,
        service: String? = nil,
        recipient: String? = nil,
        messageText: String? = nil,
        shortcutName: String? = nil,
        clarificationPrompt: String? = nil,
        requiresConfirmation: Bool? = nil,
        riskLevel: ActionRiskLevel? = nil
    ) {
        self.id = id
        self.type = type
        self.app = app
        self.url = url
        self.query = query
        self.reminderTitle = reminderTitle
        self.delaySeconds = delaySeconds
        self.service = service
        self.recipient = recipient
        self.messageText = messageText
        self.shortcutName = shortcutName
        self.clarificationPrompt = clarificationPrompt

        // Determine default risk level if not specified
        let resolvedRisk: ActionRiskLevel
        if let r = riskLevel {
            resolvedRisk = r
        } else {
            switch type {
            case .sendMessage, .runApprovedShortcut:
                resolvedRisk = .confirmationRequired
            default:
                resolvedRisk = .safe
            }
        }
        self.riskLevel = resolvedRisk
        self.requiresConfirmation = requiresConfirmation ?? (resolvedRisk == .confirmationRequired)
    }

    public var summaryDescription: String {
        switch type {
        case .openApp:
            return "Open application '\(app ?? "App")'"
        case .openURL:
            return "Open website '\(url ?? "URL")'"
        case .searchWeb:
            return "Search web for '\(query ?? "")'"
        case .createReminder:
            let delayStr = formatDelay(delaySeconds ?? 60)
            return "Reminder: '\(reminderTitle ?? "")' in \(delayStr)"
        case .openReminders:
            return "Open Reminders app"
        case .openCalendar:
            return "Open Calendar app"
        case .openWhatsApp:
            return "Open WhatsApp"
        case .openMessages:
            return "Open Messages"
        case .openSystemSettings:
            return "Open System Settings"
        case .showActionHistory:
            return "Show Action History"
        case .runApprovedShortcut:
            return "Run shortcut '\(shortcutName ?? "")'"
        case .sendMessage:
            return "Send \(service ?? "Message") to \(recipient ?? "Someone"): \"\(messageText ?? "")\""
        case .needsClarification:
            return clarificationPrompt ?? "Needs clarification"
        case .unknown:
            return "Unknown request"
        }
    }

    private func formatDelay(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            return "\(seconds / 60)m"
        } else if seconds < 86400 {
            let h = seconds / 3600
            let m = (seconds % 3600) / 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        } else {
            let d = seconds / 86400
            return "\(d)d"
        }
    }
}
