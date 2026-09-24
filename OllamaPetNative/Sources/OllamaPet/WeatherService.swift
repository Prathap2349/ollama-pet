import Foundation

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
}

@MainActor
public class WeatherService: ObservableObject {
    public static let shared = WeatherService()

    @Published public var weather: WeatherInfo?
    @Published public var statusMessage: String = "No weather data"
    @Published public var isLoading: Bool = false

    private let session: URLSession

    private let weatherIcons: [Int: String] = [
        0: "☀️", 1: "🌤", 2: "⛅", 3: "☁️", 45: "🌫", 48: "🌫",
        51: "🌦", 53: "🌦", 55: "🌧", 61: "🌧", 63: "🌧", 65: "🌧",
        71: "🌨", 73: "🌨", 75: "❄️", 80: "🌦", 81: "🌧", 82: "⛈",
        95: "⛈", 96: "⛈", 99: "⛈"
    ]

    private let weatherDesc: [Int: String] = [
        0: "Clear sky", 1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
        45: "Foggy", 48: "Icy fog", 51: "Light drizzle", 53: "Drizzle", 55: "Heavy drizzle",
        61: "Slight rain", 63: "Moderate rain", 65: "Heavy rain",
        71: "Slight snow", 73: "Moderate snow", 75: "Heavy snow",
        80: "Showers", 81: "Heavy showers", 82: "Violent showers",
        95: "Thunderstorm", 96: "Thunderstorm+hail", 99: "Heavy thunderstorm"
    ]

    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 6.0
        config.timeoutIntervalForResource = 6.0
        self.session = URLSession(configuration: config)
    }

    public func fetchWeather(for city: String) async {
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        statusMessage = "⏳ Fetching location..."

        do {
            guard let encodedCity = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let geoURL = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encodedCity)&count=1&language=en&format=json") else {
                throw NSError(domain: "Weather", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid city name"])
            }

            var geoReq = URLRequest(url: geoURL)
            geoReq.timeoutInterval = 6.0
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
                throw NSError(domain: "Weather", code: 404, userInfo: [NSLocalizedDescriptionKey: "City not found"])
            }

            statusMessage = "⏳ Getting forecast..."
            let tz = loc.timezone ?? "auto"
            guard let encodedTz = tz.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let wxURL = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(loc.latitude)&longitude=\(loc.longitude)&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min&timezone=\(encodedTz)&forecast_days=1") else {
                throw NSError(domain: "Weather", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid forecast URL"])
            }

            var wxReq = URLRequest(url: wxURL)
            wxReq.timeoutInterval = 6.0
            let (wxData, wxResp) = try await session.data(for: wxReq)
            guard let wxHttp = wxResp as? HTTPURLResponse, wxHttp.statusCode == 200 else {
                throw NSError(domain: "Weather", code: 502, userInfo: [NSLocalizedDescriptionKey: "Weather service unavailable"])
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

            let countryStr = loc.country != nil ? ", \(loc.country!)" : ""
            let newWeather = WeatherInfo(
                cityName: "\(loc.name)\(countryStr)",
                description: desc,
                icon: icon,
                temp: Int(round(wx.current.temperature_2m)),
                feelsLike: Int(round(wx.current.apparent_temperature)),
                humidity: Int(round(wx.current.relative_humidity_2m)),
                windSpeed: Int(round(wx.current.wind_speed_10m)),
                highLow: "\(maxTemp)° / \(minTemp)°",
                lastUpdated: timeStr
            )

            self.weather = newWeather
            self.statusMessage = "✓ Updated \(timeStr)"
            self.isLoading = false
        } catch {
            self.isLoading = false
            self.statusMessage = "❌ \(error.localizedDescription)"
        }
    }
}
