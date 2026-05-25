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
    var locationLastUpdated: Date?
    var weatherLastUpdated: Date?
    var roomTemperatureLastUpdated: Date?
    var roomTemperatureStatusMessage: String = ""
    var lastUpdated: Date?
    var weatherSourceName: String = ""
    var locationSourceName: String = ""

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

    func roomTemperatureSystemDescription() -> String {
        if hasActualRoomTemperature {
            return "\(roomTemperatureSourceDescription()) • live HomeKit data"
        }
        if !roomTemperatureStatusMessage.isEmpty {
            return roomTemperatureStatusMessage
        }
        return roomTemperatureSourceDescription()
    }

    func liveStatusSummary(now: Date = Date()) -> String {
        var parts = [
            freshnessLabel("Location", at: locationLastUpdated, now: now, liveThreshold: 45),
            freshnessLabel("Weather", at: weatherLastUpdated, now: now, liveThreshold: 120),
        ]
        if hasActualRoomTemperature {
            parts.append(freshnessLabel("Room sensor", at: roomTemperatureLastUpdated, now: now, liveThreshold: 90))
        } else {
            parts.append("Room temp estimated")
        }
        return parts.joined(separator: " • ")
    }

    func weatherSourceDescription() -> String {
        if !weatherSourceName.isEmpty {
            return weatherSourceName
        }
        #if canImport(WeatherKit)
        return "WeatherKit"
        #else
        return "Local weather fallback"
        #endif
    }

    func locationSourceDescription() -> String {
        if !locationSourceName.isEmpty {
            return locationSourceName
        }
        return "MapKit reverse geocode"
    }

    func backendMetrics() -> [(metric: String, value: Double)] {
        var metrics: [(metric: String, value: Double)] = []

        if let outdoorTemperature {
            metrics.append(("outdoor_temperature", outdoorTemperature))
        }
        if let roomTemperature {
            metrics.append(("room_temperature", roomTemperature))
        }
        if let humidity {
            metrics.append(("humidity_percent", humidity * 100))
        }
        if let currentSpeedMetersPerSecond, currentSpeedMetersPerSecond >= 0 {
            metrics.append(("movement_speed_mps", currentSpeedMetersPerSecond))
        }
        if let headingDegrees, headingDegrees >= 0 {
            metrics.append(("heading_degrees", headingDegrees))
        }
        if totalDistanceMeters > 0 {
            metrics.append(("distance_meters", totalDistanceMeters))
        }
        if let coordinate {
            metrics.append(("latitude", coordinate.latitude))
            metrics.append(("longitude", coordinate.longitude))
        }

        return metrics
    }

    func backendSyncSignature() -> String {
        backendMetrics()
            .map { metric, value in
                "\(metric)=\(String(format: "%.5f", value))"
            }
            .joined(separator: "|")
    }

    private func formatted(_ celsius: Double, unit: UnitTemperature) -> String {
        let measurement = Measurement(value: celsius, unit: UnitTemperature.celsius).converted(to: unit)
        return String(format: "%.1f °%@", measurement.value, unit == .celsius ? "C" : "F")
    }

    private func freshnessLabel(_ label: String, at date: Date?, now: Date, liveThreshold: TimeInterval) -> String {
        guard let date else { return "\(label) pending" }
        let age = max(0, Int(now.timeIntervalSince(date)))
        let relative: String
        if age < 60 {
            relative = "\(age)s ago"
        } else if age < 3600 {
            relative = "\(max(1, age / 60))m ago"
        } else {
            relative = "\(max(1, age / 3600))h ago"
        }
        if TimeInterval(age) <= liveThreshold {
            return "\(label) live (\(relative))"
        }
        return "\(label) \(relative)"
    }
}

@MainActor
final class LocationWeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    struct ResolvedWeatherReading {
        let outdoorTemperature: Double
        let feelsLike: Double?
        let humidity: Double?
        let conditionDescription: String
        let conditionSymbol: String
        let sourceName: String
    }

    private struct OpenMeteoForecastResponse: Decodable {
        struct Current: Decodable {
            let temperature2m: Double?
            let relativeHumidity2m: Double?
            let apparentTemperature: Double?
            let weatherCode: Int?
        }

        let current: Current?
    }

    private struct OpenStreetMapReverseResponse: Decodable {
        struct Address: Decodable {
            let city: String?
            let town: String?
            let village: String?
            let suburb: String?
            let municipality: String?
            let state: String?
            let country: String?
        }

        let name: String?
        let address: Address?
    }

    enum BackendSyncState: Equatable {
        case idle
        case syncing
        case synced(Date)
        case failed(String)
    }

    static let shared = LocationWeatherService()

    @Published var snapshot = WeatherSnapshot()
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLoading = false
    @Published var error: String?
    @Published private(set) var backendSyncState: BackendSyncState = .idle

    private let manager = CLLocationManager()
    private let roomTemperatureService = HomeRoomTemperatureService.shared
    private let weatherRefreshInterval: TimeInterval = 60
    private let weatherRefreshDistanceMeters: CLLocationDistance = 25
    private let geocodeRefreshInterval: TimeInterval = 180
    private let geocodeRefreshDistanceMeters: CLLocationDistance = 25
    private let locationRefreshInterval: TimeInterval = 30
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private var lastLocation: CLLocation?
    private var lastWeatherFetchLocation: CLLocation?
    private var lastWeatherFetchDate: Date?
    private var lastGeocodedLocation: CLLocation?
    private var lastGeocodeDate: Date?
    private var refreshTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    override init() {
        self.session = .shared
        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 5
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = manager.authorizationStatus

        roomTemperatureService.$latestReading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reading in
                guard let self else { return }
                self.snapshot.actualRoomTemperature = reading?.temperatureCelsius
                self.snapshot.roomTemperatureSource = reading?.sourceName ?? ""
                self.snapshot.roomTemperatureLastUpdated = reading?.updatedAt
                if reading != nil {
                    self.snapshot.roomTemperatureStatusMessage = ""
                }
                if let updatedAt = reading?.updatedAt {
                    self.snapshot.lastUpdated = updatedAt
                }
            }
            .store(in: &cancellables)

        roomTemperatureService.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                guard let self else { return }
                self.snapshot.roomTemperatureStatusMessage = message ?? ""
            }
            .store(in: &cancellables)
    }

    func requestPermissionAndStart() {
        error = nil
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
        refreshTimer?.invalidate()
        refreshTimer = nil
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        roomTemperatureService.stop()
    }

    func refreshNow() {
        roomTemperatureService.refreshNow()
        guard manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse else { return }
        if let location = manager.location {
            Task { @MainActor in
                await self.process(location: location)
            }
        } else {
            manager.requestLocation()
        }
    }

    private func startLocationUpdates() {
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
        manager.requestLocation()
        startRefreshTimerIfNeeded()
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
            self.error = Self.userVisibleLocationError(err)
        }
    }

    func markBackendSyncStarted() {
        backendSyncState = .syncing
    }

    func markBackendSyncSucceeded(at timestamp: Date) {
        backendSyncState = .synced(timestamp)
    }

    func markBackendSyncFailed(_ message: String) {
        backendSyncState = .failed(message)
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
        let updatedAt = Date()
        snapshot.locationLastUpdated = updatedAt
        snapshot.lastUpdated = updatedAt

        appendCoordinateIfNeeded(location.coordinate)
        await reverseGeocodeIfNeeded(for: location)
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
        if Date().timeIntervalSince(lastWeatherFetchDate) > weatherRefreshInterval {
            return true
        }
        return location.distance(from: lastWeatherFetchLocation) >= weatherRefreshDistanceMeters
    }

    private func reverseGeocodeIfNeeded(for location: CLLocation) async {
        guard shouldRefreshGeocode(for: location) else { return }
        do {
            let mapItems = try await reverseGeocode(location)
            if let mapItem = mapItems.first {
                snapshot.locationName = formattedLocationName(from: mapItem)
                snapshot.locationSourceName = "MapKit reverse geocode"
            } else {
                snapshot.locationName = snapshot.formattedCoordinates()
                snapshot.locationSourceName = "Map coordinates only"
            }
            lastGeocodedLocation = location
            lastGeocodeDate = Date()
        } catch {
            do {
                let openLocation = try await reverseGeocodeWithOpenStreetMap(location)
                snapshot.locationName = formattedLocationName(from: openLocation)
                snapshot.locationSourceName = "OpenStreetMap reverse geocode backup"
                lastGeocodedLocation = location
                lastGeocodeDate = Date()
            } catch {
                if snapshot.locationName.isEmpty {
                    snapshot.locationName = snapshot.formattedCoordinates()
                }
                snapshot.locationSourceName = "Map coordinates only"
            }
        }
    }

    private func shouldRefreshGeocode(for location: CLLocation) -> Bool {
        guard let lastGeocodeDate, let lastGeocodedLocation else { return true }
        if snapshot.locationName.isEmpty {
            return true
        }
        if Date().timeIntervalSince(lastGeocodeDate) > geocodeRefreshInterval {
            return true
        }
        return location.distance(from: lastGeocodedLocation) >= geocodeRefreshDistanceMeters
    }

    private func reverseGeocode(_ location: CLLocation) async throws -> [MKMapItem] {
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return []
        }
        return try await request.mapItems
    }

    private func reverseGeocodeWithOpenStreetMap(_ location: CLLocation) async throws -> OpenStreetMapReverseResponse {
        var components = URLComponents(string: "https://nominatim.openstreetmap.org/reverse")
        components?.queryItems = [
            URLQueryItem(name: "format", value: "jsonv2"),
            URLQueryItem(name: "lat", value: String(location.coordinate.latitude)),
            URLQueryItem(name: "lon", value: String(location.coordinate.longitude)),
            URLQueryItem(name: "zoom", value: "16"),
            URLQueryItem(name: "addressdetails", value: "1"),
        ]
        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("Agedcare-shared/1.0 (\(WCSMarketingConfig.supportEmail))", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try jsonDecoder.decode(OpenStreetMapReverseResponse.self, from: data)
    }

    private func formattedLocationName(from mapItem: MKMapItem) -> String {
        let address = mapItem.addressRepresentations
        let candidates: [String?] = [
            mapItem.name,
            address?.cityName,
            address?.cityWithContext,
            address?.regionName,
        ]
        var parts = [String]()
        for candidate in candidates {
            guard let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { continue }
            parts.append(value)
        }

        if parts.isEmpty {
            return snapshot.formattedCoordinates()
        }

        var uniqueParts = [String]()
        for part in parts where !uniqueParts.contains(part) {
            uniqueParts.append(part)
        }
        return uniqueParts.prefix(2).joined(separator: ", ")
    }

    private func formattedLocationName(from response: OpenStreetMapReverseResponse) -> String {
        let candidates: [String?] = [
            response.name,
            response.address?.suburb,
            response.address?.city,
            response.address?.town,
            response.address?.village,
            response.address?.municipality,
            response.address?.state,
            response.address?.country,
        ]

        var parts = [String]()
        for candidate in candidates {
            guard let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { continue }
            parts.append(value)
        }

        if parts.isEmpty {
            return snapshot.formattedCoordinates()
        }

        var uniqueParts = [String]()
        for part in parts where !uniqueParts.contains(part) {
            uniqueParts.append(part)
        }
        return uniqueParts.prefix(2).joined(separator: ", ")
    }

    private func fetchWeather(for location: CLLocation) async {
        isLoading = true
        error = nil

        do {
            let reading = try await resolveWeather(for: location)
            applyWeather(reading, for: location)
        } catch {
            self.error = "Weather unavailable right now. Showing the latest available values."
        }

        isLoading = false
    }

    private func resolveWeather(for location: CLLocation) async throws -> ResolvedWeatherReading {
        #if canImport(WeatherKit)
        do {
            return try await fetchWeatherKitReading(for: location)
        } catch {
            return try await fetchOpenMeteoReading(for: location)
        }
        #else
        return try await fetchOpenMeteoReading(for: location)
        #endif
    }

    #if canImport(WeatherKit)
    private func fetchWeatherKitReading(for location: CLLocation) async throws -> ResolvedWeatherReading {
        let weather = try await WeatherService.shared.weather(for: location)
        let current = weather.currentWeather
        return ResolvedWeatherReading(
            outdoorTemperature: current.temperature.converted(to: .celsius).value,
            feelsLike: current.apparentTemperature.converted(to: .celsius).value,
            humidity: current.humidity,
            conditionDescription: current.condition.description,
            conditionSymbol: current.symbolName,
            sourceName: "WeatherKit live"
        )
    }
    #endif

    private func fetchOpenMeteoReading(for location: CLLocation) async throws -> ResolvedWeatherReading {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(location.coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,weather_code"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "1"),
        ]
        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let forecast = try jsonDecoder.decode(OpenMeteoForecastResponse.self, from: data)
        guard let current = forecast.current,
              let outdoorTemperature = current.temperature2m else {
            throw URLError(.cannotParseResponse)
        }

        let condition = Self.openMeteoCondition(for: current.weatherCode ?? 0)
        return ResolvedWeatherReading(
            outdoorTemperature: outdoorTemperature,
            feelsLike: current.apparentTemperature,
            humidity: current.relativeHumidity2m.map { $0 / 100.0 },
            conditionDescription: condition.description,
            conditionSymbol: condition.symbolName,
            sourceName: "Open-Meteo meteorological backup"
        )
    }

    private func applyWeather(_ reading: ResolvedWeatherReading, for location: CLLocation) {
        snapshot.outdoorTemperature = reading.outdoorTemperature
        snapshot.feelsLike = reading.feelsLike
        snapshot.humidity = reading.humidity
        snapshot.conditionDescription = reading.conditionDescription
        snapshot.conditionSymbol = reading.conditionSymbol
        snapshot.weatherSourceName = reading.sourceName
        let updatedAt = Date()
        snapshot.weatherLastUpdated = updatedAt
        snapshot.lastUpdated = updatedAt
        lastWeatherFetchDate = updatedAt
        lastWeatherFetchLocation = location
    }

    nonisolated static func openMeteoCondition(for code: Int) -> (description: String, symbolName: String) {
        switch code {
        case 0:
            return ("Clear", "sun.max.fill")
        case 1, 2:
            return ("Partly cloudy", "cloud.sun.fill")
        case 3:
            return ("Overcast", "cloud.fill")
        case 45, 48:
            return ("Fog", "cloud.fog.fill")
        case 51, 53, 55, 56, 57:
            return ("Drizzle", "cloud.drizzle.fill")
        case 61, 63, 65, 66, 67:
            return ("Rain", "cloud.rain.fill")
        case 71, 73, 75, 77, 85, 86:
            return ("Snow", "cloud.snow.fill")
        case 80, 81, 82:
            return ("Showers", "cloud.heavyrain.fill")
        case 95, 96, 99:
            return ("Thunderstorm", "cloud.bolt.rain.fill")
        default:
            return ("Local conditions", "cloud.sun.fill")
        }
    }

    private func startRefreshTimerIfNeeded() {
        guard refreshTimer == nil else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: locationRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.roomTemperatureService.refreshNow()
                self.manager.requestLocation()
            }
        }
    }

    nonisolated private static func userVisibleLocationError(_ error: Error) -> String? {
        guard let clError = error as? CLError else {
            return error.localizedDescription
        }

        switch clError.code {
        case .locationUnknown:
            return nil
        case .network:
            return "Location is temporarily unavailable. Retrying automatically."
        case .denied:
            return "Location access denied. Enable it in Settings to map resident location and weather."
        default:
            return clError.localizedDescription
        }
    }
}
