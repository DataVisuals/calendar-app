import Foundation
import WeatherKit
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

    private let weatherService = WeatherService.shared
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        checkLocationPermission()
    }

    private func checkLocationPermission() {
        let status = locationManager.authorizationStatus
        hasLocationPermission = (status == .authorizedAlways || status == .authorized)

        if hasLocationPermission {
            loadWeather()
        }
    }

    func requestLocationPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationPermission()
    }

    func loadWeather() {
        guard hasLocationPermission else { return }

        Task {
            do {
                // Get current location
                guard let location = locationManager.location else {
                    // Use default location (Cupertino) if no location available
                    let defaultLocation = CLLocation(latitude: 37.3230, longitude: -122.0322)
                    try await fetchWeather(for: defaultLocation)
                    return
                }

                try await fetchWeather(for: location)
            } catch {
                print("Failed to load weather: \(error)")
            }
        }
    }

    private func fetchWeather(for location: CLLocation) async throws {
        let weather = try await weatherService.weather(for: location)

        let forecasts = weather.dailyForecast.forecast.prefix(7).map { day in
            DailyWeatherInfo(
                date: day.date,
                highTemp: day.highTemperature.value,
                lowTemp: day.lowTemperature.value,
                condition: day.condition.description,
                symbolName: day.symbolName
            )
        }

        await MainActor.run {
            self.dailyForecasts = forecasts
        }
    }
}
