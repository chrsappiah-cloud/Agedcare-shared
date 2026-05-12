import SwiftUI

struct WatchDashboardView: View {
    @EnvironmentObject private var sessionManager: WatchSessionManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            statusView
                .tag(0)
            alertsView
                .tag(1)
            sosView
                .tag(2)
        }
        .tabViewStyle(.verticalPage)
    }

    private var statusView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Label(sessionManager.statusText, systemImage: sessionManager.isReachable ? "applewatch.radiowaves.left.and.right" : "applewatch.slash")
                    .font(.headline)

                watchMetricRow(icon: "heart.fill", title: "Heart rate", value: sessionManager.heartRateText, tint: .red)
                watchMetricRow(icon: "drop.fill", title: "Oxygen", value: sessionManager.bloodOxygenText, tint: .green)
                watchMetricRow(icon: "figure.fall.circle", title: "Fall risk", value: sessionManager.fallRisk.capitalized, tint: .orange)
                watchMetricRow(icon: "location.fill", title: "Location", value: sessionManager.locationName, tint: .blue)

                Text(sessionManager.movementSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let sync = sessionManager.lastSyncDate {
                    Text("Synced \(sync.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let error = sessionManager.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                Button("Refresh") {
                    sessionManager.requestContextRefresh()
                    sessionManager.refreshVitalsFromWatch()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    private var alertsView: some View {
        List {
            if sessionManager.alerts.isEmpty {
                Text("No current alerts")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sessionManager.alerts) { alert in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(alert.type.capitalized)
                                .font(.caption.bold())
                            Spacer()
                            Text("P\(alert.priority)")
                                .font(.caption2.bold())
                                .foregroundStyle(.red)
                        }
                        Text("Resident \(alert.residentId.prefix(6))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(alert.status.capitalized)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.carousel)
    }

    private var sosView: some View {
        VStack(spacing: 12) {
            Spacer()
            Button {
                sessionManager.sendSOS()
            } label: {
                ZStack {
                    Circle()
                        .fill(.red)
                        .frame(width: 96, height: 96)
                    Text("SOS")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)

            Text("Send an emergency request to the iPhone care dashboard.")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }

    private func watchMetricRow(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.bold())
            }
            Spacer()
        }
    }
}
