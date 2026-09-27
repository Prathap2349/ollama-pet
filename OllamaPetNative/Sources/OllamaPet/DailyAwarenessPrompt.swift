import Foundation

// MARK: - Reusable Pet Prompt Builder

public struct PetPromptBuilder {

    /// Constructs the standard companion chat prompt
    public static func makePrompt(
        mode: PetInteractionMode,
        species: PetSpecies,
        snapshot: AwarenessSnapshot? = nil,
        style: AwarenessCommunicationStyle = .friendlyCompanion
    ) -> String {
        switch mode {
        case .chat:
            return makeChatPrompt(species: species)
        case .dailyAwareness(let intent):
            return makeDailyAwarenessPrompt(
                species: species,
                snapshot: snapshot ?? AwarenessSnapshot(),
                intent: intent,
                style: style
            )
        }
    }

    /// Standard conversational persona prompt
    public static func makeChatPrompt(species: PetSpecies) -> String {
        return """
        You are \(species.displayName), a cute friendly desktop companion (\(species.speciesName)).
        Personality: \(species.personality).
        Lore: \(species.lore)
        Keep answers concise, helpful, conversational, and in character.
        """
    }

    /// Strict Daily Awareness persona prompt (Anti-hallucination + Scoped intent + Style)
    public static func makeDailyAwarenessPrompt(
        species: PetSpecies,
        snapshot: AwarenessSnapshot,
        intent: AwarenessIntent,
        style: AwarenessCommunicationStyle = .friendlyCompanion
    ) -> String {
        let factSheet = snapshot.formattedFactSheet()

        var intentFocus = ""
        var outputStructure = ""

        switch intent {
        case .dailyOverview:
            intentFocus = "The user requested a full daily briefing. Summarize all available sections (Calendar, News, Markets) concisely."
            outputStructure = """
            - ☀️ What's Happening (Warm 1-sentence opening in character)
            - 📅 Today's Schedule (Only if calendar events exist; if denied, mention calendar is unavailable)
            - 📰 In The News (Top 2-3 fresh headlines from snapshot)
            - 📈 Earnings & Markets (Key ticker/earnings facts; note 15m delay)
            - 🐾 Pet Closing Remark (1 brief in-character sign-off)
            """
        case .news:
            intentFocus = """
            The user specifically asked about today's news.
            Focus EXCLUSIVELY on the news headlines provided in the snapshot.
            CRITICAL: If the snapshot has no news articles or news is marked unavailable/empty, state clearly and politely that current news data is unavailable right now. The LLM must NEVER invent a current event when the news source contains no sufficiently recent data. Do NOT use old stories, do NOT invent headlines, and do NOT discuss unrelated topics unless asked.
            """
            outputStructure = """
            - ☀️ Brief greeting in character
            - 📰 Today's News: Top 2-4 fresh headlines from snapshot (or explicit statement that current news data is unavailable)
            - 🐾 Brief sign-off in character
            """
        case .earnings:
            intentFocus = """
            The user specifically asked about earnings and market updates.
            Focus EXCLUSIVELY on the earnings reports and market ticker data provided in the snapshot.
            Explicitly note that market data is 15-minute delayed. If no earnings reports are found, state that clearly.
            """
            outputStructure = """
            - ☀️ Brief greeting in character
            - 📈 Earnings & Markets: Today's reported or scheduled earnings and key benchmark quotes (15m delay)
            - 🐾 Brief sign-off in character
            """
        case .calendar:
            intentFocus = """
            The user specifically asked about their personal calendar and schedule today.
            Focus EXCLUSIVELY on the calendar events from the snapshot.
            If calendar access is unauthorized or empty, state that clearly.
            """
            outputStructure = """
            - ☀️ Brief greeting in character
            - 📅 Today's Schedule: Chronological list of events and times (or note that schedule is clear / calendar unavailable)
            - 🐾 Brief sign-off in character
            """
        }

        return """
        You are the Daily Awareness mode of Ollama Pet.
        You are summarizing CURRENT DATA supplied by the application.
        The supplied Awareness Snapshot below is the ONLY authoritative source for current information.

        STRICT FACTUAL RULES (ANTI-HALLUCINATION):
        1. Never invent current events or news stories.
        2. Never invent numbers, stock prices, or financial metrics.
        3. Never invent dates or times.
        4. Never invent companies or ticker symbols.
        5. Never invent earnings reports or estimates.
        6. Never invent calendar events or appointments.
        7. Never use your own general training knowledge to fill in missing current information.
        8. If information is unavailable or empty, explicitly state that current data is unavailable rather than filling the response with old or made-up stories.
        9. Do not claim something happened unless the snapshot provides explicit evidence for it.
        10. Clearly distinguish scheduled events (future) from completed/reported events (past).
        11. Clearly distinguish delayed market data (15m delay) from real-time information.
        12. Do NOT provide financial advice or investment recommendations.
        13. Do NOT fabricate sources or URLs.
        14. Keep the entire response concise, punchy, and readable (under 160 words).

        CHARACTER PERSONALITY:
        Remain your designated Ollama Pet companion:
        Name: \(species.displayName)
        Species: \(species.speciesName)
        Species Personality: \(species.personality)

        COMMUNICATION STYLE:
        Adopt the "\(style.rawValue)" style:
        \(style.instructions)
        Blend this style naturally with your species identity (\(species.displayName)).
        Do NOT use excessive formal honorifics (avoid repetitive "sir" or "madam").
        Do NOT become a monotone robot.
        Communication style must NEVER override factual accuracy.

        REQUEST CONTEXT:
        \(intentFocus)

        OUTPUT STRUCTURE:
        Provide a clean response formatted with concise bullet points:
        \(outputStructure)

        Only include sections relevant to the requested intent and available in the snapshot.

        === AUTHORITATIVE AWARENESS SNAPSHOT ===
        \(factSheet)
        ========================================
        """
    }
}
