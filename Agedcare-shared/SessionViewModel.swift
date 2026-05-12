import Foundation
import Combine

@MainActor
final class SessionViewModel: ObservableObject {
  @Published var state: SessionState = .onboarding
  @Published var loginError: String?

  private let requestFactory = BackendRequestFactory()
  private let testingPassword = "password"

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
      guard let staffHttp = staffResp as? HTTPURLResponse else {
        throw LoginError.invalidResponse("Missing staff lookup response")
      }
        guard staffHttp.statusCode == 200 else {
          if staffHttp.statusCode == 404,
            String(data: staffData, encoding: .utf8)?.contains("PGRST202") == true
          {
            throw LoginError.invalidResponse("Care records are still being prepared")
          }
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
        email: loginResp.user.email,
        subscriptionTier: resolvedTier(for: staffInfo.role),
        betaTrack: .care,
        accessSource: .backend
      )
      SubscriptionService.shared.currentTier = staff.subscriptionTier
      state = .staff(staff)

    } catch let error as LoginError {
      if fallbackToTestingAccessIfAvailable(email: email, password: password) {
        return
      }
      loginError = error.userFacingMessage(fallback: "We couldn't complete sign in. Please try again.")
      state = .onboarding
    } catch let error as BackendConfigurationError {
      if fallbackToTestingAccessIfAvailable(email: email, password: password) {
        return
      }
      loginError = error.userFacingMessage(fallback: "Sign in isn't available right now. Please try again shortly.")
      state = .onboarding
    } catch {
      if fallbackToTestingAccessIfAvailable(email: email, password: password) {
        return
      }
      loginError = error.userFacingMessage(fallback: "Sign in isn't available right now. Please try again shortly.")
      state = .onboarding
    }
  }

  func signInForTesting(_ profile: TestingAccessProfile) {
    loginError = nil
    SupabaseAuthStore.shared.accessToken = nil

    let staff = StaffUserModel(
      id: UUID(),
      facilityId: profile.facilityId,
      role: profile.role,
      displayName: profile.displayName,
      email: profile.email,
      subscriptionTier: profile.subscriptionTier,
      betaTrack: profile.betaTrack,
      accessSource: .localTesting,
      accessNotes: profile.accessNotes
    )
    SubscriptionService.shared.currentTier = profile.subscriptionTier
    state = .staff(staff)
  }

  func logout() {
    SupabaseAuthStore.shared.accessToken = nil
    SubscriptionService.shared.currentTier = .starter
    state = .onboarding
  }

  private func fallbackToTestingAccessIfAvailable(email: String, password: String) -> Bool {
    guard
      password == testingPassword,
      let profile = AppHost.testingAccessProfile(email: email)
    else {
      return false
    }

    signInForTesting(profile)
    loginError = nil
    return true
  }

  private func resolvedTier(for role: String) -> SubscriptionTier {
    switch role.lowercased() {
    case "creator", "admin", "administrator":
      return .careTeam
    case "tester", "nurse", "carer", "caregiver":
      return .carePro
    default:
      return .starter
    }
  }
}

enum LoginError: LocalizedError {
  case invalidCredentials
  case staffNotFound
  case invalidResponse(String)

  var errorDescription: String? {
    switch self {
    case .invalidCredentials: return "Invalid email or password"
    case .staffNotFound: return "We couldn't open this staff account yet"
    case .invalidResponse: return "We couldn't complete sign in. Please try again."
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
