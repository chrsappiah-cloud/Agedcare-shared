import Foundation

enum StaffAccessSource: String {
  case backend
  case localTesting

  var label: String {
    switch self {
    case .backend: return "Live backend"
    case .localTesting: return "Subscription testing plan"
    }
  }
}

struct StaffUserModel {
  let id: UUID
  let facilityId: UUID
  let role: String
  let displayName: String?
  let email: String?
  let subscriptionTier: SubscriptionTier
  let betaTrack: BetaTrack?
  let accessSource: StaffAccessSource
  let accessNotes: String?

  init(
    id: UUID,
    facilityId: UUID,
    role: String,
    displayName: String?,
    email: String?,
    subscriptionTier: SubscriptionTier = .starter,
    betaTrack: BetaTrack? = nil,
    accessSource: StaffAccessSource = .backend,
    accessNotes: String? = nil
  ) {
    self.id = id
    self.facilityId = facilityId
    self.role = role
    self.displayName = displayName
    self.email = email
    self.subscriptionTier = subscriptionTier
    self.betaTrack = betaTrack
    self.accessSource = accessSource
    self.accessNotes = accessNotes
  }
}

struct ResidentModel: Identifiable {
  let id: UUID
  let facilityId: UUID
  let name: String
  let riskLevel: String?
  let dateOfBirth: Date?
}

struct TimelineItem: Identifiable {
  let id: UUID
  let kind: TimelineKind
  let timestamp: Date
  let summary: String

  enum TimelineKind {
    case fall
    case vital
  }
}

enum SessionState {
  case onboarding
  case loading
  case resident(facilityId: UUID, residentId: UUID)
  case staff(StaffUserModel)
}

struct LoginResponse: Decodable {
  let accessToken: String
  let user: LoginUser

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case user
  }
}

struct LoginUser: Decodable {
  let id: String
  let email: String
  let role: String
}
