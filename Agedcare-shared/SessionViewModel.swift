import Foundation
import Combine

@MainActor
final class SessionViewModel: ObservableObject {
  @Published var state: SessionState = .onboarding
  @Published var loginError: String?

  private let requestFactory = BackendRequestFactory()

  func setResident(facilityId: UUID, residentId: UUID) {
    UserDefaults.standard.set(facilityId.uuidString, forKey: "last_facility_id")
    UserDefaults.standard.set(residentId.uuidString, forKey: "last_resident_id")
    state = .resident(facilityId: facilityId, residentId: residentId)
  }

  /// Returns the last-used resident session if one was previously configured on this device.
  var savedResidentSession: (facilityId: UUID, residentId: UUID)? {
    guard
      let fidStr = UserDefaults.standard.string(forKey: "last_facility_id"),
      let ridStr = UserDefaults.standard.string(forKey: "last_resident_id"),
      let facilityId = UUID(uuidString: fidStr),
      let residentId = UUID(uuidString: ridStr)
    else { return nil }
    return (facilityId, residentId)
  }

  func login(email: String, password: String) async {
    state = .loading
    loginError = nil

    do {
      // 1. Authenticate
      var req = try requestFactory.makeAuthRequest(path: "auth/v1/token")
      let body: [String: String] = [
        "email": email, "password": password, "grant_type": "password",
      ]
      try req.encodeJSONBody(body)

      let (data, resp) = try await URLSession.shared.data(for: req)
      guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
        throw LoginError.invalidCredentials
      }

      let loginResp = try JSONDecoder().decode(LoginResponse.self, from: data)
      SupabaseAuthStore.shared.accessToken = loginResp.accessToken

      // 2. Fetch staff info
      guard let userId = UUID(uuidString: loginResp.user.id) else {
        throw LoginError.invalidResponse("Invalid user ID format")
      }
      var rpcReq = try requestFactory.makeRPCRequest("get_staff_info")
      let rpcBody: [String: String] = ["p_user_id": loginResp.user.id]
      try rpcReq.encodeJSONBody(rpcBody)

      let (staffData, staffResp) = try await URLSession.shared.data(for: rpcReq)
      guard let staffHttp = staffResp as? HTTPURLResponse, staffHttp.statusCode == 200 else {
        throw LoginError.staffNotFound
      }

      let staffInfo = try JSONDecoder().decode(StaffInfoResponse.self, from: staffData)
      guard let facilityId = UUID(uuidString: staffInfo.facilityId) else {
        throw LoginError.invalidResponse("Invalid facility ID format")
      }
      let staff = StaffUserModel(
        id: userId,
        facilityId: facilityId,
        role: staffInfo.role,
        displayName: staffInfo.displayName,
        email: loginResp.user.email
      )
      state = .staff(staff)

    } catch let error as LoginError {
      loginError = error.localizedDescription
      state = .onboarding
    } catch let error as BackendConfigurationError {
      loginError = error.localizedDescription
      state = .onboarding
    } catch {
      loginError = "Connection failed. Check the server."
      state = .onboarding
    }
  }

  func logout() {
    SupabaseAuthStore.shared.accessToken = nil
    state = .onboarding
  }
}

enum LoginError: LocalizedError {
  case invalidCredentials
  case staffNotFound
  case invalidResponse(String)

  var errorDescription: String? {
    switch self {
    case .invalidCredentials: return "Invalid email or password"
    case .staffNotFound: return "Staff account not found"
    case .invalidResponse(let msg): return "Server error: \(msg)"
    }
  }
}

struct StaffInfoResponse: Decodable {
  let id: String
  let facilityId: String
  let role: String
  let displayName: String?

  enum CodingKeys: String, CodingKey {
    case id
    case facilityId = "facility_id"
    case role
    case displayName = "display_name"
  }
}
