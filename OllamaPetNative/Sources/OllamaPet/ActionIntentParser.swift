import Foundation

// MARK: - Action Intent Parser

@MainActor
public class ActionIntentParser {
    public static let shared = ActionIntentParser()

    // Explicit danger triggers that are immediately caught
    private let blockedPhrases: [String] = [
        "rm -", "rmdir", "delete file", "delete folder", "format disk",
        "sudo ", "chmod ", "chown ", "kill ", "killall",
        "terminal command", "run in terminal", "bash script", "shell command",
        "change password", "turn off firewall", "disable sip"
    ]

    public func parseIntent(from userText: String) async -> MacAction? {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()

        // 1. Immediate Safety Intercept for Dangerous Requests
        for blocked in blockedPhrases {
            if lower.contains(blocked) {
                return MacAction(type: .unknown)
            }
        }

        // 2. Fast Deterministic Natural Language Parser
        if let directAction = parseFastPattern(text: trimmed, lower: lower) {
            return directAction
        }

        // 3. Fallback to Local Ollama Structured Intent Parser if keywords suggest an action
        if looksLikeSystemCommand(lower: lower) && OllamaClient.shared.isOnline {
            if let ollamaAction = await parseWithOllama(text: trimmed) {
                return ollamaAction
            }
        }

        return nil
    }

    // MARK: - Fast Pattern Matching Engine

    private func parseFastPattern(text: String, lower: String) -> MacAction? {
        // A. Reminders
        if lower.starts(with: "remind me") || lower.starts(with: "take a reminder") || lower.starts(with: "set a reminder") {
            return parseReminder(from: text, lower: lower)
        }

        // B. Search Web
        if lower.starts(with: "search youtube for ") {
            let q = String(text.dropFirst("search youtube for ".count)).trimmingCharacters(in: .whitespaces)
            return MacAction(type: .openURL, url: "https://www.youtube.com/results?search_query=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)")
        }
        if lower.starts(with: "search the web for ") || lower.starts(with: "search web for ") {
            let prefix = lower.starts(with: "search the web for ") ? "search the web for " : "search web for "
            let q = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            return MacAction(type: .searchWeb, query: q)
        }
        if lower.starts(with: "google ") {
            let q = String(text.dropFirst("google ".count)).trimmingCharacters(in: .whitespaces)
            return MacAction(type: .searchWeb, query: q)
        }

        // C. Direct System Apps / Services
        if lower == "open calendar" || lower == "launch calendar" {
            return MacAction(type: .openCalendar)
        }
        if lower == "open reminders" || lower == "launch reminders" {
            return MacAction(type: .openReminders)
        }
        if lower == "open whatsapp" || lower == "launch whatsapp" {
            return MacAction(type: .openWhatsApp)
        }
        if lower == "open messages" || lower == "launch messages" || lower == "open imessage" {
            return MacAction(type: .openMessages)
        }
        if lower == "open system settings" || lower == "open settings" || lower == "launch system settings" {
            return MacAction(type: .openSystemSettings)
        }
        if lower == "show action history" || lower == "open action history" {
            return MacAction(type: .showActionHistory)
        }

        // D. Approved Shortcuts
        if lower.starts(with: "run shortcut ") || lower.starts(with: "run my shortcut ") || lower.starts(with: "run approved shortcut ") {
            let prefixes = ["run approved shortcut ", "run my shortcut ", "run shortcut "]
            for p in prefixes {
                if lower.starts(with: p) {
                    let name = String(text.dropFirst(p.count)).trimmingCharacters(in: .whitespaces)
                    return MacAction(type: .runApprovedShortcut, shortcutName: name, requiresConfirmation: true)
                }
            }
        }

        // E. Send Message (WhatsApp / Messages)
        if lower.starts(with: "send ") && (lower.contains("message") || lower.contains("whatsapp")) {
            return parseSendMessage(from: text, lower: lower)
        }

        // F. Open URLs
        if lower.starts(with: "open http://") || lower.starts(with: "open https://") {
            let urlStr = String(text.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            return MacAction(type: .openURL, url: urlStr)
        }
        if lower == "open youtube" || lower == "launch youtube" {
            return MacAction(type: .openURL, url: "https://www.youtube.com")
        }
        if lower == "open github" || lower == "launch github" {
            return MacAction(type: .openURL, url: "https://www.github.com")
        }
        if lower == "open google" || lower == "launch google" {
            return MacAction(type: .openURL, url: "https://www.google.com")
        }

        // G. General Open App
        if lower.starts(with: "open ") || lower.starts(with: "launch ") || lower.starts(with: "start ") {
            let appName: String
            if lower.starts(with: "open ") {
                appName = String(text.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            } else if lower.starts(with: "launch ") {
                appName = String(text.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            } else {
                appName = String(text.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            }

            // If appName ends with a website domain, treat as URL
            if appName.contains(".com") || appName.contains(".org") || appName.contains(".net") || appName.contains(".io") {
                return MacAction(type: .openURL, url: "https://\(appName)")
            }

            if !appName.isEmpty {
                return MacAction(type: .openApp, app: appName)
            }
        }

        return nil
    }

    // MARK: - Reminder Extraction

    private func parseReminder(from text: String, lower: String) -> MacAction {
        // e.g. "Remind me in 30 minutes to drink water"
        // e.g. "Remind me in 10 seconds to check download"
        // e.g. "Remind me tomorrow at 8 AM to study"

        var delaySeconds = 60 // default 1 minute
        var reminderTitle = "Reminder"

        if let inRange = lower.range(of: " in ") {
            let afterIn = String(text[inRange.upperBound...])
            let parts = afterIn.components(separatedBy: " to ")

            if parts.count >= 2 {
                let timePart = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                reminderTitle = parts.dropFirst().joined(separator: " to ").trimmingCharacters(in: .whitespaces)
                delaySeconds = parseTimeInterval(timePart)
            } else {
                // Check if user just specified a time or title
                let tokens = afterIn.split(separator: " ")
                if tokens.count >= 2, let num = Int(tokens[0]) {
                    let unit = tokens[1].lowercased()
                    if unit.contains("sec") { delaySeconds = num }
                    else if unit.contains("min") { delaySeconds = num * 60 }
                    else if unit.contains("hour") || unit.contains("hr") { delaySeconds = num * 3600 }
                    else if unit.contains("day") { delaySeconds = num * 86400 }

                    if tokens.count > 2 {
                        reminderTitle = tokens.dropFirst(2).joined(separator: " ")
                    }
                } else {
                    reminderTitle = afterIn
                }
            }
        } else if let toRange = lower.range(of: " to ") {
            reminderTitle = String(text[toRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else {
            reminderTitle = text
        }

        if reminderTitle.isEmpty {
            return MacAction(type: .needsClarification, clarificationPrompt: "What should I remind you about?")
        }

        return MacAction(type: .createReminder, reminderTitle: reminderTitle, delaySeconds: delaySeconds)
    }

    private func parseTimeInterval(_ str: String) -> Int {
        let comps = str.split(separator: " ")
        guard let first = comps.first, let val = Int(first) else { return 60 }

        let unit = comps.dropFirst().joined(separator: " ").lowercased()
        if unit.contains("sec") {
            return val
        } else if unit.contains("min") {
            return val * 60
        } else if unit.contains("hour") || unit.contains("hr") {
            return val * 3600
        } else if unit.contains("day") {
            return val * 86400
        }
        return val * 60
    }

    // MARK: - Message Extraction

    private func parseSendMessage(from text: String, lower: String) -> MacAction {
        // e.g. "Send John a WhatsApp message saying I'll be late"
        // e.g. "Send Mary a message saying hello"
        let service = lower.contains("whatsapp") ? "WhatsApp" : "Messages"

        var recipient = "Recipient"
        var message = text

        // Extract recipient
        // "send [name] a message..." or "send a message to [name] saying..."
        if let sayingRange = lower.range(of: " saying ") {
            message = String(text[sayingRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            let beforeSaying = String(text[..<sayingRange.lowerBound])

            if let sendRange = beforeSaying.lowercased().range(of: "send ") {
                let afterSend = String(beforeSaying[sendRange.upperBound...])
                let tokens = afterSend.components(separatedBy: " ")
                if let firstToken = tokens.first, !firstToken.isEmpty {
                    recipient = firstToken
                }
            }
        }

        // Clean quotes from message
        message = message.trimmingCharacters(in: CharacterSet(charactersIn: "\"\'"))

        return MacAction(
            type: .sendMessage,
            service: service,
            recipient: recipient,
            messageText: message,
            requiresConfirmation: true,
            riskLevel: .confirmationRequired
        )
    }

    // MARK: - Helper to detect if input might be an action command

    private func looksLikeSystemCommand(lower: String) -> Bool {
        let actionKeywords = [
            "open ", "launch ", "start ", "search ", "remind ", "calendar",
            "whatsapp", "message", "shortcut", "settings", "timer"
        ]
        for kw in actionKeywords {
            if lower.contains(kw) { return true }
        }
        return false
    }

    // MARK: - Ollama Structured Intent Parser

    private func parseWithOllama(text: String) async -> MacAction? {
        let prompt = """
        User input: "\(text)"

        You are a Safe Mac Action Intent Parser. Convert the user input into a single JSON object.
        Supported actions:
        - "OPEN_APP": {"action": "OPEN_APP", "app": "AppName"}
        - "OPEN_URL": {"action": "OPEN_URL", "url": "https://..."}
        - "SEARCH_WEB": {"action": "SEARCH_WEB", "query": "..."}
        - "CREATE_REMINDER": {"action": "CREATE_REMINDER", "reminderTitle": "...", "delaySeconds": 60}
        - "OPEN_REMINDERS": {"action": "OPEN_REMINDERS"}
        - "OPEN_CALENDAR": {"action": "OPEN_CALENDAR"}
        - "OPEN_WHATSAPP": {"action": "OPEN_WHATSAPP"}
        - "OPEN_MESSAGES": {"action": "OPEN_MESSAGES"}
        - "OPEN_SYSTEM_SETTINGS": {"action": "OPEN_SYSTEM_SETTINGS"}
        - "RUN_APPROVED_SHORTCUT": {"action": "RUN_APPROVED_SHORTCUT", "shortcutName": "..."}
        - "SEND_MESSAGE": {"action": "SEND_MESSAGE", "service": "WhatsApp", "recipient": "...", "messageText": "..."}
        - "NEEDS_CLARIFICATION": {"action": "NEEDS_CLARIFICATION", "clarificationPrompt": "..."}
        - "UNKNOWN": {"action": "UNKNOWN"}

        RULES:
        1. Return ONLY valid JSON.
        2. Never generate shell commands, terminal execution, or scripts.
        3. If not an action command, return {"action": "UNKNOWN"}.
        """

        do {
            let reply = try await OllamaClient.shared.sendChat(
                systemPrompt: "You are an action parser that outputs strictly raw JSON. Output no conversational text, no markdown codeblocks.",
                messages: [ChatMessage(role: "user", content: prompt)]
            )

            // Extract JSON substring if wrapped in markdown
            let cleaned = extractJSON(from: reply)
            guard let data = cleaned.data(using: .utf8) else { return nil }

            struct OllamaParsedAction: Decodable {
                let action: String?
                let app: String?
                let url: String?
                let query: String?
                let reminderTitle: String?
                let delaySeconds: Int?
                let service: String?
                let recipient: String?
                let messageText: String?
                let shortcutName: String?
                let clarificationPrompt: String?
            }

            guard let parsed = try? JSONDecoder().decode(OllamaParsedAction.self, from: data),
                  let rawType = parsed.action,
                  let actionType = MacActionType(rawValue: rawType) else {
                return nil
            }

            if actionType == .unknown {
                return nil
            }

            return MacAction(
                type: actionType,
                app: parsed.app,
                url: parsed.url,
                query: parsed.query,
                reminderTitle: parsed.reminderTitle,
                delaySeconds: parsed.delaySeconds,
                service: parsed.service,
                recipient: parsed.recipient,
                messageText: parsed.messageText,
                shortcutName: parsed.shortcutName,
                clarificationPrompt: parsed.clarificationPrompt
            )
        } catch {
            return nil
        }
    }

    private func extractJSON(from text: String) -> String {
        var str = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("```json") {
            str = String(str.dropFirst(7))
        } else if str.hasPrefix("```") {
            str = String(str.dropFirst(3))
        }
        if str.hasSuffix("```") {
            str = String(str.dropLast(3))
        }
        str = str.trimmingCharacters(in: .whitespacesAndNewlines)

        // Find outermost { and }
        if let start = str.firstIndex(of: "{"), let end = str.lastIndex(of: "}") {
            return String(str[start...end])
        }
        return str
    }
}
