import Foundation
import CryptoKit

public protocol ResidentsRepositoryProtocol: AnyObject {
  func getResidents(facilityId: UUID) async throws -> [ResidentDTO]
  func getFallCount(residentId: UUID, days: Int) async throws -> Int
  func getTimeline(residentId: UUID, limit: Int) async throws -> [TimelineEntryDTO]
  func recordVitalEvent(facilityId: UUID, residentId: UUID, metric: String, value: Double, timestamp: Date) async throws
}

public final class ResidentsRepository: ResidentsRepositoryProtocol {
  private let supabase: SupabaseClient
  private let backupStore = ICloudBackupStore.shared
  private let demoStore = DemoResidentStore.shared

  public init(supabase: SupabaseClient) {
    self.supabase = supabase
  }

  public func getResidents(facilityId: UUID) async throws -> [ResidentDTO] {
    let req = GetResidentsRequest(p_facility_id: facilityId.uuidString)
    do {
      let residents: [ResidentDTO] = try await supabase.rpc("get_residents_for_facility", payload: req)
      backupStore.saveResidents(residents, facilityId: facilityId)
      return residents
    } catch {
      if let cachedResidents = backupStore.loadResidents(facilityId: facilityId) {
        return cachedResidents
      }
      if let demoResidents = demoStore.residents(facilityId: facilityId) {
        backupStore.saveResidents(demoResidents, facilityId: facilityId)
        return demoResidents
      }
      throw error
    }
  }

  public func getFallCount(residentId: UUID, days: Int) async throws -> Int {
    let req = GetFallSummaryRequest(p_resident_id: residentId.uuidString, p_days: days)
    do {
      return try await supabase.rpc("get_fall_summary_for_resident", payload: req)
    } catch {
      if let demoFallCount = demoStore.fallCount(residentId: residentId, days: days) {
        return demoFallCount
      }
      throw error
    }
  }

  public func getTimeline(residentId: UUID, limit: Int = 50) async throws -> [TimelineEntryDTO] {
    let req = GetTimelineRequest(p_resident_id: residentId.uuidString, p_limit: limit)
    do {
      let timeline: [TimelineEntryDTO] = try await supabase.rpc("get_resident_timeline", payload: req)
      backupStore.saveTimeline(timeline, residentId: residentId)
      return timeline
    } catch {
      if let cachedTimeline = backupStore.loadTimeline(residentId: residentId) {
        return cachedTimeline
      }
      if let demoTimeline = demoStore.timeline(residentId: residentId, limit: limit) {
        backupStore.saveTimeline(demoTimeline, residentId: residentId)
        return demoTimeline
      }
      throw error
    }
  }

  public func recordVitalEvent(facilityId: UUID, residentId: UUID, metric: String, value: Double, timestamp: Date) async throws {
    let req = RecordVitalEventRequest(
      p_facility_id: facilityId, p_resident_id: residentId,
      p_metric: metric, p_value: value, p_timestamp: timestamp
    )
    try await supabase.rpcVoid("record_vital_event", payload: req)
  }
}

final class DemoResidentStore {
  static let shared = DemoResidentStore()

  private let residentSetsByFacility: [UUID: [ResidentDTO]]
  private let timelineByResident: [UUID: [TimelineEntryDTO]]
  private let facilityStatsByFacility: [UUID: FacilityStatsDTO]

  private init() {
    var residentsByFacility = [UUID: [ResidentDTO]]()
    var timelines = [UUID: [TimelineEntryDTO]]()
    var stats = [UUID: FacilityStatsDTO]()

    for profile in AppHost.testingAccessProfiles {
      let residents = Self.makeResidents(for: profile)
      residentsByFacility[profile.facilityId] = residents

      var facilityFallCount7d = 0
      for resident in residents {
        let residentTimeline = Self.makeTimeline(for: resident)
        timelines[resident.id] = residentTimeline
        facilityFallCount7d += residentTimeline.filter {
          $0.kind == "fall" && Self.daysAgo(from: $0.ts) <= 7
        }.count
      }

      stats[profile.facilityId] = FacilityStatsDTO(
        falls_last_7d: facilityFallCount7d,
        open_alerts: max(1, facilityFallCount7d),
        avg_acknowledge_minutes: profile.subscriptionTier == .careTeam ? 3 : 6
      )
    }

    self.residentSetsByFacility = residentsByFacility
    self.timelineByResident = timelines
    self.facilityStatsByFacility = stats
  }

  func supportsFacility(_ facilityId: UUID) -> Bool {
    residentSetsByFacility[facilityId] != nil
  }

  func containsResident(_ residentId: UUID) -> Bool {
    timelineByResident[residentId] != nil
  }

  func residents(facilityId: UUID) -> [ResidentDTO]? {
    residentSetsByFacility[facilityId]
  }

  func timeline(residentId: UUID, limit: Int) -> [TimelineEntryDTO]? {
    guard let timeline = timelineByResident[residentId] else { return nil }
    return Array(timeline.prefix(limit))
  }

  func fallCount(residentId: UUID, days: Int) -> Int? {
    guard let timeline = timelineByResident[residentId] else { return nil }
    return timeline.filter { $0.kind == "fall" && Self.daysAgo(from: $0.ts) <= days }.count
  }

  func facilityStats(facilityId: UUID) -> FacilityStatsDTO? {
    facilityStatsByFacility[facilityId]
  }

  private static func makeResidents(for profile: TestingAccessProfile) -> [ResidentDTO] {
    let templates: [(name: String, risk: String?, dob: String)]
    switch profile.subscriptionTier {
    case .starter:
      templates = [
        ("Margaret Ellis", "medium", "1941-04-18T00:00:00Z"),
        ("Thomas Reid", "low", "1946-11-02T00:00:00Z"),
        ("June Carter", "low", "1950-07-09T00:00:00Z"),
      ]
    case .carePro:
      templates = [
        ("Evelyn Moore", "high", "1938-02-03T00:00:00Z"),
        ("Samuel Brooks", "medium", "1944-09-15T00:00:00Z"),
        ("Lillian Hart", "low", "1949-12-24T00:00:00Z"),
      ]
    case .careTeam:
      templates = [
        ("Aisha Khan", "high", "1937-03-20T00:00:00Z"),
        ("Peter Johnson", "medium", "1942-06-12T00:00:00Z"),
        ("Grace Walker", "low", "1948-10-27T00:00:00Z"),
      ]
    }

    return templates.enumerated().map { index, template in
      ResidentDTO(
        id: stableUUID(seed: "\(profile.facilityId.uuidString)-resident-\(index + 1)"),
        facility_id: profile.facilityId,
        name: template.name,
        risk_level: template.risk,
        date_of_birth: template.dob
      )
    }
  }

  private static func makeTimeline(for resident: ResidentDTO) -> [TimelineEntryDTO] {
    let risk = resident.risk_level?.lowercased() ?? "low"

    switch risk {
    case "high":
      return [
        TimelineEntryDTO(kind: "vital", ts: isoTimestamp(daysAgo: 0, hour: 8), summary: "Morning vitals captured automatically."),
        TimelineEntryDTO(kind: "fall", ts: isoTimestamp(daysAgo: 2, hour: 3), summary: "Possible fall detected and escalated to staff."),
        TimelineEntryDTO(kind: "vital", ts: isoTimestamp(daysAgo: 5, hour: 14), summary: "Heart-rate trend remained elevated; review suggested."),
        TimelineEntryDTO(kind: "fall", ts: isoTimestamp(daysAgo: 18, hour: 21), summary: "Night-time stumble recorded in resident room."),
      ]
    case "medium":
      return [
        TimelineEntryDTO(kind: "vital", ts: isoTimestamp(daysAgo: 0, hour: 9), summary: "Medication follow-up and hydration check recorded."),
        TimelineEntryDTO(kind: "vital", ts: isoTimestamp(daysAgo: 4, hour: 13), summary: "Routine movement and wellbeing pattern captured."),
        TimelineEntryDTO(kind: "fall", ts: isoTimestamp(daysAgo: 11, hour: 19), summary: "Minor instability event noted for observation."),
      ]
    default:
      return [
        TimelineEntryDTO(kind: "vital", ts: isoTimestamp(daysAgo: 1, hour: 10), summary: "Daily wellness summary synced from the care plan."),
        TimelineEntryDTO(kind: "vital", ts: isoTimestamp(daysAgo: 6, hour: 15), summary: "Regular mobility and comfort checks completed."),
      ]
    }
  }

  private static func daysAgo(from timestamp: String) -> Int {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: timestamp) {
      return Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? .max
    }

    formatter.formatOptions = [.withInternetDateTime]
    guard let fallbackDate = formatter.date(from: timestamp) else { return .max }
    return Calendar.current.dateComponents([.day], from: fallbackDate, to: Date()).day ?? .max
  }

  private static func isoTimestamp(daysAgo: Int, hour: Int) -> String {
    let calendar = Calendar(identifier: .gregorian)
    let baseDate = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
    let dated = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: baseDate) ?? baseDate
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: dated)
  }

  private static func stableUUID(seed: String) -> UUID {
    let digest = SHA256.hash(data: Data(seed.utf8))
    let bytes = Array(digest.prefix(16))
    let hex = bytes.map { String(format: "%02x", $0) }.joined()
    let part1 = String(hex.prefix(8))
    let part2 = String(hex.dropFirst(8).prefix(4))
    let part3 = String(hex.dropFirst(12).prefix(4))
    let part4 = String(hex.dropFirst(16).prefix(4))
    let part5 = String(hex.dropFirst(20).prefix(12))
    let formatted = [part1, part2, part3, part4, part5].joined(separator: "-")
    return UUID(uuidString: formatted) ?? UUID()
  }
}
