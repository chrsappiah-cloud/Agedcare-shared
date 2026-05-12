import Foundation

public protocol ResidentsRepositoryProtocol: AnyObject {
  func getResidents(facilityId: UUID) async throws -> [ResidentDTO]
  func getFallCount(residentId: UUID, days: Int) async throws -> Int
  func getTimeline(residentId: UUID, limit: Int) async throws -> [TimelineEntryDTO]
  func recordVitalEvent(facilityId: UUID, residentId: UUID, metric: String, value: Double, timestamp: Date) async throws
}

public final class ResidentsRepository: ResidentsRepositoryProtocol {
  private let supabase: SupabaseClient
  private let backupStore = ICloudBackupStore.shared

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
      throw error
    }
  }

  public func getFallCount(residentId: UUID, days: Int) async throws -> Int {
    let req = GetFallSummaryRequest(p_resident_id: residentId.uuidString, p_days: days)
    return try await supabase.rpc("get_fall_summary_for_resident", payload: req)
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
