import Foundation
import Combine
import SwiftUI

// MARK: - Deterministic Awareness Intent Detector

public struct AwarenessIntentDetector {
    /// Evaluates user text deterministically without any LLM calls
    public static func detectIntent(from text: String) -> AwarenessIntent? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()

        // 1. Calendar intent
        if lower.contains("calendar") ||
            lower.contains("schedule today") ||
            lower.contains("my schedule") ||
            lower.contains("what do i have today") ||
            lower.contains("what's on my agenda") ||
            lower.contains("what is on my agenda") ||
            lower.contains("my agenda") ||
            lower.contains("appointments today") ||
            lower.contains("meetings today") ||
            lower.contains("what's planned today") {
            return .calendar
        }

        // 2. Earnings and Market intent
        if lower.contains("earnings") ||
            lower.contains("stock market") ||
            lower.contains("stocks today") ||
            lower.contains("market today") ||
            lower.contains("companies i'm watching") ||
            lower.contains("companies im watching") ||
            lower.contains("watching companies") ||
            lower.contains("big earnings") ||
            lower.contains("market update") ||
            lower.contains("any earnings today") {
            return .earnings
        }

        // 3. News intent
        if lower.contains("news today") ||
            lower.contains("today's news") ||
            lower.contains("in the news") ||
            lower.contains("happening in the world") ||
            lower.contains("world news") ||
            lower.contains("latest news") ||
            lower.contains("top headlines") ||
            lower.contains("headlines today") {
            return .news
        }

        // 4. Daily Overview / Morning Update intent
        if lower.contains("what's happening today") ||
            lower.contains("what is happening today") ||
            lower.contains("what's happening") ||
            lower.contains("what is happening") ||
            lower.contains("what's new") ||
            lower.contains("what is new") ||
            lower.contains("morning update") ||
            lower.contains("daily update") ||
            lower.contains("morning briefing") ||
            lower.contains("daily digest") ||
            lower.contains("morning digest") ||
            lower.contains("give me my morning update") ||
            lower.contains("give me today's update") ||
            lower.contains("today's update") ||
            lower.contains("tell me about today") ||
            lower == "today" ||
            lower == "update" {
            return .dailyOverview
        }

        return nil
    }
}

// MARK: - Central Daily Awareness Service

@MainActor
public final class DailyAwarenessService: ObservableObject {
    public static let shared = DailyAwarenessService()

    @Published public var isFetching: Bool = false
    @Published public var isSummarizing: Bool = false
    @Published public var currentMode: PetInteractionMode = .chat
    @Published public var lastSnapshot: AwarenessSnapshot? = nil
    @Published public var lastFetchTime: Date? = nil
    @Published public var statusMessage: String = "Ready"
    @Published public var lastError: String? = nil

    private let newsDataSource = NewsDataSource()
    private let marketDataSource = MarketDataSource()
    private let calendarDataSource = CalendarDataSource()

    /// 15 minute cache TTL to avoid unnecessary network polling
    public let cacheTTL: TimeInterval = 900.0

    private init() {}

    // MARK: - Snapshot Acquisition & Caching

    /// Retrieves cached snapshot or fetches fresh data if expired or forced
    public func getOrFetchSnapshot(forceRefresh: Bool = false) async -> AwarenessSnapshot {
        if !forceRefresh, let cached = lastSnapshot, let lastTime = lastFetchTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < cacheTTL {
                NSLog("[DailyAwarenessService] Reusing valid cached snapshot (age: %.0fs)", elapsed)
                return cached
            }
        }

        return await fetchFreshSnapshot()
    }

    /// Fetches all sources in parallel with structured concurrency and partial failure tolerance
    public func fetchFreshSnapshot() async -> AwarenessSnapshot {
        isFetching = true
        statusMessage = "Checking news, calendar & markets..."
        defer {
            isFetching = false
            statusMessage = "Ready"
        }

        // Parallel non-blocking execution
        async let newsResult = fetchNewsSafe()
        async let marketResult = fetchMarketSafe()
        async let calendarResult = fetchCalendarSafe()

        let (newsItems, newsFreshness) = await newsResult
        let (earningsItems, marketFreshness) = await marketResult
        let (calendarItems, calFreshness) = await calendarResult

        let snapshot = AwarenessSnapshot(
            generatedAt: Date(),
            timezone: TimeZone.autoupdatingCurrent.identifier,
            news: newsItems,
            earnings: earningsItems,
            calendarEvents: calendarItems,
            freshness: [calFreshness, newsFreshness, marketFreshness]
        )

        self.lastSnapshot = snapshot
        self.lastFetchTime = Date()
        self.lastError = nil
        return snapshot
    }

    // MARK: - Safe Data Fetchers

    private func fetchNewsSafe() async -> ([AwarenessNewsItem], SourceFreshness) {
        do {
            return try await newsDataSource.fetch()
        } catch {
            NSLog("[DailyAwarenessService] News fetch error: %@", error.localizedDescription)
            return (
                [],
                SourceFreshness(
                    sourceName: "News",
                    status: .error(message: error.localizedDescription),
                    detail: "Network or source unavailable"
                )
            )
        }
    }

    private func fetchMarketSafe() async -> ([AwarenessEarningsItem], SourceFreshness) {
        do {
            return try await marketDataSource.fetch()
        } catch {
            NSLog("[DailyAwarenessService] Market fetch error: %@", error.localizedDescription)
            return (
                [],
                SourceFreshness(
                    sourceName: "Earnings & Markets",
                    status: .error(message: error.localizedDescription),
                    detail: "Market feed unavailable"
                )
            )
        }
    }

    private func fetchCalendarSafe() async -> ([AwarenessCalendarItem], SourceFreshness) {
        do {
            return try await calendarDataSource.fetch()
        } catch {
            NSLog("[DailyAwarenessService] Calendar fetch error: %@", error.localizedDescription)
            return (
                [],
                SourceFreshness(
                    sourceName: "Apple Calendar",
                    status: .error(message: error.localizedDescription),
                    detail: "Permission denied or unavailable"
                )
            )
        }
    }

    // MARK: - Transactional Awareness Generation

    /// Orchestrates end-to-end Daily Awareness generation strictly using local Ollama
    public func generateBriefing(
        userQuery: String,
        intent: AwarenessIntent,
        forceRefresh: Bool = false,
        onToken: @MainActor @escaping (String) -> Void
    ) async throws -> String {
        // Enter transactional Daily Awareness mode
        currentMode = .dailyAwareness(intent: intent)
        defer { currentMode = .chat }

        isSummarizing = true
        defer { isSummarizing = false }

        // 1. Fetch / Retrieve cached data
        let snapshot = await getOrFetchSnapshot(forceRefresh: forceRefresh)

        // 2. Build anti-hallucination factual prompt
        let species = PetState.shared.currentSpecies
        let systemPrompt = PetPromptBuilder.makePrompt(
            mode: .dailyAwareness(intent: intent),
            species: species,
            snapshot: snapshot
        )

        // 3. Invoke local-only AI policy
        statusMessage = "Summarizing with local Ollama..."
        let userMessage = ChatMessage(role: "user", content: userQuery)

        do {
            let result = try await AIProviderManager.shared.streamChat(
                systemPrompt: systemPrompt,
                messages: [userMessage],
                policy: .localOnly,
                onToken: onToken
            )
            return result
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    // MARK: - Permissions & Diagnostics

    public func requestCalendarPermission() async -> Bool {
        return await calendarDataSource.checkAndRequestAuthorization()
    }

    public var isCalendarAuthorized: Bool {
        return calendarDataSource.isAuthorized()
    }
}
