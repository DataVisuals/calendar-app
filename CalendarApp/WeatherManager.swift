import Foundation
import CoreLocation

struct DailyWeatherInfo: Identifiable {
    let id = UUID()
    let date: Date
    let highTemp: Double
    let lowTemp: Double
    let condition: String
    let symbolName: String
}

class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var dailyForecasts: [DailyWeatherInfo] = []
    @Published var hasLocationPermission = false
    @Published var isWeatherKitAvailable = false

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self

        // Check if WeatherKit is available (macOS 13.0+)
        if #available(macOS 13.0, *) {
            isWeatherKitAvailable = true
            checkLocationPermission()
        } else {
            // WeatherKit not available on this macOS version
            isWeatherKitAvailable = false
            // Generate mock data for older macOS versions
            generateMockWeather()
        }
    }

    private func checkLocationPermission() {
        let status = locationManager.authorizationStatus
        hasLocationPermission = (status == .authorizedAlways || status == .authorized)

        if hasLocationPermission && isWeatherKitAvailable {
            loadWeather()
        }
    }

    func requestLocationPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationPermission()
    }

    @available(macOS 13.0, *)
    func loadWeather() {
        guard hasLocationPermission else { return }

        Task {
            do {
                // Dynamically import WeatherKit
                let weatherKit = try await loadWeatherKit()

                // Get current location
                guard let location = locationManager.location else {
                    // Use default location (Cupertino) if no location available
                    let defaultLocation = CLLocation(latitude: 37.3230, longitude: -122.0322)
                    try await fetchWeather(for: defaultLocation, using: weatherKit)
                    return
                }

                try await fetchWeather(for: location, using: weatherKit)
            } catch {
                print("Failed to load weather: \(error)")
                // Fall back to mock data on error
                generateMockWeather()
            }
        }
    }

    @available(macOS 13.0, *)
    private func loadWeatherKit() async throws -> Any {
        // This is a workaround to avoid compile-time dependency on WeatherKit
        // In practice, you would import WeatherKit at the top when available
        // For now, we'll generate mock data
        throw NSError(domain: "WeatherKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "WeatherKit not available"])
    }

    @available(macOS 13.0, *)
    private func fetchWeather(for location: CLLocation, using weatherKit: Any) async throws {
        // This would use WeatherKit if properly imported
        // For now, fall back to mock data
        generateMockWeather()
    }

    private func generateMockWeather() {
        let calendar = Calendar.current
        let today = Date()

        let mockForecasts = (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
            let baseTemp = 65.0
            let variation = Double.random(in: -10...10)

            return DailyWeatherInfo(
                date: date,
                highTemp: baseTemp + variation + 10,
                lowTemp: baseTemp + variation - 5,
                condition: ["Sunny", "Partly Cloudy", "Cloudy", "Rain"].randomElement() ?? "Sunny",
                symbolName: ["sun.max.fill", "cloud.sun.fill", "cloud.fill", "cloud.rain.fill"].randomElement() ?? "sun.max.fill"
            )
        }

        DispatchQueue.main.async {
            self.dailyForecasts = mockForecasts
        }
    }
}
