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

    init(sourceTitle: String, categoryName: String? = nil, maxItems: Int = 5) {
        self.sourceTitle = sourceTitle
        self.categoryName = categoryName
        self.maxItems = maxItems
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
        rfc822.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        if let d = rfc822.date(from: trimmed) { return d }

        rfc822.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        if let d = rfc822.date(from: trimmed) { return d }

        let iso = ISO8601DateFormatter()
        return iso.date(from: trimmed)
    }
}

// MARK: - News Data Source (RSS + Optional GNews)

public final class NewsDataSource: AwarenessDataSource {
    public typealias Output = [AwarenessNewsItem]
    public let sourceName: String = "News"

    private let session: URLSession

    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 15.0
        self.session = URLSession(configuration: config)
    }

    public func fetch() async throws -> (output: [AwarenessNewsItem], freshness: SourceFreshness) {
        // Option B: If user has configured a GNews key in Keychain, we can use it
        if let gnewsKey = APIKeyManager.shared.getKey(for: "gnews"), !gnewsKey.isEmpty {
            do {
                let gnewsItems = try await fetchGNews(apiKey: gnewsKey)
                if !gnewsItems.isEmpty {
                    return (
                        gnewsItems,
                        SourceFreshness(sourceName: sourceName, status: .available, detail: "GNews API")
                    )
                }
            } catch {
                NSLog("[NewsDataSource] GNews failed, falling back to public RSS: %@", error.localizedDescription)
            }
        }

        // Option A (Default): Public RSS Feeds (No API key needed, zero-config, highly reliable)
        var allItems: [AwarenessNewsItem] = []

        // 1. General World Headlines (BBC World News RSS)
        let worldUrl = URL(string: "https://feeds.bbci.co.uk/news/world/rss.xml")!
        if let worldItems = await fetchRSS(url: worldUrl, source: "BBC News", category: "World", max: 5) {
            allItems.append(contentsOf: worldItems)
        } else {
            // Fallback general feed (NPR News)
            let nprUrl = URL(string: "https://feeds.npr.org/1001/rss.xml")!
            if let nprItems = await fetchRSS(url: nprUrl, source: "NPR", category: "General", max: 5) {
                allItems.append(contentsOf: nprItems)
            }
        }

        // 2. Technology & Business Headlines (BBC Tech RSS)
        let techUrl = URL(string: "https://feeds.bbci.co.uk/news/technology/rss.xml")!
        if let techItems = await fetchRSS(url: techUrl, source: "BBC Tech", category: "Technology", max: 3) {
            allItems.append(contentsOf: techItems)
        }

        if allItems.isEmpty {
            return (
                [],
                SourceFreshness(
                    sourceName: sourceName,
                    status: .error(message: "Could not reach news feeds"),
                    detail: "Network or feed unavailable"
                )
            )
        }

        return (
            allItems,
            SourceFreshness(
                sourceName: sourceName,
                status: .available,
                detail: "Public RSS (\(allItems.count) headlines)"
            )
        )
    }

    private func fetchRSS(url: URL, source: String, category: String?, max: Int) async -> [AwarenessNewsItem]? {
        var request = URLRequest(url: url)
        request.setValue("OllamaPetNative/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let parser = RSSXMLParserDelegate(sourceTitle: source, categoryName: category, maxItems: max)
            let items = parser.parse(data: data)
            return items.isEmpty ? nil : items
        } catch {
            return nil
        }
    }

    private func fetchGNews(apiKey: String) async throws -> [AwarenessNewsItem] {
        guard let url = URL(string: "https://gnews.io/api/v4/top-headlines?category=general&lang=en&max=5&apikey=\(apiKey)") else {
            return []
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "NewsDataSource", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "GNews error"])
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

        let decoded = try JSONDecoder().decode(GNewsResponse.self, from: data)
        guard let articles = decoded.articles else { return [] }

        let iso = ISO8601DateFormatter()
        return articles.prefix(5).map { art in
            AwarenessNewsItem(
                title: art.title,
                source: art.source?.name ?? "GNews",
                publishedAt: art.publishedAt.flatMap { iso.date(from: $0) },
                url: art.url,
                snippet: art.description,
                category: "General"
            )
        }
    }
}

// MARK: - Market & Earnings Data Source (Finnhub + Public Quotes)

public final class MarketDataSource: AwarenessDataSource {
    public typealias Output = [AwarenessEarningsItem]
    public let sourceName: String = "Earnings & Markets"

    private let session: URLSession

    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 15.0
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
        request.timeoutInterval = 10.0
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
        var results: [AwarenessEarningsItem] = []
        let todayStr = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)

        for sym in symbols {
            if let quote = await fetchYahooQuote(symbol: sym, dateStr: todayStr) {
                results.append(quote)
            }
        }
        return results
    }

    private func fetchYahooQuote(symbol: String, dateStr: String) async -> AwarenessEarningsItem? {
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1d&range=1d") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0

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
