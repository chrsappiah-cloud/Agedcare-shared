import Foundation

public protocol FacilityRepositoryProtocol: AnyObject {
  func getStats(facilityId: UUID) async throws -> FacilityStatsDTO
}

public final class FacilityRepository: FacilityRepositoryProtocol {
  private let supabase: SupabaseClient
  private let backupStore = ICloudBackupStore.shared
  private let demoStore = DemoResidentStore.shared

  public init(supabase: SupabaseClient) {
    self.supabase = supabase
  }

  public func getStats(facilityId: UUID) async throws -> FacilityStatsDTO {
    let req = GetFacilityStatsRequest(p_facility_id: facilityId.uuidString)
    do {
      let stats: FacilityStatsDTO = try await supabase.rpc("get_facility_stats", payload: req)
      backupStore.saveFacilityStats(stats, facilityId: facilityId)
      return stats
    } catch {
      if let cachedStats = backupStore.loadFacilityStats(facilityId: facilityId) {
        return cachedStats
      }
      if let demoStats = demoStore.facilityStats(facilityId: facilityId) {
        backupStore.saveFacilityStats(demoStats, facilityId: facilityId)
        return demoStats
      }
      throw error
    }
  }
}
