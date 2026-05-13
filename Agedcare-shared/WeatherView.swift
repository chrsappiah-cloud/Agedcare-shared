import SwiftUI
import MapKit

// MARK: - Weather card shown on ResidentHomeView
struct WeatherCardView: View {
    @StateObject private var service = LocationWeatherService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            if service.isLoading && !hasSnapshotContent {
                ProgressView("Fetching weather…")
                    .frame(maxWidth: .infinity)
            } else {
                if let err = service.error {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.danger)
                }
                residentMap
                weatherGrid
                movementGrid
                roomTemperatureFootnote
            }
        }
        .padding(16)
        .background(AppTheme.surface)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        .onAppear { service.requestPermissionAndStart() }
        .onDisappear { service.stop() }
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
            Button { service.requestPermissionAndStart() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.emeraldGreen)
            }
            .accessibilityLabel("Refresh weather")
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
            Map(position: .constant(.region(region))) {
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

// MARK: - Preview
#Preview {
    WeatherCardView()
        .padding()
        .background(AppTheme.gradientDiamond)
}
