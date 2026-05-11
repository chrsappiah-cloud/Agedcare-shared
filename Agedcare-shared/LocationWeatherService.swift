import Foundation
import CoreLocation
import Combine

#if canImport(WeatherKit)
import WeatherKit
#endif

// MARK: - Weather snapshot (WeatherKit-agnostic for testability)
struct WeatherSnapshot {
    var locationName: String = ""
    var outdoorTemperature: Double?   // °C
    var feelsLike: Double?            // °C
    var humidity: Double?             // 0–1
    var conditionDescription: String = ""
    var conditionSymbol: String = "sun.max.fill"
    /// Estimated room temperature: outdoor temp shifted toward 22 °C (comfortable indoor baseline)
    var estimatedRoomTemperature: Double? {
        guard let t = outdoorTemperature else { return nil }
        return (t + 22.0) / 2.0
    }

    // MARK: - Formatting helpers (used by WeatherView + unit tests)
    func formattedOutdoorTemp(unit: UnitTemperature = .celsius) -> String {
        guard let t = outdoorTemperature else { return "--" }
        return formatted(t, unit: unit)
    }

    func formattedRoomTemp(unit: UnitTemperature = .celsius) -> String {
        guard let t = estimatedRoomTemperature else { return "--" }
        return formatted(t, unit: unit)
    }

    func formattedHumidity() -> String {
        guard let h = humidity else { return "--" }
        return "\(Int((h * 100).rounded()))%"
    }

    private func formatted(_ celsius: Double, unit: UnitTemperature) -> String {
        let meas = Measurement(value: celsius, unit: UnitTemperature.celsius).converted(to: unit)
        return String(format: "%.1f °%@", meas.value, unit == .celsius ? "C" : "F")
    }
}

// MARK: - Service
@MainActor
final class LocationWeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationWeatherService()

    @Published var snapshot = WeatherSnapshot()
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLoading = false
    @Published var error: String?

    private let manager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermissionAndStart() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            error = "Location access denied. Enable it in Settings to see weather."
        }
    }

    // MARK: CLLocationManagerDelegate
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            manager.stopUpdatingLocation()
            await self.fetchWeather(for: loc)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError err: Error) {
        Task { @MainActor in self.error = err.localizedDescription }
    }

    // MARK: - Weather fetch
    private func fetchWeather(for location: CLLocation) async {
        isLoading = true
        error = nil

        // Reverse-geocode for a friendly place name
        if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
            snapshot.locationName = [placemark.locality, placemark.administrativeArea]
                .compactMap { $0 }.joined(separator: ", ")
        }

#if canImport(WeatherKit)
        do {
            let weather = try await WeatherService.shared.weather(for: location)
            let current = weather.currentWeather
            snapshot.outdoorTemperature = current.temperature.converted(to: .celsius).value
            snapshot.feelsLike = current.apparentTemperature.converted(to: .celsius).value
            snapshot.humidity = current.humidity
            snapshot.conditionDescription = current.condition.description
            snapshot.conditionSymbol = current.symbolName
        } catch {
            self.error = "Weather unavailable: \(error.localizedDescription)"
        }
#else
        // Simulator / preview fallback
        snapshot.outdoorTemperature = 22.0
        snapshot.feelsLike = 21.0
        snapshot.humidity = 0.55
        snapshot.conditionDescription = "Partly Cloudy"
        snapshot.conditionSymbol = "cloud.sun.fill"
#endif
        isLoading = false
    }
}
