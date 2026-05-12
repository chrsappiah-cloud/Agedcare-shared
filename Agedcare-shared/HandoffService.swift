import Foundation
import Combine
@preconcurrency import UserNotifications
import UIKit

enum HandoffAction: Codable, Equatable {
  case requestStaff(facilityId: String, residentId: String, residentName: String)
  case staffTakeover(staffId: String, staffName: String, facilityId: String)
  case sosAlert(facilityId: String, residentId: String)
  case vitalReading(facilityId: String, residentId: String, metric: String, value: Double)

  var notificationTitle: String {
    switch self {
    case .requestStaff: return "Resident Needs Assistance"
    case .staffTakeover: return "Staff Connected"
    case .sosAlert: return "SOS Alert"
    case .vitalReading: return "Vital Reading"
    }
  }

  var notificationBody: String {
    switch self {
    case .requestStaff(_, _, let name): return "\(name) has requested a staff member"
    case .staffTakeover(_, let name, _): return "\(name) is now monitoring this device"
    case .sosAlert(_, _): return "A resident has triggered an SOS alert"
    case .vitalReading(_, _, let metric, let value): return "\(metric): \(value)"
    }
  }
}

@MainActor
final class HandoffService: NSObject, ObservableObject {
  static let shared = HandoffService()

  @Published var pendingHandoff: HandoffAction?
  @Published var activeTransferToken: String?
  @Published var pendingRequests: [HandoffRequest] = []
  @Published var routingResidentId: UUID?
  @Published var lastErrorMessage: String?

  struct HandoffRequest: Identifiable, Decodable {
    let id: Int
    let facilityId: String
    let residentId: String
    let createdAt: String?
    let notes: String?
  }

  private var handoffCallback: ((HandoffAction) -> Void)?
  private let requestFactory = BackendRequestFactory()
  private var pollTask: Task<Void, Never>?

  func startListening(callback: @escaping (HandoffAction) -> Void) {
    handoffCallback = callback
    registerForPushHandoffs()
  }

  func startPolling(facilityId: String) {
    pollTask?.cancel()
    pollTask = Task { [weak self] in
      while !Task.isCancelled {
        await self?.fetchPendingRequests(facilityId: facilityId)
        if let request = self?.pendingRequests.first,
           self?.pendingHandoff == nil {
          self?.pendingHandoff = .requestStaff(
            facilityId: request.facilityId,
            residentId: request.residentId,
            residentName: request.notes ?? "Resident"
          )
        }
        try? await Task.sleep(nanoseconds: 10_000_000_000)
      }
    }
  }

  func stopPolling() {
    pollTask?.cancel()
    pollTask = nil
  }

  func routeToResident(residentId: String) {
    guard let uuid = UUID(uuidString: residentId) else { return }
    routingResidentId = uuid
  }

  func requestStaff(facilityId: String, residentId: String, residentName: String) async {
    let action = HandoffAction.requestStaff(facilityId: facilityId, residentId: residentId, residentName: residentName)
    pendingHandoff = action
    postLocalNotification(for: action)
    handoffCallback?(action)
    do {
      _ = try await callRPC("create_handoff_request", body: [
        "p_facility_id": facilityId,
        "p_resident_id": residentId,
        "p_notes": "\(residentName) requested staff assistance",
      ])
      lastErrorMessage = nil
    } catch {
      lastErrorMessage = error.localizedDescription
    }
  }

  func staffTakeover(staffId: String, staffName: String, facilityId: String, session: SessionViewModel) async {
    let action = HandoffAction.staffTakeover(staffId: staffId, staffName: staffName, facilityId: facilityId)
    pendingHandoff = nil
    postLocalNotification(for: action)
    do {
      _ = try await callRPC("resolve_handoff_request", body: ["p_alert_id": activeTransferToken ?? ""])
      lastErrorMessage = nil
    } catch {
      lastErrorMessage = error.localizedDescription
    }
    clearHandoff()
    handoffCallback?(action)
  }

  func fetchPendingRequests(facilityId: String) async {
    do {
      let data = try await callRPC("get_pending_handoffs", body: ["p_facility_id": facilityId])
      if let requests = try? JSONDecoder().decode([HandoffRequest].self, from: data) {
        pendingRequests = requests
      }
      lastErrorMessage = nil
    } catch {
      lastErrorMessage = error.localizedDescription
    }
  }

  func acceptHandoff(token: String) {
    activeTransferToken = token
  }

  func clearHandoff() {
    pendingHandoff = nil
    activeTransferToken = nil
  }

  @discardableResult
  private func callRPC(_ name: String, body: [String: Any], authorized: Bool = false) async throws -> Data {
    var req = try requestFactory.makeRPCRequest(name, authorized: authorized)
    req.httpBody = try JSONSerialization.data(withJSONObject: body)
    let (data, resp) = try await URLSession.shared.data(for: req)
    guard let http = resp as? HTTPURLResponse, http.statusCode < 300 else {
      throw SupabaseError.httpError((resp as? HTTPURLResponse)?.statusCode ?? -1, data)
    }
    return data
  }

  private func registerForPushHandoffs() {
    UNUserNotificationCenter.current().delegate = self
  }

  private func postLocalNotification(for action: HandoffAction) {
    let content = UNMutableNotificationContent()
    content.title = action.notificationTitle
    content.body = action.notificationBody
    content.sound = .default
    content.userInfo = handoffUserInfo(for: action)
    content.categoryIdentifier = "HANDOFF"
    let request = UNNotificationRequest(
      identifier: "handoff_\(UUID().uuidString)",
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
  }

  private func handoffUserInfo(for action: HandoffAction) -> [String: Any] {
    var info: [String: Any] = ["handoff": true]
    switch action {
    case .requestStaff(let fid, let rid, let name):
      info["action"] = "requestStaff"
      info["facilityId"] = fid
      info["residentId"] = rid
      info["residentName"] = name
    case .staffTakeover(let sid, let sname, let fid):
      info["action"] = "staffTakeover"
      info["staffId"] = sid
      info["staffName"] = sname
      info["facilityId"] = fid
    case .sosAlert(let fid, let rid):
      info["action"] = "sosAlert"
      info["facilityId"] = fid
      info["residentId"] = rid
    case .vitalReading(let fid, let rid, let metric, let value):
      info["action"] = "vitalReading"
      info["facilityId"] = fid
      info["residentId"] = rid
      info["metric"] = metric
      info["value"] = value
    }
    return info
  }
}

nonisolated extension HandoffService: UNUserNotificationCenterDelegate {
  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    guard userInfo["handoff"] as? Bool == true else {
      completionHandler()
      return
    }
    let action = userInfo["action"] as? String
    let facilityId = userInfo["facilityId"] as? String
    let residentId = userInfo["residentId"] as? String
    let residentName = userInfo["residentName"] as? String
    let staffId = userInfo["staffId"] as? String
    let staffName = userInfo["staffName"] as? String
    Task { @MainActor in
      handleHandoffNotification(
        action: action,
        facilityId: facilityId,
        residentId: residentId,
        residentName: residentName,
        staffId: staffId,
        staffName: staffName
      )
      completionHandler()
    }
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let userInfo = notification.request.content.userInfo
    if userInfo["handoff"] as? Bool == true {
      completionHandler([.banner, .sound, .list])
    } else {
      completionHandler([.banner, .sound])
    }
  }

  @MainActor
  private func handleHandoffNotification(
    action: String?,
    facilityId: String?,
    residentId: String?,
    residentName: String?,
    staffId: String?,
    staffName: String?
  ) {
    guard let action else { return }
    switch action {
    case "requestStaff":
      if let facilityId, let residentId {
        pendingHandoff = .requestStaff(
          facilityId: facilityId,
          residentId: residentId,
          residentName: residentName ?? "Resident"
        )
      }
    case "staffTakeover":
      if let staffId, let staffName, let facilityId {
        pendingHandoff = .staffTakeover(staffId: staffId, staffName: staffName, facilityId: facilityId)
      }
    case "sosAlert":
      if let facilityId, let residentId {
        pendingHandoff = .sosAlert(facilityId: facilityId, residentId: residentId)
      }
    default:
      break
    }
  }
}
