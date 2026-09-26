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

        // B. Timers (e.g. "set a timer for 10 minutes", "timer for 1 minute")
        if let timerAction = parseTimer(from: text, lower: lower) {
            return timerAction
        }

        // C. Extract specific browser target if present (e.g. "in Google Chrome", "in Safari", "in Firefox")
        let (cleanedText, cleanedLower, targetBrowser) = extractBrowser(from: text, lower: lower)

        // D. Search Web & Media
        if cleanedLower.starts(with: "play ") && (cleanedLower.contains("on youtube") || cleanedLower.contains("in youtube")) {
            var q = cleanedText
            if let range = q.range(of: "play ", options: .caseInsensitive) {
                q.removeSubrange(range)
            }
            if let range = q.range(of: " on youtube", options: .caseInsensitive) {
                q.removeSubrange(range)
            } else if let range = q.range(of: " in youtube", options: .caseInsensitive) {
                q.removeSubrange(range)
            }
            let trimmedQ = q.trimmingCharacters(in: .whitespaces)
            let encoded = trimmedQ.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmedQ
            return MacAction(type: .openURL, url: "https://www.youtube.com/results?search_query=\(encoded)", browser: targetBrowser)
        }
        if cleanedLower == "play lofi" || cleanedLower == "play lofi on youtube" || cleanedLower == "play lofi music" {
            return MacAction(type: .openURL, url: "https://www.youtube.com/results?search_query=lofi+hip+hop+radio", browser: targetBrowser)
        }
        if cleanedLower.starts(with: "search youtube for ") {
            let q = String(cleanedText.dropFirst("search youtube for ".count)).trimmingCharacters(in: .whitespaces)
            let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
            return MacAction(type: .openURL, url: "https://www.youtube.com/results?search_query=\(encoded)", browser: targetBrowser)
        }
        if cleanedLower.starts(with: "search google for ") {
            let q = String(cleanedText.dropFirst("search google for ".count)).trimmingCharacters(in: .whitespaces)
            return MacAction(type: .searchWeb, browser: targetBrowser, query: q)
        }
        if cleanedLower.starts(with: "search the web for ") || cleanedLower.starts(with: "search web for ") {
            let prefix = cleanedLower.starts(with: "search the web for ") ? "search the web for " : "search web for "
            let q = String(cleanedText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            return MacAction(type: .searchWeb, browser: targetBrowser, query: q)
        }
        if cleanedLower.starts(with: "search for ") {
            let q = String(cleanedText.dropFirst("search for ".count)).trimmingCharacters(in: .whitespaces)
            return MacAction(type: .searchWeb, browser: targetBrowser, query: q)
        }
        if cleanedLower.starts(with: "google ") {
            let q = String(cleanedText.dropFirst("google ".count)).trimmingCharacters(in: .whitespaces)
            return MacAction(type: .searchWeb, browser: targetBrowser, query: q)
        }

        // E. Direct System Apps / Services
        if cleanedLower == "open calendar" || cleanedLower == "launch calendar" {
            return MacAction(type: .openCalendar)
        }
        if cleanedLower == "open reminders" || cleanedLower == "launch reminders" {
            return MacAction(type: .openReminders)
        }
        if cleanedLower == "open whatsapp" || cleanedLower == "launch whatsapp" {
            return MacAction(type: .openWhatsApp)
        }
        if cleanedLower == "open messages" || cleanedLower == "launch messages" || cleanedLower == "open imessage" {
            return MacAction(type: .openMessages)
        }
        if cleanedLower == "open system settings" || cleanedLower == "open settings" || cleanedLower == "launch system settings" {
            return MacAction(type: .openSystemSettings)
        }
        if cleanedLower == "show action history" || cleanedLower == "open action history" {
            return MacAction(type: .showActionHistory)
        }

        // F. System Vitals & Stats (RAM, CPU, Battery, Top Apps)
        if cleanedLower.contains("ram") || cleanedLower.contains("memory usage") || cleanedLower.contains("how much memory") || cleanedLower.contains("battery") || cleanedLower.contains("top app") || cleanedLower.contains("which app") || cleanedLower.contains("system vitals") || cleanedLower == "cpu load" || cleanedLower == "cpu usage" {
            return MacAction(type: .querySystemVitals, query: cleanedLower)
        }

        // G. Focus Control
        if cleanedLower.contains("start focus") || cleanedLower.contains("focus session") || cleanedLower.contains("start a focus") || cleanedLower.contains("pomodoro") {
            var duration = 25 * 60
            if let match = cleanedLower.range(of: #"\d+"#, options: .regularExpression) {
                if let mins = Int(cleanedLower[match]) {
                    duration = max(1, mins * 60)
                }
            }
            return MacAction(type: .controlFocus, durationSeconds: duration)
        }

        // H. Presence Monitor Control
        if cleanedLower == "stop monitoring" || cleanedLower == "stop monitor" || cleanedLower == "turn off monitor" || cleanedLower == "disable monitor" || cleanedLower == "disable presence monitor" {
            return MacAction(type: .controlMonitoring)
        }

        // F. Approved Shortcuts
        if cleanedLower.starts(with: "run shortcut ") || cleanedLower.starts(with: "run my shortcut ") || cleanedLower.starts(with: "run approved shortcut ") {
            let prefixes = ["run approved shortcut ", "run my shortcut ", "run shortcut "]
            for p in prefixes {
                if cleanedLower.starts(with: p) {
                    let name = String(cleanedText.dropFirst(p.count)).trimmingCharacters(in: .whitespaces)
                    return MacAction(type: .runApprovedShortcut, shortcutName: name, requiresConfirmation: true)
                }
            }
        }

        // G. Send Message (WhatsApp / Messages)
        if cleanedLower.contains(" saying ") && (cleanedLower.contains("message") || cleanedLower.contains("whatsapp") || cleanedLower.contains("send") || cleanedLower.starts(with: "text ")) {
            return parseSendMessage(from: cleanedText, lower: cleanedLower)
        }
        if cleanedLower.starts(with: "send ") && (cleanedLower.contains("message") || cleanedLower.contains("whatsapp")) {
            return parseSendMessage(from: cleanedText, lower: cleanedLower)
        }

        // H. Open URLs / Websites with optional Browser Target
        if cleanedLower.starts(with: "go to ") || cleanedLower.starts(with: "navigate to ") {
            let site = cleanedLower.starts(with: "go to ") ? String(cleanedText.dropFirst(6)) : String(cleanedText.dropFirst(12))
            let trimmedSite = site.trimmingCharacters(in: .whitespaces)
            let lowerSite = trimmedSite.lowercased()
            if lowerSite == "youtube" || lowerSite == "youtube.com" {
                return MacAction(type: .openURL, url: "https://www.youtube.com", browser: targetBrowser)
            } else if lowerSite == "google" || lowerSite == "google.com" {
                return MacAction(type: .openURL, url: "https://www.google.com", browser: targetBrowser)
            } else if lowerSite == "github" || lowerSite == "github.com" {
                return MacAction(type: .openURL, url: "https://www.github.com", browser: targetBrowser)
            } else if lowerSite.contains(".com") || lowerSite.contains(".org") || lowerSite.contains(".net") || lowerSite.contains(".io") || lowerSite.starts(with: "http") {
                let url = lowerSite.starts(with: "http") ? trimmedSite : "https://\(trimmedSite)"
                return MacAction(type: .openURL, url: url, browser: targetBrowser)
            }
        }
        if cleanedLower.starts(with: "open http://") || cleanedLower.starts(with: "open https://") {
            let urlStr = String(cleanedText.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            return MacAction(type: .openURL, url: urlStr, browser: targetBrowser)
        }
        if cleanedLower == "open youtube" || cleanedLower == "launch youtube" {
            return MacAction(type: .openURL, url: "https://www.youtube.com", browser: targetBrowser)
        }
        if cleanedLower == "open github" || cleanedLower == "launch github" {
            return MacAction(type: .openURL, url: "https://www.github.com", browser: targetBrowser)
        }
        if cleanedLower == "open google" || cleanedLower == "launch google" {
            return MacAction(type: .openURL, url: "https://www.google.com", browser: targetBrowser)
        }

        // I. General Open App
        if cleanedLower.starts(with: "open ") || cleanedLower.starts(with: "launch ") || cleanedLower.starts(with: "start ") {
            let appName: String
            if cleanedLower.starts(with: "open ") {
                appName = String(cleanedText.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            } else if cleanedLower.starts(with: "launch ") {
                appName = String(cleanedText.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            } else {
                appName = String(cleanedText.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            }

            // If appName ends with a website domain, treat as URL
            if appName.contains(".com") || appName.contains(".org") || appName.contains(".net") || appName.contains(".io") {
                return MacAction(type: .openURL, url: "https://\(appName)", browser: targetBrowser)
            }

            if !appName.isEmpty {
                return MacAction(type: .openApp, app: appName)
            }
        }

        return nil
    }

    // MARK: - Browser Target Extraction

    private func extractBrowser(from text: String, lower: String) -> (cleanedText: String, cleanedLower: String, browser: String?) {
        let browserPatterns: [(pattern: String, name: String)] = [
            (" in google chrome", "Google Chrome"),
            (" on google chrome", "Google Chrome"),
            (" using google chrome", "Google Chrome"),
            (" with google chrome", "Google Chrome"),
            (" in chrome", "Google Chrome"),
            (" on chrome", "Google Chrome"),
            (" using chrome", "Google Chrome"),
            (" with chrome", "Google Chrome"),
            (" in safari", "Safari"),
            (" on safari", "Safari"),
            (" using safari", "Safari"),
            (" with safari", "Safari"),
            (" in firefox", "Firefox"),
            (" on firefox", "Firefox"),
            (" using firefox", "Firefox"),
            (" with firefox", "Firefox"),
            (" in microsoft edge", "Microsoft Edge"),
            (" on microsoft edge", "Microsoft Edge"),
            (" using microsoft edge", "Microsoft Edge"),
            (" in edge", "Microsoft Edge"),
            (" on edge", "Microsoft Edge"),
            (" using edge", "Microsoft Edge"),
            (" in brave browser", "Brave Browser"),
            (" on brave browser", "Brave Browser"),
            (" using brave browser", "Brave Browser"),
            (" in brave", "Brave Browser"),
            (" on brave", "Brave Browser"),
            (" using brave", "Brave Browser")
        ]

        for (pattern, name) in browserPatterns {
            if lower.hasSuffix(pattern) {
                let cleaned = String(text.dropLast(pattern.count)).trimmingCharacters(in: .whitespaces)
                let cleanedLower = String(lower.dropLast(pattern.count)).trimmingCharacters(in: .whitespaces)
                return (cleaned, cleanedLower, name)
            }
        }
        return (text, lower, nil)
    }

    // MARK: - Timer Extraction

    private func parseTimer(from text: String, lower: String) -> MacAction? {
        let prefixes = ["set a timer for ", "set timer for ", "start a timer for ", "start timer for ", "timer for "]
        for p in prefixes {
            if lower.starts(with: p) {
                let timeStr = String(text.dropFirst(p.count)).trimmingCharacters(in: .whitespaces)
                let secs = parseTimeInterval(timeStr.lowercased())
                return MacAction(type: .setTimer, delaySeconds: secs)
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
        if let sayingRange = lower.range(of: " saying ") {
            message = String(text[sayingRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            let beforeSaying = String(text[..<sayingRange.lowerBound])
            let beforeLower = beforeSaying.lowercased()

            let candidateTriggers = [
                "and message ", "and text ",
                "message ", "text ",
                "send a whatsapp to ", "send whatsapp to ",
                "send a message to ", "send message to ",
                "send a whatsapp message to ", "send whatsapp message to ",
                "send to ", "send "
            ]

            for trigger in candidateTriggers {
                if let r = beforeLower.range(of: trigger) {
                    let after = String(beforeSaying[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                    let cleanAfter = after
                        .replacingOccurrences(of: "a whatsapp message to ", with: "", options: .caseInsensitive)
                        .replacingOccurrences(of: "a message to ", with: "", options: .caseInsensitive)
                        .replacingOccurrences(of: "a whatsapp to ", with: "", options: .caseInsensitive)
                        .replacingOccurrences(of: "a text to ", with: "", options: .caseInsensitive)
                        .trimmingCharacters(in: .whitespaces)
                    let words = cleanAfter.components(separatedBy: " ")
                    if let first = words.first, !first.isEmpty {
                        recipient = first
                        break
                    }
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
