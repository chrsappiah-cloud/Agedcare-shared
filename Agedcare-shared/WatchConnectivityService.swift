import Foundation
import Combine
import WatchConnectivity

@MainActor
final class WatchConnectivityService: NSObject, ObservableObject {
  static let shared = WatchConnectivityService()

  struct WatchContext {
    let isComplicationEnabled: Bool
    let isPaired: Bool
    let isWatchAppInstalled: Bool
    let activationState: WCSessionActivationState
  }

  struct WatchResidentSyncPayload: Codable, Sendable {
    let facilityId: String
    let residentId: String
    let statusText: String
    let isMonitoringActive: Bool
    let isRecordingIncident: Bool
    let fallRisk: String
    let heartRate: String?
    let bloodOxygen: String?
    let locationName: String?
    let movementSummary: String?
    let recordedAt: String
  }

  struct WatchAlertSummary: Codable, Sendable {
    let id: Int64
    let residentId: String
    let type: String
    let status: String
    let priority: Int
    let createdAt: String
  }

  @Published var isReachable = false
  @Published var watchContext: WatchContext?
  @Published var lastMessage: [String: Any]?
  @Published var activationState: WCSessionActivationState = .notActivated
  @Published var isPaired = false
  @Published var isWatchAppInstalled = false
  @Published var lastSyncDate: Date?
  @Published var lastErrorMessage: String?

  private let session = WCSession.isSupported() ? WCSession.default : nil
  private var pendingUserInfo = [[String: Any]]()
  private var pendingApplicationContext = [String: Any]()
  private var latestApplicationContext = [String: Any]()

  private override init() {
    super.init()
    guard let session else { return }
    session.delegate = self
    session.activate()
    refreshState(from: session)
  }

  var isSupported: Bool {
    session != nil
  }

  var statusSummary: String {
    guard isSupported else { return "WatchConnectivity unavailable on this device" }
    if activationState != .activated { return "Activating Apple Watch link" }
    if !isPaired { return "No Apple Watch paired" }
    if !isWatchAppInstalled { return "Watch paired, companion app not installed" }
    return isReachable ? "Apple Watch connected" : "Apple Watch available for background sync"
  }

  func activateSessionIfNeeded() {
    guard let session else { return }
    if session.activationState != .activated {
      session.activate()
    }
    refreshState(from: session)
  }

  func sendSOSAlert(facilityId: String, residentId: String) {
    sendMessage([
      "type": "sos_alert",
      "facilityId": facilityId,
      "residentId": residentId,
      "timestamp": ISO8601DateFormatter().string(from: Date()),
    ])
  }

  func sendVitalUpdate(facilityId: String, residentId: String, metric: String, value: Double) {
    sendMessage([
      "type": "vital_update",
      "facilityId": facilityId,
      "residentId": residentId,
      "metric": metric,
      "value": value,
      "timestamp": ISO8601DateFormatter().string(from: Date()),
    ])
  }

  func syncResidentStatus(_ payload: WatchResidentSyncPayload) {
    var residentStatus: [String: Any] = [
      "facilityId": payload.facilityId,
      "residentId": payload.residentId,
      "statusText": payload.statusText,
      "isMonitoringActive": payload.isMonitoringActive,
      "isRecordingIncident": payload.isRecordingIncident,
      "fallRisk": payload.fallRisk,
      "recordedAt": payload.recordedAt,
    ]
    if let heartRate = payload.heartRate { residentStatus["heartRate"] = heartRate }
    if let bloodOxygen = payload.bloodOxygen { residentStatus["bloodOxygen"] = bloodOxygen }
    if let locationName = payload.locationName { residentStatus["locationName"] = locationName }
    if let movementSummary = payload.movementSummary { residentStatus["movementSummary"] = movementSummary }

    let context: [String: Any] = [
      "residentStatus": residentStatus,
      "type": "resident_status",
      "timestamp": payload.recordedAt,
    ]
    updateApplicationContext(context)
  }

  func syncOpenAlerts(_ alerts: [AlertModel], facilityId: String) {
    let formatter = ISO8601DateFormatter()
    let payload = alerts.prefix(10).map {
      WatchAlertSummary(
        id: $0.id,
        residentId: $0.residentId.uuidString,
        type: $0.type,
        status: $0.status,
        priority: $0.priority,
        createdAt: formatter.string(from: $0.createdAt)
      )
    }

    do {
      let data = try JSONEncoder().encode(payload)
      let jsonObject = try JSONSerialization.jsonObject(with: data)
      updateApplicationContext([
        "type": "staff_alert_snapshot",
        "facilityId": facilityId,
        "alerts": jsonObject,
        "timestamp": formatter.string(from: Date()),
      ])
    } catch {
      lastErrorMessage = "Unable to encode watch alert snapshot: \(error.localizedDescription)"
    }
  }

  func sendAlertUpdate(alertJSON: String) {
    sendMessage([
      "type": "alert_update",
      "payload": alertJSON,
      "timestamp": ISO8601DateFormatter().string(from: Date()),
    ])
  }

  func transferUserInfo(_ dict: [String: Any]) {
    guard let session else { return }
    guard session.activationState == .activated else {
      pendingUserInfo.append(dict)
      activateSessionIfNeeded()
      return
    }
    session.transferUserInfo(dict)
    markSyncSuccess()
  }

  private func sendMessage(_ dict: [String: Any]) {
    guard let session else { return }
    guard session.activationState == .activated else {
      pendingUserInfo.append(dict)
      activateSessionIfNeeded()
      return
    }

    if session.isReachable {
      session.sendMessage(dict, replyHandler: nil) { [weak self] error in
        Task { @MainActor in
          self?.lastErrorMessage = error.localizedDescription
          self?.pendingUserInfo.append(dict)
        }
      }
    } else {
      session.transferUserInfo(dict)
    }
    markSyncSuccess()
  }

  private func updateApplicationContext(_ dict: [String: Any]) {
    guard let session else { return }
    latestApplicationContext.merge(dict) { _, new in new }

    guard session.activationState == .activated else {
      pendingApplicationContext.merge(dict) { _, new in new }
      activateSessionIfNeeded()
      return
    }

    do {
      try session.updateApplicationContext(latestApplicationContext)
      markSyncSuccess()
    } catch {
      pendingApplicationContext.merge(dict) { _, new in new }
      lastErrorMessage = error.localizedDescription
    }
  }

  private func flushPendingQueues() {
    guard let session, session.activationState == .activated else { return }

    if !pendingApplicationContext.isEmpty {
      latestApplicationContext.merge(pendingApplicationContext) { _, new in new }
      do {
        try session.updateApplicationContext(latestApplicationContext)
        pendingApplicationContext.removeAll()
        markSyncSuccess()
      } catch {
        lastErrorMessage = error.localizedDescription
      }
    }

    guard !pendingUserInfo.isEmpty else { return }
    let queued = pendingUserInfo
    pendingUserInfo.removeAll()
    for item in queued {
      session.transferUserInfo(item)
    }
    markSyncSuccess()
  }

  private func refreshState(from session: WCSession) {
    activationState = session.activationState
    isReachable = session.isReachable
    isPaired = session.isPaired
    isWatchAppInstalled = session.isWatchAppInstalled
    watchContext = WatchContext(
      isComplicationEnabled: session.isComplicationEnabled,
      isPaired: session.isPaired,
      isWatchAppInstalled: session.isWatchAppInstalled,
      activationState: session.activationState
    )
    NotificationCenter.default.post(name: .watchConnectivityStateDidChange, object: nil)
  }

  private func markSyncSuccess() {
    lastSyncDate = Date()
    lastErrorMessage = nil
  }
}

extension WatchConnectivityService: WCSessionDelegate {
  nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

  nonisolated func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }

  nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    Task { @MainActor in
      refreshState(from: session)
      if let error {
        lastErrorMessage = error.localizedDescription
      }
      flushPendingQueues()
    }
  }

  nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
    Task { @MainActor in
      refreshState(from: session)
    }
  }

  nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    Task { @MainActor in
      lastMessage = message
      markSyncSuccess()
      handleWatchMessage(message)
    }
  }

  nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    Task { @MainActor in
      lastMessage = userInfo
      markSyncSuccess()
      handleWatchMessage(userInfo)
    }
  }

  nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    Task { @MainActor in
      lastMessage = applicationContext
      latestApplicationContext.merge(applicationContext) { _, new in new }
      markSyncSuccess()
    }
  }

  nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
    Task { @MainActor in
      refreshState(from: session)
      flushPendingQueues()
    }
  }

  @MainActor
  private func handleWatchMessage(_ message: [String: Any]) {
    guard let type = message["type"] as? String else { return }
    switch type {
    case "sos_from_watch":
      NotificationCenter.default.post(name: .watchSOSTriggered, object: message)
    case "vital_from_watch":
      NotificationCenter.default.post(name: .watchVitalUpdateReceived, object: message)
    case "request_context":
      let context = buildContextPayload()
      updateApplicationContext(["type": "context_update", "payload": context])
    default:
      break
    }
  }

  @MainActor
  private func buildContextPayload() -> [String: Any] {
    [
      "appName": "AgedCare",
      "statusSummary": statusSummary,
      "isPaired": isPaired,
      "isWatchAppInstalled": isWatchAppInstalled,
      "isReachable": isReachable,
      "timestamp": ISO8601DateFormatter().string(from: Date()),
    ]
  }
}

extension Notification.Name {
  static let watchSOSTriggered = Notification.Name("watchSOSTriggered")
  static let watchVitalUpdateReceived = Notification.Name("watchVitalUpdateReceived")
  static let watchConnectivityStateDidChange = Notification.Name("watchConnectivityStateDidChange")
}
