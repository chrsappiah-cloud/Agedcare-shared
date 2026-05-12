import Foundation

final class ICloudBackupStore {
  static let shared = ICloudBackupStore()

  private let kvStore = NSUbiquitousKeyValueStore.default
  private let defaults = UserDefaults.standard
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  private init() {
    kvStore.synchronize()
  }

  var isICloudAvailable: Bool {
    FileManager.default.ubiquityIdentityToken != nil
  }

  func saveAlerts(_ alerts: [AlertModel], facilityId: UUID) {
    save(alerts, forKey: "alerts.\(facilityId.uuidString)")
  }

  func loadAlerts(facilityId: UUID) -> [AlertModel]? {
    load([AlertModel].self, forKey: "alerts.\(facilityId.uuidString)")
  }

  func saveResidents(_ residents: [ResidentDTO], facilityId: UUID) {
    save(residents, forKey: "residents.\(facilityId.uuidString)")
  }

  func loadResidents(facilityId: UUID) -> [ResidentDTO]? {
    load([ResidentDTO].self, forKey: "residents.\(facilityId.uuidString)")
  }

  func saveTimeline(_ entries: [TimelineEntryDTO], residentId: UUID) {
    save(entries, forKey: "timeline.\(residentId.uuidString)")
  }

  func loadTimeline(residentId: UUID) -> [TimelineEntryDTO]? {
    load([TimelineEntryDTO].self, forKey: "timeline.\(residentId.uuidString)")
  }

  func saveFacilityStats(_ stats: FacilityStatsDTO, facilityId: UUID) {
    save(stats, forKey: "facility-stats.\(facilityId.uuidString)")
  }

  func loadFacilityStats(facilityId: UUID) -> FacilityStatsDTO? {
    load(FacilityStatsDTO.self, forKey: "facility-stats.\(facilityId.uuidString)")
  }

  func saveInsights(_ insights: [MediaAnalysisResult], facilityId: String) {
    save(insights, forKey: "ai-insights.\(facilityId)")
  }

  func loadInsights(facilityId: String) -> [MediaAnalysisResult]? {
    load([MediaAnalysisResult].self, forKey: "ai-insights.\(facilityId)")
  }

  func saveSessions(_ sessions: [AudioMonitorSession], facilityId: String) {
    save(sessions, forKey: "ai-sessions.\(facilityId)")
  }

  func loadSessions(facilityId: String) -> [AudioMonitorSession]? {
    load([AudioMonitorSession].self, forKey: "ai-sessions.\(facilityId)")
  }

  func saveEvents(_ events: [AudioMonitorEvent], facilityId: String) {
    save(events, forKey: "ai-events.\(facilityId)")
  }

  func loadEvents(facilityId: String) -> [AudioMonitorEvent]? {
    load([AudioMonitorEvent].self, forKey: "ai-events.\(facilityId)")
  }

  private func save<T: Codable>(_ value: T, forKey key: String) {
    guard let data = try? encoder.encode(value) else { return }
    defaults.set(data, forKey: key)
    kvStore.set(data, forKey: key)
    kvStore.synchronize()
  }

  private func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
    if let data = defaults.data(forKey: key),
       let decoded = try? decoder.decode(type, from: data) {
      return decoded
    }

    if let data = kvStore.data(forKey: key),
       let decoded = try? decoder.decode(type, from: data) {
      return decoded
    }

    return nil
  }
}
