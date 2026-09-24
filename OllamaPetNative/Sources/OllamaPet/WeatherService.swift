import Foundation
import SwiftUI

public struct WeatherInfo: Equatable {
    public let cityName: String
    public let description: String
    public let icon: String
    public let temp: Int
    public let feelsLike: Int
    public let humidity: Int
    public let windSpeed: Int
    public let highLow: String
    public let lastUpdated: String
    public let conditionCode: Int
    public let atmosphere: WeatherAtmosphere
}

@MainActor
public class WeatherService: ObservableObject {
    public static let shared = WeatherService()

    @Published public var savedLocations: [SavedWeatherLocation] = []
    @Published public var activeLocationId: UUID? = nil
    @Published public var weather: WeatherInfo?
    @Published public var activeAtmosphere: WeatherAtmosphere = .clearDay
    @Published public var statusMessage: String = "No weather data"
    @Published public var isLoading: Bool = false

    private let session: URLSession

    public let weatherIcons: [Int: String] = [
        0: "☀️", 1: "🌤", 2: "⛅", 3: "☁️", 45: "🌫", 48: "🌫",
        51: "🌦", 53: "🌦", 55: "🌧", 61: "🌧", 63: "🌧", 65: "🌧",
        71: "🌨", 73: "🌨", 75: "❄️", 80: "🌦", 81: "🌧", 82: "⛈",
        95: "⛈", 96: "⛈", 99: "⛈"
    ]

    public let weatherDesc: [Int: String] = [
        0: "Clear sky", 1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
        45: "Foggy", 48: "Icy fog", 51: "Light drizzle", 53: "Drizzle", 55: "Heavy drizzle",
        61: "Slight rain", 63: "Moderate rain", 65: "Heavy rain",
        71: "Slight snow", 73: "Moderate snow", 75: "Heavy snow",
        80: "Showers", 81: "Heavy showers", 82: "Violent showers",
        95: "Thunderstorm", 96: "Thunderstorm+hail", 99: "Heavy thunderstorm"
    ]

    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8.0
        config.timeoutIntervalForResource = 12.0
        self.session = URLSession(configuration: config)

        loadPersistedLocations()
    }

    // MARK: - Persistence & Vault Management

    public func loadPersistedLocations() {
        let data = DataManager.shared.savedData
        self.savedLocations = data.weatherLocations
        self.activeLocationId = data.activeWeatherLocationId

        if savedLocations.isEmpty {
            // Seed initial default location if clean install
            let defaultLoc = SavedWeatherLocation(
                name: "San Francisco",
                country: "United States",
                latitude: 37.7749,
                longitude: -122.4194,
                timezone: "America/Los_Angeles"
            )
            savedLocations.append(defaultLoc)
            activeLocationId = defaultLoc.id
            persistLocations()
        } else if activeLocationId == nil || !savedLocations.contains(where: { $0.id == activeLocationId }) {
            activeLocationId = savedLocations.first?.id
            persistLocations()
        }

        if let activeLoc = activeLocation {
            Task {
                await fetchWeather(for: activeLoc)
            }
        }
    }

    public var activeLocation: SavedWeatherLocation? {
        savedLocations.first(where: { $0.id == activeLocationId })
    }

    public func persistLocations() {
        DataManager.shared.savedData.weatherLocations = savedLocations
        DataManager.shared.savedData.activeWeatherLocationId = activeLocationId
        DataManager.shared.saveData()
    }

    public func selectLocation(id: UUID) {
        guard activeLocationId != id else { return }
        activeLocationId = id
        persistLocations()

        if let loc = activeLocation {
            Task {
                await fetchWeather(for: loc)
            }
        }
    }

    public func removeLocation(id: UUID) {
        savedLocations.removeAll { $0.id == id }
        if activeLocationId == id {
            activeLocationId = savedLocations.first?.id
        }
        persistLocations()

        if let activeLoc = activeLocation {
            Task {
                await fetchWeather(for: activeLoc)
            }
        } else {
            weather = nil
            statusMessage = "Add a city to view climate"
        }
    }

    // MARK: - City Search & Weather Fetch

    public func addLocation(cityName: String) async throws {
        let trimmed = cityName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        statusMessage = "🔍 Searching for \(trimmed)..."
        defer { isLoading = false }

        guard let encodedCity = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let geoURL = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encodedCity)&count=1&language=en&format=json") else {
            throw NSError(domain: "Weather", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid city name"])
        }

        var geoReq = URLRequest(url: geoURL)
        geoReq.timeoutInterval = 8.0
        let (geoData, geoResp) = try await session.data(for: geoReq)
        guard let geoHttp = geoResp as? HTTPURLResponse, geoHttp.statusCode == 200 else {
            throw NSError(domain: "Weather", code: 502, userInfo: [NSLocalizedDescriptionKey: "Geocoding service unavailable"])
        }

        struct GeoResponse: Decodable {
            struct Result: Decodable {
                let latitude: Double
                let longitude: Double
                let name: String
                let country: String?
                let timezone: String?
            }
            let results: [Result]?
        }

        let geoResult = try JSONDecoder().decode(GeoResponse.self, from: geoData)
        guard let loc = geoResult.results?.first else {
            throw NSError(domain: "Weather", code: 404, userInfo: [NSLocalizedDescriptionKey: "City '\(trimmed)' not found"])
        }

        var newLocation = SavedWeatherLocation(
            name: loc.name,
            country: loc.country,
            latitude: loc.latitude,
            longitude: loc.longitude,
            timezone: loc.timezone ?? "auto"
        )

        // Don't add duplicate names
        if let existing = savedLocations.first(where: { $0.name.lowercased() == newLocation.name.lowercased() }) {
            selectLocation(id: existing.id)
            return
        }

        // Fetch immediate weather for this location
        if let wxData = await fetchAtmosphereForCoordinates(lat: newLocation.latitude, lon: newLocation.longitude, tz: newLocation.timezone ?? "auto") {
            newLocation.lastTemp = wxData.temp
            newLocation.lastConditionCode = wxData.code
            newLocation.lastUpdated = wxData.timeStr
        }

        savedLocations.append(newLocation)
        activeLocationId = newLocation.id
        persistLocations()

        if let activeLoc = activeLocation {
            await fetchWeather(for: activeLoc)
        }
    }

    public func fetchWeather(for location: SavedWeatherLocation) async {
        isLoading = true
        statusMessage = "⏳ Updating climate for \(location.name)..."
        defer { isLoading = false }

        let tz = location.timezone ?? "auto"
        guard let encodedTz = tz.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let wxURL = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(location.latitude)&longitude=\(location.longitude)&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min&timezone=\(encodedTz)&forecast_days=1") else {
            statusMessage = "Invalid forecast URL"
            return
        }

        do {
            var wxReq = URLRequest(url: wxURL)
            wxReq.timeoutInterval = 8.0
            let (wxData, wxResp) = try await session.data(for: wxReq)
            guard let wxHttp = wxResp as? HTTPURLResponse, wxHttp.statusCode == 200 else {
                statusMessage = "Forecast service unavailable"
                return
            }

            struct WeatherResponse: Decodable {
                struct Current: Decodable {
                    let temperature_2m: Double
                    let relative_humidity_2m: Double
                    let apparent_temperature: Double
                    let weather_code: Int
                    let wind_speed_10m: Double
                }
                struct Daily: Decodable {
                    let temperature_2m_max: [Double]
                    let temperature_2m_min: [Double]
                }
                let current: Current
                let daily: Daily
            }

            let wx = try JSONDecoder().decode(WeatherResponse.self, from: wxData)
            let icon = weatherIcons[wx.current.weather_code] ?? "🌡"
            let desc = weatherDesc[wx.current.weather_code] ?? "Unknown"
            let timeStr = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
            let maxTemp = Int(round(wx.daily.temperature_2m_max.first ?? wx.current.temperature_2m))
            let minTemp = Int(round(wx.daily.temperature_2m_min.first ?? wx.current.temperature_2m))

            let atmosphere = computeAtmosphere(code: wx.current.weather_code, timezone: location.timezone)

            self.activeAtmosphere = atmosphere
            self.weather = WeatherInfo(
                cityName: "\(location.name)\(location.country != nil ? ", \(location.country!)" : "")",
                description: desc,
                icon: icon,
                temp: Int(round(wx.current.temperature_2m)),
                feelsLike: Int(round(wx.current.apparent_temperature)),
                humidity: Int(round(wx.current.relative_humidity_2m)),
                windSpeed: Int(round(wx.current.wind_speed_10m)),
                highLow: "H: \(maxTemp)°  L: \(minTemp)°",
                lastUpdated: timeStr,
                conditionCode: wx.current.weather_code,
                atmosphere: atmosphere
            )

            // Update in saved locations list
            if let index = savedLocations.firstIndex(where: { $0.id == location.id }) {
                savedLocations[index].lastTemp = Int(round(wx.current.temperature_2m))
                savedLocations[index].lastConditionCode = wx.current.weather_code
                savedLocations[index].lastUpdated = timeStr
                persistLocations()
            }

            self.statusMessage = "Updated \(timeStr)"
        } catch {
            self.statusMessage = "Offline / Connection Error"
        }
    }

    private func fetchAtmosphereForCoordinates(lat: Double, lon: Double, tz: String) async -> (temp: Int, code: Int, timeStr: String)? {
        guard let encodedTz = tz.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let wxURL = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weather_code&timezone=\(encodedTz)&forecast_days=1") else {
            return nil
        }
        do {
            let (data, resp) = try await session.data(for: URLRequest(url: wxURL))
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            struct QuickResponse: Decodable {
                struct Current: Decodable {
                    let temperature_2m: Double
                    let weather_code: Int
                }
                let current: Current
            }
            let dec = try JSONDecoder().decode(QuickResponse.self, from: data)
            let timeStr = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
            return (Int(round(dec.current.temperature_2m)), dec.current.weather_code, timeStr)
        } catch {
            return nil
        }
    }

    private func computeAtmosphere(code: Int, timezone: String?) -> WeatherAtmosphere {
        // Hour of day in location timezone
        var hour = Calendar.current.component(.hour, from: Date())
        if let tzStr = timezone, let tz = TimeZone(identifier: tzStr) {
            var cal = Calendar.current
            cal.timeZone = tz
            hour = cal.component(.hour, from: Date())
        }

        let isNight = hour < 6 || hour >= 20
        let isGoldenHour = (hour >= 17 && hour < 20) || (hour >= 6 && hour < 8)

        switch code {
        case 95, 96, 99:
            return .thunderstorm
        case 71, 73, 75, 77, 85, 86:
            return .snow
        case 51, 53, 55, 61, 63, 65, 80, 81, 82:
            return .rain
        case 45, 48:
            return .fog
        default:
            if isNight {
                return .nightClear
            } else if isGoldenHour {
                return .goldenHour
            } else {
                return .clearDay
            }
        }
    }
}
