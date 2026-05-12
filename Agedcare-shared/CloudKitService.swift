#if canImport(CloudKit)
import CloudKit

public final class CloudKitService {
  public static let shared = CloudKitService()
  private let container: CKContainer

  private init(container: CKContainer = .default()) {
    self.container = container
  }

  public var privateDB: CKDatabase { container.privateCloudDatabase }
  public var publicDB: CKDatabase { container.publicCloudDatabase }

  @discardableResult
  public func save(_ record: CKRecord, in db: CKDatabase? = nil) async throws -> CKRecord {
    try await (db ?? privateDB).save(record)
  }

  public func query(
    recordType: String,
    predicate: NSPredicate = NSPredicate(value: true),
    in db: CKDatabase? = nil
  ) async throws -> [CKRecord] {
    let operation = CKQueryOperation(query: CKQuery(recordType: recordType, predicate: predicate))
    var results: [CKRecord] = []
    operation.recordMatchedBlock = { _, result in
      if case .success(let record) = result {
        results.append(record)
      }
    }
    return try await withCheckedThrowingContinuation { cont in
      operation.queryResultBlock = { result in
        switch result {
        case .success:
          cont.resume(returning: results)
        case .failure(let error):
          cont.resume(throwing: error)
        }
      }
      (db ?? self.privateDB).add(operation)
    }
  }
}

extension CloudKitService {
  @discardableResult
  func saveIncidentRecording(_ incident: IncidentRecording) async throws -> String {
    let recordName = incident.cloudKitRecordName ?? "incident-\(incident.id.uuidString)"
    let record = CKRecord(recordType: "AgedCareIncidentMedia", recordID: CKRecord.ID(recordName: recordName))
    record["incidentId"] = incident.id.uuidString
    record["facilityId"] = incident.facilityId?.uuidString
    record["residentId"] = incident.residentId?.uuidString
    record["type"] = incident.type
    record["recordedAt"] = incident.timestamp
    record["durationSeconds"] = incident.duration as CKRecordValue
    record["hasPreIncidentFootage"] = incident.hasPreIncidentFootage as CKRecordValue
    record["syncStatus"] = incident.resolvedSyncStatus.rawValue
    record["summary"] = incident.backendSummary
    record["analysisId"] = incident.backendAnalysisID
    record["externalMediaURL"] = incident.backendMediaURL?.absoluteString
    record["localFilename"] = incident.fileURL.lastPathComponent
    record["snapshotFilename"] = incident.snapshotURL?.lastPathComponent
    if let location = incident.locationSnapshot {
      record["locationName"] = location.locationName
      record["latitude"] = location.latitude as CKRecordValue?
      record["longitude"] = location.longitude as CKRecordValue?
      record["movementSummary"] = location.movementSummary
      record["roomTemperature"] = location.roomTemperatureCelsius as CKRecordValue?
    }
    if FileManager.default.fileExists(atPath: incident.fileURL.path) {
      record["videoAsset"] = CKAsset(fileURL: incident.fileURL)
    }
    if let snapshotURL = incident.snapshotURL,
       FileManager.default.fileExists(atPath: snapshotURL.path) {
      record["snapshotAsset"] = CKAsset(fileURL: snapshotURL)
    }
    _ = try await save(record, in: privateDB)
    return recordName
  }
}
#endif
