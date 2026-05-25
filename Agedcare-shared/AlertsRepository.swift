import Foundation
#if canImport(CloudKit)
import CloudKit
#endif

public protocol AlertsRepositoryProtocol: AnyObject {
  func createFallAlert(facilityId: UUID, residentId: UUID, priority: Int) async throws -> Int64
  func createSOSAlert(facilityId: UUID, residentId: UUID) async throws -> Int64
  func getOpenAlerts(facilityId: UUID) async throws -> [AlertModel]
  func acknowledgeAlert(alertId: Int64, staffId: UUID) async throws
  func closeAlert(alertId: Int64, notes: String) async throws
}

public final class AlertsRepository: AlertsRepositoryProtocol {
  private let supabase: SupabaseClient
  private let backupStore = ICloudBackupStore.shared

  public init(supabase: SupabaseClient) {
    self.supabase = supabase
  }

  public func createFallAlert(facilityId: UUID, residentId: UUID, priority: Int) async throws -> Int64 {
    let req = CreateFallAlertRequest(
      p_facility_id: facilityId.uuidString,
      p_resident_id: residentId.uuidString,
      p_priority: priority
    )
    do {
      let resp: CreateFallAlertResponse = try await supabase.rpc("create_fall_alert", payload: req)
      await syncBackupAlert(
        AlertModel(
          id: resp.alert_id,
          residentId: residentId,
          type: "fall",
          status: "open",
          priority: priority,
          createdAt: Date(),
          assignedStaffId: nil
        ),
        facilityId: facilityId
      )
      return resp.alert_id
    } catch {
      let fallbackAlert = makeFallbackAlert(
        residentId: residentId,
        type: "fall",
        priority: priority
      )
      try await persistBackupAlert(fallbackAlert, facilityId: facilityId, primaryError: error)
      return fallbackAlert.id
    }
  }

  public func createSOSAlert(facilityId: UUID, residentId: UUID) async throws -> Int64 {
    let req = CreateSOSAlertRequest(
      p_facility_id: facilityId.uuidString,
      p_resident_id: residentId.uuidString
    )
    do {
      let resp: CreateSOSAlertResponse = try await supabase.rpc("create_sos_alert", payload: req)
      await syncBackupAlert(
        AlertModel(
          id: resp.alert_id,
          residentId: residentId,
          type: "sos",
          status: "open",
          priority: 3,
          createdAt: Date(),
          assignedStaffId: nil
        ),
        facilityId: facilityId
      )
      return resp.alert_id
    } catch {
      let fallbackAlert = makeFallbackAlert(
        residentId: residentId,
        type: "sos",
        priority: 3
      )
      try await persistBackupAlert(fallbackAlert, facilityId: facilityId, primaryError: error)
      return fallbackAlert.id
    }
  }

  public func getOpenAlerts(facilityId: UUID) async throws -> [AlertModel] {
    let req = GetOpenAlertsRequest(p_facility_id: facilityId.uuidString)
    do {
      let alerts: [AlertModel] = try await supabase.rpc("get_open_alerts_for_facility", payload: req)
      await syncBackupAlerts(alerts, facilityId: facilityId)
      backupStore.saveAlerts(alerts, facilityId: facilityId)
      return alerts
    } catch {
      #if canImport(CloudKit)
      if let cloudAlerts = try await CloudKitAlertSync.shared?.fetchAlerts(facilityId: facilityId) {
        backupStore.saveAlerts(cloudAlerts, facilityId: facilityId)
        return cloudAlerts.filter { $0.status.caseInsensitiveCompare("open") == .orderedSame }
      }
      #endif
      if let cachedAlerts = backupStore.loadAlerts(facilityId: facilityId) {
        return cachedAlerts.filter { $0.status.caseInsensitiveCompare("open") == .orderedSame }
      }
      throw error
    }
  }

  public func acknowledgeAlert(alertId: Int64, staffId: UUID) async throws {
    let req = AcknowledgeAlertRequest(p_alert_id: alertId, p_staff_id: staffId.uuidString)
    do {
      try await supabase.rpcVoid("acknowledge_alert", payload: req)
      await syncBackupStatus(alertId: alertId, status: "acknowledged", assignedStaffId: staffId)
    } catch {
      try await persistBackupStatus(
        alertId: alertId,
        status: "acknowledged",
        assignedStaffId: staffId,
        primaryError: error
      )
    }
  }

  public func closeAlert(alertId: Int64, notes: String) async throws {
    let req = CloseAlertRequest(p_alert_id: alertId, p_notes: notes)
    do {
      try await supabase.rpcVoid("close_alert", payload: req)
      await syncBackupStatus(alertId: alertId, status: "closed", assignedStaffId: nil)
    } catch {
      try await persistBackupStatus(
        alertId: alertId,
        status: "closed",
        assignedStaffId: nil,
        primaryError: error
      )
    }
  }

  private func makeFallbackAlert(residentId: UUID, type: String, priority: Int) -> AlertModel {
    AlertModel(
      id: Int64.max - Int64(Date().timeIntervalSince1970 * 1_000),
      residentId: residentId,
      type: type,
      status: "open",
      priority: priority,
      createdAt: Date(),
      assignedStaffId: nil
    )
  }

  private func syncBackupAlerts(_ alerts: [AlertModel], facilityId: UUID) async {
    for alert in alerts {
      await syncBackupAlert(alert, facilityId: facilityId)
    }
  }

  private func syncBackupAlert(_ alert: AlertModel, facilityId: UUID) async {
    #if canImport(CloudKit)
    do {
      try await CloudKitAlertSync.shared?.pushAlert(alert, facilityId: facilityId)
    } catch {
      print("⚠️ CloudKit backup sync failed: \(error.localizedDescription)")
    }
    #endif
  }

  private func syncBackupStatus(alertId: Int64, status: String, assignedStaffId: UUID?) async {
    #if canImport(CloudKit)
    do {
      try await CloudKitAlertSync.shared?.updateAlertStatus(
        alertId: alertId,
        status: status,
        assignedStaffId: assignedStaffId
      )
    } catch {
      print("⚠️ CloudKit backup status sync failed: \(error.localizedDescription)")
    }
    #endif
  }

  private func persistBackupAlert(_ alert: AlertModel, facilityId: UUID, primaryError: Error) async throws {
    #if canImport(CloudKit)
    if let cloudKit = CloudKitAlertSync.shared {
      do {
        try await cloudKit.pushAlert(alert, facilityId: facilityId)
        return
      } catch {
        throw primaryError
      }
    }
    #endif
    throw primaryError
  }

  private func persistBackupStatus(
    alertId: Int64,
    status: String,
    assignedStaffId: UUID?,
    primaryError: Error
  ) async throws {
    #if canImport(CloudKit)
    if let cloudKit = CloudKitAlertSync.shared {
      do {
        try await cloudKit.updateAlertStatus(
          alertId: alertId,
          status: status,
          assignedStaffId: assignedStaffId
        )
        return
      } catch {
        throw primaryError
      }
    }
    #endif
    throw primaryError
  }
}
