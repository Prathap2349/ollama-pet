import Foundation

// MARK: - Awareness Source Freshness & Status

public enum AwarenessSourceStatus: Codable, Equatable {
    case available
    case cached
    case empty
    case unauthorized
    case delayed(minutes: Int)
    case error(message: String)

    public var isAvailable: Bool {
        switch self {
        case .available, .cached, .delayed:
            return true
        default:
            return false
        }
    }

    public var displayText: String {
        switch self {
        case .available:
            return "Current"
        case .cached:
            return "Cached"
        case .empty:
            return "No data"
        case .unauthorized:
            return "Unauthorized"
        case .delayed(let mins):
            return "Delayed (\(mins)m)"
        case .error(let msg):
            return "Unavailable (\(msg))"
        }
    }
}

public struct SourceFreshness: Codable, Equatable, Identifiable {
    public var id: String { sourceName }
    public let sourceName: String
    public let fetchedAt: Date
    public let status: AwarenessSourceStatus
    public let detail: String?

    public init(
        sourceName: String,
        fetchedAt: Date = Date(),
        status: AwarenessSourceStatus,
        detail: String? = nil
    ) {
        self.sourceName = sourceName
        self.fetchedAt = fetchedAt
        self.status = status
        self.detail = detail
    }
}

// MARK: - Normalized News Item

public struct AwarenessNewsItem: Identifiable, Codable, Equatable {
    public let id: String
    public let title: String
    public let source: String
    public let publishedAt: Date?
    public let url: String?
    public let snippet: String?
    public let category: String?

    public init(
        id: String = UUID().uuidString,
        title: String,
        source: String,
        publishedAt: Date? = nil,
        url: String? = nil,
        snippet: String? = nil,
        category: String? = nil
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.publishedAt = publishedAt
        self.url = url
        self.snippet = snippet
        self.category = category
    }
}

// MARK: - Normalized Earnings / Market Item

public struct AwarenessEarningsItem: Identifiable, Codable, Equatable {
    public let id: String
    public let symbol: String
    public let companyName: String?
    public let date: String // e.g. "2026-09-27"
    public let timing: String // "Before Market Open (BMO)", "After Market Close (AMC)", or "Scheduled"
    public let epsEstimate: Double?
    public let epsActual: Double?
    public let revenueEstimate: Double?
    public let revenueActual: Double?
    public let currentPrice: Double?
    public let changePercent: Double?
    public let isReported: Bool
    public let isDelayed: Bool

    public init(
        id: String = UUID().uuidString,
        symbol: String,
        companyName: String? = nil,
        date: String,
        timing: String = "Scheduled",
        epsEstimate: Double? = nil,
        epsActual: Double? = nil,
        revenueEstimate: Double? = nil,
        revenueActual: Double? = nil,
        currentPrice: Double? = nil,
        changePercent: Double? = nil,
        isReported: Bool = false,
        isDelayed: Bool = true
    ) {
        self.id = id
        self.symbol = symbol
        self.companyName = companyName
        self.date = date
        self.timing = timing
        self.epsEstimate = epsEstimate
        self.epsActual = epsActual
        self.revenueEstimate = revenueEstimate
        self.revenueActual = revenueActual
        self.currentPrice = currentPrice
        self.changePercent = changePercent
        self.isReported = isReported
        self.isDelayed = isDelayed
    }
}

// MARK: - Normalized Calendar Item (Privacy Preserving)

public struct AwarenessCalendarItem: Identifiable, Codable, Equatable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let calendarName: String?
    public let timeFormatted: String

    public init(
        id: String = UUID().uuidString,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        calendarName: String? = nil,
        timeFormatted: String
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendarName = calendarName
        self.timeFormatted = timeFormatted
    }
}

// MARK: - Unified Awareness Snapshot

public struct AwarenessSnapshot: Codable, Equatable {
    public let generatedAt: Date
    public let timezone: String
    public let news: [AwarenessNewsItem]
    public let earnings: [AwarenessEarningsItem]
    public let calendarEvents: [AwarenessCalendarItem]
    public let freshness: [SourceFreshness]

    public init(
        generatedAt: Date = Date(),
        timezone: String = TimeZone.autoupdatingCurrent.identifier,
        news: [AwarenessNewsItem] = [],
        earnings: [AwarenessEarningsItem] = [],
        calendarEvents: [AwarenessCalendarItem] = [],
        freshness: [SourceFreshness] = []
    ) {
        self.generatedAt = generatedAt
        self.timezone = timezone
        self.news = news
        self.earnings = earnings
        self.calendarEvents = calendarEvents
        self.freshness = freshness
    }

    /// Formats the snapshot into clean, factual text lines strictly for the prompt.
    /// Does not include speculative commentary or AI interpretation.
    public func formattedFactSheet() -> String {
        var sections: [String] = []

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.autoupdatingCurrent

        sections.append("SNAPSHOT METADATA:")
        sections.append("- Generated At: \(formatter.string(from: generatedAt))")
        sections.append("- Local Timezone: \(timezone)")

        // Freshness status per source
        sections.append("\nDATA SOURCES STATUS:")
        for item in freshness {
            let note = item.detail != nil ? " (\(item.detail!))" : ""
            sections.append("- \(item.sourceName): \(item.status.displayText)\(note)")
        }

        // Calendar section
        sections.append("\nTODAY'S CALENDAR EVENTS:")
        if calendarEvents.isEmpty {
            let calStatus = freshness.first(where: { $0.sourceName.lowercased().contains("calendar") })
            if let calStatus = calStatus, calStatus.status == .unauthorized {
                sections.append("- Calendar access is not permitted by user.")
            } else {
                sections.append("- No scheduled events for today.")
            }
        } else {
            for event in calendarEvents {
                let calTag = event.calendarName != nil ? " [\(event.calendarName!)]" : ""
                sections.append("- \(event.timeFormatted): \(event.title)\(calTag)")
            }
        }

        // News section
        sections.append("\nTOP NEWS HEADLINES:")
        if news.isEmpty {
            sections.append("- No news articles available at this time.")
        } else {
            for item in news {
                let cat = item.category != nil ? "[\(item.category!)] " : ""
                sections.append("- \(cat)\(item.title) (Source: \(item.source))")
            }
        }

        // Earnings and Market section
        sections.append("\nEARNINGS & MARKET WATCH (Delayed Data):")
        if earnings.isEmpty {
            sections.append("- No earnings reports or market updates for today.")
        } else {
            for item in earnings {
                var details: [String] = []
                details.append("Timing: \(item.timing)")
                if let price = item.currentPrice {
                    details.append(String(format: "Price: $%.2f", price))
                }
                if let change = item.changePercent {
                    details.append(String(format: "Change: %+.2f%%", change))
                }
                if let epsEst = item.epsEstimate {
                    details.append(String(format: "EPS Est: $%.2f", epsEst))
                }
                if let epsAct = item.epsActual {
                    details.append(String(format: "EPS Actual: $%.2f", epsAct))
                }
                let detailStr = details.joined(separator: ", ")
                let nameStr = item.companyName != nil ? " (\(item.companyName!))" : ""
                sections.append("- \(item.symbol)\(nameStr): \(detailStr)")
            }
        }

        return sections.joined(separator: "\n")
    }
}

// MARK: - Awareness Intent & Interaction Mode

public enum AwarenessIntent: String, CaseIterable, Codable {
    case dailyOverview = "Daily Overview"
    case news = "News Digest"
    case earnings = "Earnings & Markets"
    case calendar = "Today's Calendar"

    public var title: String { rawValue }
}

public enum PetInteractionMode: Equatable {
    case chat
    case dailyAwareness(intent: AwarenessIntent)
}

// MARK: - Awareness Communication Style (Issue 9)

public enum AwarenessCommunicationStyle: String, CaseIterable, Codable {
    case personalAssistant = "Personal Assistant"
    case friendlyCompanion = "Friendly Companion"
    case professionalCompanion = "Professional Companion"

    public var title: String { rawValue }

    public var instructions: String {
        switch self {
        case .personalAssistant:
            return "Polite, respectful, calm, efficient, and helpful, with a polished assistant tone."
        case .friendlyCompanion:
            return "Warm, natural, casual, supportive, and conversational, like an encouraging friend."
        case .professionalCompanion:
            return "Concise, clear, composed, informative, and direct, with minimal playfulness."
        }
    }
}
