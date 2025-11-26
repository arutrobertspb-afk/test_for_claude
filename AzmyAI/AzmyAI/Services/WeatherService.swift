//
//  WeatherService.swift
//  AzmyAI
//
//  Fetches weather data using Open-Meteo API (free, no API key required)
//

import Foundation
import SwiftUI

// MARK: - Weather Data

struct WeatherData: Equatable {
    let temperature: Double
    let temperatureUnit: String
    let condition: WeatherCondition
    let humidity: Int
    let windSpeed: Double
    let feelsLike: Double
    let isDay: Bool
    let lastUpdated: Date

    var temperatureString: String {
        let sign = temperature > 0 ? "+" : ""
        return "\(sign)\(Int(temperature))°\(temperatureUnit)"
    }

    var icon: String {
        condition.icon(isDay: isDay)
    }

    var iconColor: Color {
        condition.color(isDay: isDay)
    }

    static let placeholder = WeatherData(
        temperature: 21,
        temperatureUnit: "C",
        condition: .clear,
        humidity: 65,
        windSpeed: 12,
        feelsLike: 22,
        isDay: true,
        lastUpdated: Date()
    )
}

// MARK: - Weather Condition

enum WeatherCondition: String {
    case clear
    case partlyCloudy
    case cloudy
    case foggy
    case drizzle
    case rain
    case heavyRain
    case snow
    case thunderstorm
    case unknown

    func icon(isDay: Bool) -> String {
        switch self {
        case .clear:
            return isDay ? "sun.max.fill" : "moon.fill"
        case .partlyCloudy:
            return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case .cloudy:
            return "cloud.fill"
        case .foggy:
            return "cloud.fog.fill"
        case .drizzle:
            return "cloud.drizzle.fill"
        case .rain:
            return "cloud.rain.fill"
        case .heavyRain:
            return "cloud.heavyrain.fill"
        case .snow:
            return "cloud.snow.fill"
        case .thunderstorm:
            return "cloud.bolt.rain.fill"
        case .unknown:
            return "questionmark.circle"
        }
    }

    func color(isDay: Bool) -> Color {
        switch self {
        case .clear:
            return isDay ? .yellow : .purple
        case .partlyCloudy:
            return isDay ? .orange : .indigo
        case .cloudy:
            return .gray
        case .foggy:
            return .gray.opacity(0.7)
        case .drizzle, .rain:
            return .blue
        case .heavyRain:
            return .blue.opacity(0.8)
        case .snow:
            return .cyan
        case .thunderstorm:
            return .purple
        case .unknown:
            return .gray
        }
    }

    static func fromWMOCode(_ code: Int) -> WeatherCondition {
        switch code {
        case 0:
            return .clear
        case 1, 2:
            return .partlyCloudy
        case 3:
            return .cloudy
        case 45, 48:
            return .foggy
        case 51, 53, 55, 56, 57:
            return .drizzle
        case 61, 63, 66, 67, 80, 81:
            return .rain
        case 65, 82:
            return .heavyRain
        case 71, 73, 75, 77, 85, 86:
            return .snow
        case 95, 96, 99:
            return .thunderstorm
        default:
            return .unknown
        }
    }
}

// MARK: - Open-Meteo API Response

private struct OpenMeteoResponse: Codable {
    let current: CurrentWeather

    struct CurrentWeather: Codable {
        let temperature2m: Double
        let relativeHumidity2m: Int
        let apparentTemperature: Double
        let isDay: Int
        let weatherCode: Int
        let windSpeed10m: Double

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case relativeHumidity2m = "relative_humidity_2m"
            case apparentTemperature = "apparent_temperature"
            case isDay = "is_day"
            case weatherCode = "weather_code"
            case windSpeed10m = "wind_speed_10m"
        }
    }
}

// MARK: - Weather Service

@MainActor
class WeatherService: ObservableObject {
    static let shared = WeatherService()

    @Published var currentWeather: WeatherData?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let baseURL = "https://api.open-meteo.com/v1/forecast"

    // Cache weather for 10 minutes
    private var lastFetchTime: Date?
    private var cachedLatitude: Double?
    private var cachedLongitude: Double?
    private let cacheTimeout: TimeInterval = 600 // 10 minutes

    // MARK: - Fetch Weather

    func fetchWeather(latitude: Double, longitude: Double, forceRefresh: Bool = false) async -> WeatherData? {
        // Check cache
        if !forceRefresh,
           let cached = currentWeather,
           let lastFetch = lastFetchTime,
           cachedLatitude == latitude,
           cachedLongitude == longitude,
           Date().timeIntervalSince(lastFetch) < cacheTimeout {
            return cached
        }

        isLoading = true
        errorMessage = nil

        // Build URL
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m"),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        guard let url = components.url else {
            errorMessage = "Invalid URL"
            isLoading = false
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                errorMessage = "Weather service unavailable"
                isLoading = false
                return nil
            }

            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            let current = decoded.current

            let weatherData = WeatherData(
                temperature: current.temperature2m,
                temperatureUnit: "C",
                condition: WeatherCondition.fromWMOCode(current.weatherCode),
                humidity: current.relativeHumidity2m,
                windSpeed: current.windSpeed10m,
                feelsLike: current.apparentTemperature,
                isDay: current.isDay == 1,
                lastUpdated: Date()
            )

            // Update cache
            currentWeather = weatherData
            lastFetchTime = Date()
            cachedLatitude = latitude
            cachedLongitude = longitude

            isLoading = false
            return weatherData

        } catch {
            print("[Weather] Error: \(error)")
            errorMessage = error.localizedDescription
            isLoading = false
            return nil
        }
    }

    // MARK: - Fetch with Location Service

    func fetchWeatherForCurrentLocation() async -> WeatherData? {
        let locationService = LocationService.shared

        // Get current location
        guard let location = await locationService.getCurrentLocation() else {
            // Return placeholder if no location
            return WeatherData.placeholder
        }

        return await fetchWeather(latitude: location.latitude, longitude: location.longitude)
    }

    // MARK: - Refresh

    func refresh() {
        Task {
            _ = await fetchWeatherForCurrentLocation()
        }
    }
}
