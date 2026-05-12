import Foundation
import CoreLocation
import Combine
import MapKit

#if canImport(WeatherKit)
import WeatherKit
#endif

// MARK: - Weather snapshot
struct WeatherSnapshot {
    var locationName: String = ""
    var outdoorTemperature: Double?
    var feelsLike: Double?
    var humidity: Double?
    var conditionDescription: String = ""
    var conditionSymbol: String = "sun.max.fill"
    var actualRoomTemperature: Double?
    var roomTemperatureSource: String = ""
    var coordinate: CLLocationCoordinate2D?
    var recentCoordinates: [CLLocationCoordinate2D] = []
    var currentSpeedMetersPerSecond: Double?
    var headingDegrees: Double?
    var totalDistanceMeters: Double = 0
    var horizontalAccuracyMeters: Double?
    var lastUpdated: Date?

    var estimatedRoomTemperature: Double? {
        guard let t = outdoorTemperature else { return nil }
        let baseline = feelsLike ?? 22.0
        return (t + baseline + 22.0) / 3.0
    }

    var roomTemperature: Double? {
        actualRoomTemperature ?? estimatedRoomTemperature
    }

    var hasActualRoomTemperature: Bool {
        actualRoomTemperature != nil
    }

    var mapRegion: MKCoordinateRegion? {
        guard let coordinate else { return nil }
        return MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
        )
    }

    func formattedOutdoorTemp(unit: UnitTemperature = .celsius) -> String {
        guard let t = outdoorTemperature else { return "--" }
        return formatted(t, unit: unit)
    }

    func formattedRoomTemp(unit: UnitTemperature = .celsius) -> String {
        guard let t = roomTemperature else { return "--" }
        return formatted(t, unit: unit)
    }

    func formattedHumidity() -> String {
        guard let h = humidity else { return "--" }
        return "\(Int((h * 100).rounded()))%"
    }

    func formattedCoordinates() -> String {
        guard let coordinate else { return "Location unavailable" }
        return String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }

    func formattedSpeed() -> String {
        guard let speed = currentSpeedMetersPerSecond, speed >= 0 else { return "--" }
        let kilometersPerHour = speed * 3.6
        return String(format: "%.1f km/h", kilometersPerHour)
    }

    func formattedDistance() -> String {
        guard totalDistanceMeters > 0 else { return "0 m" }
        if totalDistanceMeters >= 1_000 {
            return String(format: "%.2f km", totalDistanceMeters / 1_000)
        }
        return "\(Int(totalDistanceMeters.rounded())) m"
    }

    func movementStateDescription() -> String {
        if let speed = currentSpeedMetersPerSecond, speed >= 0.4 {
            return "Moving"
        }
        if totalDistanceMeters > 0 {
            return "Stationary"
        }
        return "Monitoring"
    }

    func roomTemperatureSourceDescription() -> String {
        if hasActualRoomTemperature {
            return roomTemperatureSource.isEmpty ? "Home sensor" : roomTemperatureSource
        }
        return "Estimated from local weather"
    }

    private func formatted(_ celsius: Double, unit: UnitTemperature) -> String {
        let measurement = Measurement(value: celsius, unit: UnitTemperature.celsius).converted(to: unit)
        return String(format: "%.1f °%@", measurement.value, unit == .celsius ? "C" : "F")
    }
}

@MainActor
final class LocationWeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationWeatherService()

    @Published var snapshot = WeatherSnapshot()
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLoading = false
    @Published var error: String?

    private let manager = CLLocationManager()
    private let roomTemperatureService = HomeRoomTemperatureService.shared
    private var lastLocation: CLLocation?
    private var lastWeatherFetchLocation: CLLocation?
    private var lastWeatherFetchDate: Date?
    private var cancellables: Set<AnyCancellable> = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 5
        manager.activityType = .fitness
        authorizationStatus = manager.authorizationStatus

        roomTemperatureService.$latestReading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reading in
                guard let self else { return }
                self.snapshot.actualRoomTemperature = reading?.temperatureCelsius
                self.snapshot.roomTemperatureSource = reading?.sourceName ?? ""
            }
            .store(in: &cancellables)
    }

    func requestPermissionAndStart() {
        roomTemperatureService.start()
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        default:
            error = "Location access denied. Enable it in Settings to map resident location and weather."
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    private func startLocationUpdates() {
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.startLocationUpdates()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            await self.process(location: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in
            guard newHeading.trueHeading >= 0 else { return }
            self.snapshot.headingDegrees = newHeading.trueHeading
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError err: Error) {
        Task { @MainActor in
            self.error = err.localizedDescription
        }
    }

    private func process(location: CLLocation) async {
        guard location.horizontalAccuracy >= 0 else { return }

        if let lastLocation {
            let distance = location.distance(from: lastLocation)
            if distance >= 1 {
                snapshot.totalDistanceMeters += distance
            }
        }

        snapshot.coordinate = location.coordinate
        snapshot.locationName = snapshot.formattedCoordinates()
        snapshot.currentSpeedMetersPerSecond = location.speed >= 0 ? location.speed : nil
        snapshot.horizontalAccuracyMeters = location.horizontalAccuracy
        snapshot.lastUpdated = Date()

        appendCoordinateIfNeeded(location.coordinate)
        lastLocation = location

        if shouldRefreshWeather(for: location) {
            await fetchWeather(for: location)
        }
    }

    private func appendCoordinateIfNeeded(_ coordinate: CLLocationCoordinate2D) {
        let shouldAppend: Bool
        if let lastCoordinate = snapshot.recentCoordinates.last {
            let previous = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let current = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            shouldAppend = current.distance(from: previous) >= 3
        } else {
            shouldAppend = true
        }

        guard shouldAppend else { return }
        snapshot.recentCoordinates.append(coordinate)
        snapshot.recentCoordinates = Array(snapshot.recentCoordinates.suffix(20))
    }

    private func shouldRefreshWeather(for location: CLLocation) -> Bool {
        guard let lastWeatherFetchDate, let lastWeatherFetchLocation else { return true }
        if Date().timeIntervalSince(lastWeatherFetchDate) > 600 {
            return true
        }
        return location.distance(from: lastWeatherFetchLocation) >= 100
    }

    private func fetchWeather(for location: CLLocation) async {
        isLoading = true
        error = nil

        #if canImport(WeatherKit)
        do {
            let weather = try await WeatherService.shared.weather(for: location)
            let current = weather.currentWeather
            snapshot.outdoorTemperature = current.temperature.converted(to: .celsius).value
            snapshot.feelsLike = current.apparentTemperature.converted(to: .celsius).value
            snapshot.humidity = current.humidity
            snapshot.conditionDescription = current.condition.description
            snapshot.conditionSymbol = current.symbolName
            lastWeatherFetchDate = Date()
            lastWeatherFetchLocation = location
        } catch {
            self.error = "Weather unavailable: \(error.localizedDescription)"
        }
        #else
        snapshot.outdoorTemperature = 22.0
        snapshot.feelsLike = 21.0
        snapshot.humidity = 0.55
        snapshot.conditionDescription = "Partly Cloudy"
        snapshot.conditionSymbol = "cloud.sun.fill"
        lastWeatherFetchDate = Date()
        lastWeatherFetchLocation = location
        #endif

        isLoading = false
    }
}
