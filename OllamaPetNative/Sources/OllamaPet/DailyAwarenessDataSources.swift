import Foundation
import EventKit

// MARK: - Awareness Data Source Protocol

public protocol AwarenessDataSource {
    associatedtype Output
    var sourceName: String { get }
    func fetch() async throws -> (output: Output, freshness: SourceFreshness)
}

// MARK: - RSS Feed Parser (Zero external dependencies)

final class RSSXMLParserDelegate: NSObject, XMLParserDelegate {
    private var items: [AwarenessNewsItem] = []
    private var activeContainer: String? = nil
    private var currentTitle: String = ""
    private var currentLink: String = ""
    private var currentPubDate: String = ""
    private var currentDescription: String = ""
    private var insideItem: Bool = false
    private let sourceTitle: String
    private let categoryName: String?
    private let maxItems: Int
    private let cutoffDate: Date?

    init(sourceTitle: String, categoryName: String? = nil, maxItems: Int = 5, cutoffDate: Date? = nil) {
        self.sourceTitle = sourceTitle
        self.categoryName = categoryName
        self.maxItems = maxItems
        self.cutoffDate = cutoffDate
    }

    func parse(data: Data) -> [AwarenessNewsItem] {
        items.removeAll()
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let tag = elementName.lowercased()
        if tag == "item" || tag == "entry" {
            insideItem = true
            currentTitle = ""
            currentLink = ""
            currentPubDate = ""
            currentDescription = ""
            activeContainer = nil
        } else if insideItem {
            if tag == "link" && attributeDict["href"] != nil {
                currentLink = attributeDict["href"] ?? ""
            }
            if ["title", "link", "pubdate", "published", "updated", "description", "summary"].contains(tag) {
                activeContainer = tag
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideItem, let container = activeContainer else { return }
        switch container {
        case "title":
            currentTitle += string
        case "link":
            if currentLink.isEmpty { currentLink += string }
        case "pubdate", "published", "updated":
            currentPubDate += string
        case "description", "summary":
            currentDescription += string
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard insideItem, let container = activeContainer,
              let str = String(data: CDATABlock, encoding: .utf8) else { return }
        switch container {
        case "title":
            currentTitle += str
        case "link":
            if currentLink.isEmpty { currentLink += str }
        case "pubdate", "published", "updated":
            currentPubDate += str
        case "description", "summary":
            currentDescription += str
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let tag = elementName.lowercased()
        if tag == activeContainer {
            activeContainer = nil
        }
        if tag == "item" || tag == "entry" {
            insideItem = false
            activeContainer = nil
            let cleanTitle = sanitize(currentTitle)
            let cleanDesc = sanitize(currentDescription)
            let cleanUrl = currentLink.trimmingCharacters(in: .whitespacesAndNewlines)

            if !cleanTitle.isEmpty && items.count < maxItems {
                let parsedDate = parseDate(currentPubDate)

                // Discard clearly stale articles older than cutoffDate
                if let cutoff = cutoffDate, let date = parsedDate, date < cutoff {
                    return
                }

                let item = AwarenessNewsItem(
                    title: cleanTitle,
                    source: sourceTitle,
                    publishedAt: parsedDate,
                    url: cleanUrl.isEmpty ? nil : cleanUrl,
                    snippet: cleanDesc.isEmpty ? nil : String(cleanDesc.prefix(160)),
                    category: categoryName
                )
                items.append(item)
            }
        }
    }

    private func sanitize(_ text: String) -> String {
        var str = text
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")

        while str.contains("  ") {
            str = str.replacingOccurrences(of: "  ", with: " ")
        }
        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseDate(_ dateStr: String) -> Date? {
        let trimmed = dateStr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let rfc822 = DateFormatter()
        rfc822.locale = Locale(identifier: "en_US_POSIX")

        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "EEE, d MMM yyyy HH:mm:ss zzz",
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, d MMM yyyy HH:mm:ss Z",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        ]
        for fmt in formats {
            rfc822.dateFormat = fmt
            if let d = rfc822.date(from: trimmed) { return d }
        }

        let iso = ISO8601DateFormatter()
        return iso.date(from: trimmed)
    }
}

// MARK: - GNews Status & Test Types (Issue 2)

public enum GNewsTestResult: Equatable {
    case valid
    case invalidKey
    case rateLimited
    case networkError(String)
    case apiUnavailable(Int)

    public var displayText: String {
        switch self {
        case .valid: return "API Key Valid"
        case .invalidKey: return "API Key Invalid"
        case .rateLimited: return "Rate Limited"
        case .networkError: return "Network Error"
        case .apiUnavailable: return "API Unavailable"
        }
    }
}

public enum GNewsError: LocalizedError {
    case invalidKey
    case rateLimited
    case networkError(String)
    case apiUnavailable(Int)
    case invalidResponse

    public var userFacingMessage: String {
        switch self {
        case .invalidKey: return "GNews API Key is invalid or unauthorized"
        case .rateLimited: return "GNews API rate limit reached"
        case .networkError(let msg): return "GNews network error: \(msg)"
        case .apiUnavailable(let code): return "GNews API unavailable (HTTP \(code))"
        case .invalidResponse: return "GNews returned unexpected data format"
        }
    }

    public var errorDescription: String? { userFacingMessage }
}

// MARK: - News Data Source (GNews Priority + Public RSS Fallback only when unconfigured)

public final class NewsDataSource: AwarenessDataSource {
    public typealias Output = [AwarenessNewsItem]
    public let sourceName: String = "News"

    private let session: URLSession

    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 6.0
        config.timeoutIntervalForResource = 8.0
        self.session = URLSession(configuration: config)
    }

    /// Lightweight test for GNews API Key validity (Requirement 2)
    public static func testGNewsKey(apiKey: String) async -> GNewsTestResult {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return .invalidKey }

        guard let url = URL(string: "https://gnews.io/api/v4/top-headlines?category=general&lang=en&max=1&apikey=\(trimmedKey)") else {
            return .invalidKey
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 6.0
        request.setValue("OllamaPetNative/1.0", forHTTPHeaderField: "User-Agent")

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 6.0
        let testSession = URLSession(configuration: config)

        do {
            let (data, response) = try await testSession.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .apiUnavailable(500)
            }

            switch http.statusCode {
            case 200:
                struct TestResponse: Decodable {
                    struct Article: Decodable { let title: String? }
                    let articles: [Article]?
                }
                if let decoded = try? JSONDecoder().decode(TestResponse.self, from: data), decoded.articles != nil {
                    return .valid
                }
                return .valid
            case 401, 403:
                return .invalidKey
            case 429:
                return .rateLimited
            case 500...599:
                return .apiUnavailable(http.statusCode)
            default:
                return .apiUnavailable(http.statusCode)
            }
        } catch let err as URLError {
            return .networkError(err.localizedDescription)
        } catch {
            return .networkError(error.localizedDescription)
        }
    }

    public func fetch() async throws -> (output: [AwarenessNewsItem], freshness: SourceFreshness) {
        // 1. If user configured a GNews key in Keychain: MUST use GNews and NEVER silently fall back to RSS (Requirement 1 & 2)
        if let gnewsKey = APIKeyManager.shared.getKey(for: "gnews"), !gnewsKey.isEmpty {
            do {
                let gnewsItems = try await fetchGNews(apiKey: gnewsKey)
                if gnewsItems.isEmpty {
                    return (
                        [],
                        SourceFreshness(
                            sourceName: sourceName,
                            status: .empty,
                            detail: "GNews API returned no stories within the freshness window (36h)"
                        )
                    )
                }

                let newestDate = gnewsItems.compactMap { $0.publishedAt }.max()
                let dateStr = newestDate.map { DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .short) } ?? "Recent"

                return (
                    gnewsItems,
                    SourceFreshness(
                        sourceName: sourceName,
                        status: .available,
                        detail: "GNews API (\(gnewsItems.count) headlines, newest: \(dateStr))"
                    )
                )
            } catch let gError as GNewsError {
                // DO NOT SILENTLY FALL BACK TO RSS WHEN GNEWS FAILS!
                NSLog("[NewsDataSource] Configured GNews failed: %@", gError.userFacingMessage)
                return (
                    [],
                    SourceFreshness(
                        sourceName: sourceName,
                        status: .error(message: gError.userFacingMessage),
                        detail: "Configured GNews failed: \(gError.userFacingMessage)"
                    )
                )
            } catch {
                NSLog("[NewsDataSource] Configured GNews failed: %@", error.localizedDescription)
                return (
                    [],
                    SourceFreshness(
                        sourceName: sourceName,
                        status: .error(message: error.localizedDescription),
                        detail: "Configured GNews failed: \(error.localizedDescription)"
                    )
                )
            }
        }

        // 2. Default: Public RSS Feeds (Only when no GNews key is configured)
        // Discard stale articles older than 36 hours (Requirement 1)
        let cutoffDate = Calendar.current.date(byAdding: .hour, value: -36, to: Date()) ?? Date().addingTimeInterval(-36 * 3600)
        var allItems: [AwarenessNewsItem] = []

        // Fetch BBC World & Tech concurrently
        async let worldItemsTask = fetchRSS(
            url: URL(string: "https://feeds.bbci.co.uk/news/world/rss.xml")!,
            source: "BBC News",
            category: "World",
            max: 6,
            cutoffDate: cutoffDate
        )
        async let techItemsTask = fetchRSS(
            url: URL(string: "https://feeds.bbci.co.uk/news/technology/rss.xml")!,
            source: "BBC Tech",
            category: "Technology",
            max: 4,
            cutoffDate: cutoffDate
        )

        let (worldItems, techItems) = await (worldItemsTask, techItemsTask)
        if let w = worldItems { allItems.append(contentsOf: w) }
        if let t = techItems { allItems.append(contentsOf: t) }

        // Deduplicate headlines by normalized alphanumeric title
        var uniqueHeadlines = Set<String>()
        var dedupedItems: [AwarenessNewsItem] = []
        for item in allItems {
            let normKey = item.title.lowercased().filter { $0.isLetter || $0.isNumber }
            guard !uniqueHeadlines.contains(normKey) else { continue }
            uniqueHeadlines.insert(normKey)
            dedupedItems.append(item)
        }

        // Sort newest first
        dedupedItems.sort { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }

        if dedupedItems.isEmpty {
            return (
                [],
                SourceFreshness(
                    sourceName: sourceName,
                    status: .empty,
                    detail: "No fresh public news stories found within the last 36 hours"
                )
            )
        }

        let newestDate = dedupedItems.compactMap { $0.publishedAt }.max()
        let dateStr = newestDate.map { DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .short) } ?? "Recent"

        return (
            Array(dedupedItems.prefix(6)),
            SourceFreshness(
                sourceName: sourceName,
                status: .available,
                detail: "Public RSS (\(dedupedItems.count) headlines, newest: \(dateStr))"
            )
        )
    }

    private func fetchRSS(url: URL, source: String, category: String?, max: Int, cutoffDate: Date?) async -> [AwarenessNewsItem]? {
        var request = URLRequest(url: url)
        request.setValue("OllamaPetNative/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 5.0
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let parser = RSSXMLParserDelegate(sourceTitle: source, categoryName: category, maxItems: max, cutoffDate: cutoffDate)
            let items = parser.parse(data: data)
            return items.isEmpty ? nil : items
        } catch {
            return nil
        }
    }

    private func fetchGNews(apiKey: String) async throws -> [AwarenessNewsItem] {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw GNewsError.invalidKey }

        // Date window: strictly last 36 hours
        let cutoffDate = Calendar.current.date(byAdding: .hour, value: -36, to: Date()) ?? Date().addingTimeInterval(-36 * 3600)
        let isoFormatter = ISO8601DateFormatter()
        let fromDateStr = isoFormatter.string(from: cutoffDate)

        // Request freshest available articles using search with sortby=publishedAt & from date window
        guard let url = URL(string: "https://gnews.io/api/v4/search?q=news&sortby=publishedAt&lang=en&max=10&from=\(fromDateStr)&apikey=\(trimmedKey)") else {
            throw GNewsError.invalidKey
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 6.0
        request.setValue("OllamaPetNative/1.0 (macOS)", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let err as URLError {
            throw GNewsError.networkError(err.localizedDescription)
        } catch {
            throw GNewsError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw GNewsError.invalidResponse
        }

        switch http.statusCode {
        case 200:
            break
        case 401, 403:
            throw GNewsError.invalidKey
        case 429:
            throw GNewsError.rateLimited
        default:
            throw GNewsError.apiUnavailable(http.statusCode)
        }

        struct GNewsResponse: Decodable {
            struct Article: Decodable {
                struct Source: Decodable {
                    let name: String?
                }
                let title: String
                let description: String?
                let url: String?
                let publishedAt: String?
                let source: Source?
            }
            let articles: [Article]?
        }

        guard let decoded = try? JSONDecoder().decode(GNewsResponse.self, from: data),
              let articles = decoded.articles else {
            throw GNewsError.invalidResponse
        }

        var uniqueHeadlines = Set<String>()
        var validItems: [AwarenessNewsItem] = []

        for art in articles {
            let cleanTitle = art.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanTitle.isEmpty else { continue }

            let normKey = cleanTitle.lowercased().filter { $0.isLetter || $0.isNumber }
            guard !uniqueHeadlines.contains(normKey) else { continue }
            uniqueHeadlines.insert(normKey)

            let pubDate = art.publishedAt.flatMap { isoFormatter.date(from: $0) }
            if let date = pubDate, date < cutoffDate {
                continue // Discard stale articles
            }

            let item = AwarenessNewsItem(
                title: cleanTitle,
                source: art.source?.name ?? "GNews",
                publishedAt: pubDate,
                url: art.url,
                snippet: art.description,
                category: "General"
            )
            validItems.append(item)
        }

        validItems.sort { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }

        if let newest = validItems.first?.publishedAt {
            let df = DateFormatter()
            df.dateStyle = .short
            df.timeStyle = .short
            NSLog("[NewsDataSource] GNews: %d fresh articles. Cutoff: %@, Newest: %@", validItems.count, df.string(from: cutoffDate), df.string(from: newest))
        }

        return Array(validItems.prefix(6))
    }
}

// MARK: - Market & Earnings Data Source (Finnhub + Public Quotes)

public final class MarketDataSource: AwarenessDataSource {
    public typealias Output = [AwarenessEarningsItem]
    public let sourceName: String = "Earnings & Markets"

    private let session: URLSession

    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5.0
        config.timeoutIntervalForResource = 6.0
        self.session = URLSession(configuration: config)
    }

    public func fetch() async throws -> (output: [AwarenessEarningsItem], freshness: SourceFreshness) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.autoupdatingCurrent

        let today = Date()
        let todayStr = formatter.string(from: today)

        let cal = Calendar.autoupdatingCurrent
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today) ?? today
        let tomorrowStr = formatter.string(from: tomorrow)

        // 1. If Finnhub API Key is configured in Keychain, use Finnhub Earnings Calendar
        if let finnhubKey = APIKeyManager.shared.getKey(for: "finnhub"), !finnhubKey.isEmpty {
            do {
                let items = try await fetchFinnhubEarnings(apiKey: finnhubKey, from: todayStr, to: tomorrowStr)
                if !items.isEmpty {
                    return (
                        items,
                        SourceFreshness(
                            sourceName: sourceName,
                            status: .delayed(minutes: 15),
                            detail: "Finnhub API (\(items.count) reports)"
                        )
                    )
                }
            } catch {
                NSLog("[MarketDataSource] Finnhub request failed: %@", error.localizedDescription)
            }
        }

        // 2. Fallback / Core Market Watch: Major watched benchmark symbols (AAPL, MSFT, GOOGL, NVDA, SPY)
        // Swift deterministically calculates the changePercent and passes facts only
        let watchedSymbols = ["AAPL", "NVDA", "MSFT", "GOOGL"]
        let quotes = await fetchQuotes(for: watchedSymbols)

        if quotes.isEmpty {
            return (
                [],
                SourceFreshness(
                    sourceName: sourceName,
                    status: .empty,
                    detail: "No active earnings or quotes found for today"
                )
            )
        }

        return (
            quotes,
            SourceFreshness(
                sourceName: sourceName,
                status: .delayed(minutes: 15),
                detail: "Market Watch (\(quotes.count) watched symbols, 15m delayed)"
            )
        )
    }

    private func fetchFinnhubEarnings(apiKey: String, from: String, to: String) async throws -> [AwarenessEarningsItem] {
        guard let url = URL(string: "https://finnhub.io/api/v1/calendar/earnings?from=\(from)&to=\(to)&token=\(apiKey)") else {
            return []
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "MarketDataSource", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "Finnhub error"])
        }

        struct FinnhubEarningsPayload: Decodable {
            struct EarningsEntry: Decodable {
                let date: String?
                let epsActual: Double?
                let epsEstimate: Double?
                let hour: String? // "bmo" (before market open), "amc" (after market close), "dmh"
                let quarter: Int?
                let revenueActual: Double?
                let revenueEstimate: Double?
                let symbol: String
                let year: Int?
            }
            let earningsCalendar: [EarningsEntry]?
        }

        let decoded = try JSONDecoder().decode(FinnhubEarningsPayload.self, from: data)
        guard let list = decoded.earningsCalendar, !list.isEmpty else { return [] }

        // Take top 6 reports
        return list.prefix(6).map { entry in
            let timingText: String
            switch entry.hour?.lowercased() {
            case "bmo":
                timingText = "Before Market Open (BMO)"
            case "amc":
                timingText = "After Market Close (AMC)"
            default:
                timingText = "Scheduled"
            }

            let isReported = entry.epsActual != nil || entry.revenueActual != nil

            return AwarenessEarningsItem(
                symbol: entry.symbol,
                companyName: nil,
                date: entry.date ?? from,
                timing: timingText,
                epsEstimate: entry.epsEstimate,
                epsActual: entry.epsActual,
                revenueEstimate: entry.revenueEstimate,
                revenueActual: entry.revenueActual,
                currentPrice: nil,
                changePercent: nil,
                isReported: isReported,
                isDelayed: true
            )
        }
    }

    private func fetchQuotes(for symbols: [String]) async -> [AwarenessEarningsItem] {
        let todayStr = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        return await withTaskGroup(of: AwarenessEarningsItem?.self) { group in
            for sym in symbols {
                group.addTask {
                    await self.fetchYahooQuote(symbol: sym, dateStr: todayStr)
                }
            }
            var results: [AwarenessEarningsItem] = []
            for await quote in group {
                if let q = quote {
                    results.append(q)
                }
            }
            return results
        }
    }

    private func fetchYahooQuote(symbol: String, dateStr: String) async -> AwarenessEarningsItem? {
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1d&range=1d") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 4.0

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }

            struct ChartResponse: Decodable {
                struct Chart: Decodable {
                    struct Result: Decodable {
                        struct Meta: Decodable {
                            let regularMarketPrice: Double?
                            let chartPreviousClose: Double?
                            let previousClose: Double?
                            let shortName: String?
                        }
                        let meta: Meta?
                    }
                    let result: [Result]?
                }
                let chart: Chart?
            }

            let decoded = try JSONDecoder().decode(ChartResponse.self, from: data)
            guard let meta = decoded.chart?.result?.first?.meta,
                  let currentPrice = meta.regularMarketPrice else {
                return nil
            }

            let prevClose = meta.chartPreviousClose ?? meta.previousClose ?? currentPrice
            // Swift performs calculation deterministically
            let changePercent: Double = prevClose > 0 ? ((currentPrice - prevClose) / prevClose) * 100.0 : 0.0

            return AwarenessEarningsItem(
                symbol: symbol,
                companyName: meta.shortName,
                date: dateStr,
                timing: "Trading Session",
                epsEstimate: nil,
                epsActual: nil,
                revenueEstimate: nil,
                revenueActual: nil,
                currentPrice: currentPrice,
                changePercent: changePercent,
                isReported: false,
                isDelayed: true
            )
        } catch {
            return nil
        }
    }
}

// MARK: - Apple Calendar Data Source (Native EventKit)

public final class CalendarDataSource: AwarenessDataSource {
    public typealias Output = [AwarenessCalendarItem]
    public let sourceName: String = "Apple Calendar"

    private let eventStore = EKEventStore()

    public init() {}

    public func fetch() async throws -> (output: [AwarenessCalendarItem], freshness: SourceFreshness) {
        let authorized = await checkAndRequestAuthorization()
        guard authorized else {
            return (
                [],
                SourceFreshness(
                    sourceName: sourceName,
                    status: .unauthorized,
                    detail: "Calendar permission not granted"
                )
            )
        }

        let cal = Calendar.autoupdatingCurrent
        let now = Date()
        let startOfDay = cal.startOfDay(for: now)
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) else {
            return ([], SourceFreshness(sourceName: sourceName, status: .empty, detail: "Could not calculate day range"))
        }

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let rawEvents = eventStore.events(matching: predicate)

        // Filter out canceled events and sort chronologically
        let validEvents = rawEvents
            .filter { $0.status != .canceled }
            .sorted { $0.startDate < $1.startDate }

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        timeFormatter.timeZone = TimeZone.autoupdatingCurrent

        // Privacy-Preserving normalization: ONLY title, times, calendar name. Strip notes, attendees, URL.
        let normalized: [AwarenessCalendarItem] = validEvents.map { ev in
            let timeStr: String
            if ev.isAllDay {
                timeStr = "All Day"
            } else {
                let startStr = timeFormatter.string(from: ev.startDate)
                let endStr = timeFormatter.string(from: ev.endDate)
                timeStr = "\(startStr) - \(endStr)"
            }

            return AwarenessCalendarItem(
                id: ev.eventIdentifier ?? UUID().uuidString,
                title: ev.title ?? "Scheduled Event",
                startDate: ev.startDate,
                endDate: ev.endDate,
                isAllDay: ev.isAllDay,
                calendarName: ev.calendar?.title,
                timeFormatted: timeStr
            )
        }

        return (
            normalized,
            SourceFreshness(
                sourceName: sourceName,
                status: .available,
                detail: "Local EventKit (\(normalized.count) events today)"
            )
        )
    }

    public func authorizationStatus() -> EKAuthorizationStatus {
        return EKEventStore.authorizationStatus(for: .event)
    }

    public func isAuthorized() -> Bool {
        let status = authorizationStatus()
        if #available(macOS 14.0, *) {
            if status == .fullAccess { return true }
        }
        return status == .authorized
    }

    public func checkAndRequestAuthorization() async -> Bool {
        if isAuthorized() { return true }
        let status = authorizationStatus()
        if status == .notDetermined {
            return await withCheckedContinuation { continuation in
                if #available(macOS 14.0, *) {
                    eventStore.requestFullAccessToEvents { granted, _ in
                        continuation.resume(returning: granted)
                    }
                } else {
                    eventStore.requestAccess(to: .event) { granted, _ in
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
        return false
    }
}
