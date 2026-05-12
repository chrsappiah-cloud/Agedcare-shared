import SwiftUI

struct InsightsView: View {
  let staff: StaffUserModel
  @EnvironmentObject var container: DependencyContainer
  @State private var stats: FacilityStatsDTO?
  @State private var loadError: String?
  private let refreshIntervalNanoseconds: UInt64 = 15_000_000_000

  var body: some View {
    NavigationStack {
      List {
        if let stats {
          Section("Last 7 days") {
            LabeledContent("Falls", value: "\(stats.falls_last_7d)")
            LabeledContent("Open alerts", value: "\(stats.open_alerts)")
            LabeledContent("Avg. acknowledge time", value: "\(stats.avg_acknowledge_minutes) min")
          }
        }
        if let error = loadError {
          Section {
            Text(error).foregroundColor(.red)
          }
        }
      }
      .navigationTitle("Insights")
      .refreshable { await loadStats() }
      .task { await liveRefreshLoop() }
    }
  }

  private func liveRefreshLoop() async {
    while !Task.isCancelled {
      await loadStats()
      try? await Task.sleep(nanoseconds: refreshIntervalNanoseconds)
    }
  }

  private func loadStats() async {
    do {
      stats = try await container.facilityRepository.getStats(facilityId: staff.facilityId)
      loadError = nil
    } catch {
      loadError = error.userFacingMessage(fallback: "Insights are temporarily unavailable. Please pull to refresh and try again.")
    }
  }
}
