#if canImport(CloudKit)
import CloudKit
import Foundation

public enum CloudKitSyncError: LocalizedError {
  case containerNotConfigured
  case subscriptionFailed(String)
  case recordFailed(String)

  public var errorDescription: String? {
    switch self {
    case .containerNotConfigured: return "CloudKit container not configured"
    case .subscriptionFailed(let m): return "Subscription error: \(m)"
    case .recordFailed(let m): return "Record error: \(m)"
    }
  }
}

public final class CloudKitAlertSync: @unchecked Sendable {
  public static var shared: CloudKitAlertSync? = CloudKitAlertSync()
  public var container: CKContainer!
  public var sharedDB: CKDatabase!

  public static let alertRecordType = "AgedCareAlert"
  public static let subscriptionID = "agedcare-alert-changes"

  private var service: CloudKitService!

  public init() {
    // Eager init deferred — call setup() before use
  }

  public func setup() throws {
    guard container == nil else { return }
    #if targetEnvironment(simulator)
    throw CloudKitSyncError.containerNotConfigured
    #else
    container = CKContainer.default()
    service = CloudKitService.shared
    sharedDB = service.privateDB
    #endif
  }

  // MARK: - Record conversion

  public func makeAlertRecord(
    id: String,
    facilityId: String,
    residentId: String,
    type: String,
    priority: Int,
    status: String = "open",
    createdAt: Date = Date(),
    assignedStaffId: String? = nil
  ) -> CKRecord {
    let record = CKRecord(recordType: Self.alertRecordType, recordID: CKRecord.ID(recordName: id))
    record["facilityId"] = facilityId
    record["residentId"] = residentId
    record["type"] = type
    record["priority"] = priority as CKRecordValue
    record["status"] = status
    record["createdAt"] = createdAt
    record["assignedStaffId"] = assignedStaffId
    return record
  }

  public func alertFromRecord(_ record: CKRecord) -> AlertModel? {
    guard
      let residentId = record["residentId"] as? String,
      let type = record["type"] as? String,
      let status = record["status"] as? String,
      let priority = record["priority"] as? Int,
      let createdAt = record["createdAt"] as? Date
    else { return nil }

    let assignedStaffId = (record["assignedStaffId"] as? String).flatMap(UUID.init(uuidString:))

    return AlertModel(
      id: alertID(from: record.recordID),
      residentId: UUID(uuidString: residentId) ?? UUID(),
      type: type,
      status: status,
      priority: priority,
      createdAt: createdAt,
      assignedStaffId: assignedStaffId
    )
  }

  private func alertID(from recordID: CKRecord.ID) -> Int64 {
    let recordName = recordID.recordName
    if let suffix = recordName.split(separator: "-", omittingEmptySubsequences: false).last,
       let id = Int64(suffix) {
      return id
    }

    var value: UInt64 = 1_469_598_103_934_665_603
    for byte in recordName.utf8 {
      value ^= UInt64(byte)
      value &*= 1_099_511_628_211
    }
    return Int64(bitPattern: value)
  }

  // MARK: - Sync operations

  public func pushAlert(_ alert: AlertModel, facilityId: UUID) async throws {
    try setup()
    let record = makeAlertRecord(
      id: "alert-\(alert.id)",
      facilityId: facilityId.uuidString,
        residentId: alert.residentId.uuidString,
        type: alert.type,
        priority: alert.priority,
        status: alert.status,
        createdAt: alert.createdAt,
        assignedStaffId: alert.assignedStaffId?.uuidString
      )
    try await service.save(record, in: sharedDB)
  }

  public func updateAlertStatus(alertId: Int64, status: String, assignedStaffId: UUID? = nil) async throws {
    try setup()
    let recordID = CKRecord.ID(recordName: "alert-\(alertId)")
    let record = try await sharedDB.record(for: recordID)
    record["status"] = status
    record["assignedStaffId"] = assignedStaffId?.uuidString
    try await service.save(record, in: sharedDB)
  }

  public func fetchAlerts(facilityId: UUID) async throws -> [AlertModel] {
    try setup()
    let pred = NSPredicate(format: "facilityId == %@", facilityId.uuidString)
    let records = try await service.query(recordType: Self.alertRecordType, predicate: pred, in: sharedDB)
    return records.compactMap { alertFromRecord($0) }
  }

  // MARK: - Subscriptions (real-time push)

  public func subscribeToChanges() async throws {
    try setup()
    let accountStatus = try await container.accountStatus()
    guard accountStatus == .available else { return }
    let sub = CKQuerySubscription(
      recordType: Self.alertRecordType,
      predicate: NSPredicate(value: true),
      subscriptionID: Self.subscriptionID,
      options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
    )

    let info = CKSubscription.NotificationInfo()
    info.alertBody = "New care alert"
    info.soundName = "default"
    info.shouldBadge = true
    info.shouldSendContentAvailable = true
    sub.notificationInfo = info

    do {
      try await sharedDB.save(sub)
    } catch let e as CKError where e.code == .serverRejectedRequest {
      throw CloudKitSyncError.subscriptionFailed("Server rejected: \(e.localizedDescription)")
    } catch let e as CKError where e.code == .serverRejectedRequest || e.code.rawValue == 10003 {
      return
    }
  }

  public func unsubscribe() async throws {
    try setup()
    try await sharedDB.deleteSubscription(withID: Self.subscriptionID)
  }

  // MARK: - Remote notification handling

  public func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async {
    do { try setup() } catch { return }
    guard let notificationUserInfo = userInfo as? [String: NSObject] else { return }
    let notification = CKNotification(fromRemoteNotificationDictionary: notificationUserInfo)
    guard
      let queryNotification = notification as? CKQueryNotification,
      let recordID = queryNotification.recordID
    else { return }

    do {
      let record = try await sharedDB.record(for: recordID)
      if let alert = alertFromRecord(record) {
        alertUpdateHandler?(alert, queryNotification.queryNotificationReason)
      }
    } catch {
      alertErrorHandler?(error)
    }
  }

  public var alertUpdateHandler: ((AlertModel, CKQueryNotification.Reason) -> Void)?
  public var alertErrorHandler: ((Error) -> Void)?
}

#endif
