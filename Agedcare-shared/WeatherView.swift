import SwiftUI
import MapKit

// MARK: - Weather card shown on ResidentHomeView
struct WeatherCardView: View {
    private enum WeatherSectionTab: String, CaseIterable, Identifiable {
        case overview
        case location
        case systems

        var id: String { rawValue }

        var title: String {
            switch self {
            case .overview: return "Overview"
            case .location: return "Location"
            case .systems: return "Systems"
            }
        }
    }

    @StateObject private var service = LocationWeatherService.shared
    @State private var selectedTab: WeatherSectionTab = .overview
    @State private var mapCameraPosition: MapCameraPosition = .automatic

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            tabPicker
            if service.isLoading && !hasSnapshotContent {
                ProgressView("Fetching weather…")
                    .frame(maxWidth: .infinity)
            } else {
                if let err = service.error {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.danger)
                }
                tabContent
            }
        }
        .padding(16)
        .background(AppTheme.surface)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        .onAppear { service.requestPermissionAndStart() }
        .onDisappear { service.stop() }
        .onReceive(service.$snapshot) { _ in
            syncMapCamera()
        }
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "cloud.sun.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.emeraldGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text("Weather & Room Temp")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                if !service.snapshot.liveStatusSummary().isEmpty {
                    Text(service.snapshot.liveStatusSummary())
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer()
            if let lastUpdated = service.snapshot.lastUpdated {
                Text(lastUpdated, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Button { service.refreshNow() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.emeraldGreen)
            }
            .accessibilityLabel("Refresh weather")
        }
    }

    private var tabPicker: some View {
        Picker("Weather sections", selection: $selectedTab) {
            ForEach(WeatherSectionTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("weather_section_tabs")
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            weatherGrid
                .accessibilityIdentifier("weather_overview_panel")
            roomTemperatureFootnote
        case .location:
            residentMap
            movementGrid
                .accessibilityIdentifier("weather_location_panel")
        case .systems:
            systemsGrid
                .accessibilityIdentifier("weather_systems_panel")
        }
    }

    private var weatherGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            WeatherTileView(
                icon: service.snapshot.conditionSymbol,
                label: "Outdoor Temp",
                value: service.snapshot.formattedOutdoorTemp(),
                color: .orange
            )
            WeatherTileView(
                icon: "thermometer.medium",
                label: service.snapshot.hasActualRoomTemperature ? "Room Temp" : "Room Temp (est.)",
                value: service.snapshot.formattedRoomTemp(),
                color: AppTheme.emeraldGreen
            )
            WeatherTileView(
                icon: "humidity.fill",
                label: "Humidity",
                value: service.snapshot.formattedHumidity(),
                color: .blue
            )
            WeatherTileView(
                icon: "wind",
                label: "Conditions",
                value: service.snapshot.conditionDescription.isEmpty
                    ? "--" : service.snapshot.conditionDescription,
                color: .purple
            )
        }
    }

    private var movementGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            WeatherTileView(
                icon: "location.fill",
                label: "Location",
                value: service.snapshot.locationName.isEmpty ? "--" : service.snapshot.locationName,
                color: .red
            )
            WeatherTileView(
                icon: "figure.walk",
                label: "Movement",
                value: service.snapshot.movementStateDescription(),
                color: .mint
            )
            WeatherTileView(
                icon: "speedometer",
                label: "Speed",
                value: service.snapshot.formattedSpeed(),
                color: .indigo
            )
            WeatherTileView(
                icon: "point.topleft.down.curvedto.point.bottomright.up",
                label: "Distance",
                value: service.snapshot.formattedDistance(),
                color: .pink
            )
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var residentMap: some View {
        if let region = service.snapshot.mapRegion,
           let coordinate = service.snapshot.coordinate {
            Map(position: $mapCameraPosition, interactionModes: [.pan, .zoom]) {
                Marker("Resident", coordinate: coordinate)
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .bottomLeading) {
                Text(service.snapshot.formattedCoordinates())
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.5), in: Capsule())
                    .padding(10)
            }
            .onAppear {
                mapCameraPosition = .region(region)
            }
        }
    }

    private var systemsGrid: some View {
        VStack(spacing: 10) {
            SystemStatusRow(
                title: "Weather source",
                detail: service.snapshot.weatherSourceDescription(),
                status: service.snapshot.weatherLastUpdated == nil ? .pending : .ok
            )
            SystemStatusRow(
                title: "Room temperature",
                detail: service.snapshot.roomTemperatureSourceDescription(),
                status: service.snapshot.hasActualRoomTemperature ? .ok : .pending
            )
            SystemStatusRow(
                title: "Location services",
                detail: locationStatusDetail,
                status: service.snapshot.coordinate == nil ? .pending : .ok
            )
            SystemStatusRow(
                title: "Map & geocoding",
                detail: service.snapshot.locationSourceDescription(),
                status: service.snapshot.coordinate == nil ? .pending : .ok
            )
            SystemStatusRow(
                title: "Backend sync",
                detail: backendSyncDetail,
                status: backendSyncIndicator
            )
        }
    }

    private var roomTemperatureFootnote: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(service.snapshot.roomTemperatureSourceDescription())
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            if !service.snapshot.locationName.isEmpty {
                Text(service.snapshot.locationName)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Text(service.snapshot.locationSourceDescription())
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
            if !service.snapshot.hasActualRoomTemperature {
                Text("Add a HomeKit temperature sensor or thermostat to show actual room temperature.")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(.top, 8)
    }

    private var hasSnapshotContent: Bool {
        service.snapshot.coordinate != nil
            || service.snapshot.outdoorTemperature != nil
            || service.snapshot.roomTemperature != nil
            || !service.snapshot.locationName.isEmpty
    }

    private var locationStatusDetail: String {
        switch service.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if let accuracy = service.snapshot.horizontalAccuracyMeters {
                return "Live location, ±\(Int(accuracy.rounded())) m"
            }
            return "Live location ready"
        case .notDetermined:
            return "Waiting for permission"
        case .denied, .restricted:
            return "Permission required in Settings"
        @unknown default:
            return "Location status unknown"
        }
    }

    private var backendSyncDetail: String {
        switch service.backendSyncState {
        case .idle:
            return "Waiting for live monitoring"
        case .syncing:
            return "Sending weather and location metrics"
        case .synced(let date):
            return "Synced \(date.formatted(date: .omitted, time: .shortened))"
        case .failed(let message):
            return message
        }
    }

    private var backendSyncIndicator: SystemStatusRow.Indicator {
        switch service.backendSyncState {
        case .idle:
            return .pending
        case .syncing:
            return .active
        case .synced:
            return .ok
        case .failed:
            return .error
        }
    }

    private func syncMapCamera() {
        guard let region = service.snapshot.mapRegion else { return }
        mapCameraPosition = .region(region)
    }
}

// MARK: - Individual tile
private struct WeatherTileView: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppTheme.background)
        .cornerRadius(10)
    }
}

private struct SystemStatusRow: View {
    enum Indicator {
        case ok
        case active
        case pending
        case error
    }

    let title: String
    let detail: String
    let status: Indicator

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(AppTheme.background)
        .cornerRadius(12)
    }

    private var statusColor: Color {
        switch status {
        case .ok: return AppTheme.emeraldGreen
        case .active: return .blue
        case .pending: return AppTheme.warning
        case .error: return AppTheme.emeraldRed
        }
    }
}

// MARK: - Preview
#Preview {
    WeatherCardView()
        .padding()
        .background(AppTheme.gradientDiamond)
}
