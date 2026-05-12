import Foundation

enum TestingAccessKind: String {
  case creator
  case administrator
  case tester

  var label: String {
    switch self {
    case .creator: return "Creator"
    case .administrator: return "Administrator"
    case .tester: return "Tester"
    }
  }
}

struct DemoAccessProfile: Identifiable, Equatable {
  let title: String
  let email: String
  let password: String

  var id: String { email }
}

struct TestingAccessProfile: Identifiable, Equatable {
  let title: String
  let email: String
  let role: String
  let displayName: String
  let subscriptionTier: SubscriptionTier
  let betaTrack: BetaTrack
  let accessKind: TestingAccessKind
  let facilityId: UUID
  let accessNotes: String

  var id: String { email }
}

enum BackendProvider: String {
  case primary
  case aws
  case cloudflare
}

enum AppHost {
  private static let bundledInfo = Bundle.main.infoDictionary ?? [:]
  private static let environment = ProcessInfo.processInfo.environment

  private static let productionAPIBaseURL = URL(string: "https://agedcare-api.chrsappiah.cloud")!
  private static let defaultDemoProfiles = [
    DemoAccessProfile(title: "Admin — Dr. Sarah Chen", email: "admin@gvcare.com", password: "password"),
    DemoAccessProfile(title: "Nurse — John Smith", email: "nurse@gvcare.com", password: "password"),
    DemoAccessProfile(title: "Carer — Emma Davis", email: "carer@gvcare.com", password: "password"),
  ]
  private static let defaultTestingAccessProfiles = [
    TestingAccessProfile(
      title: "Creator Access",
      email: WCSMarketingConfig.supportEmail,
      role: "creator",
      displayName: "Dr Christopher Appiah-Thompson",
      subscriptionTier: .careTeam,
      betaTrack: .care,
      accessKind: .creator,
      facilityId: UUID(uuidString: "99999999-1111-4111-8111-111111111111")!,
      accessNotes: "Founder-level beta validation with full Care Team plan access."
    ),
    TestingAccessProfile(
      title: "Administrator Access",
      email: "admin@gvcare.com",
      role: "admin",
      displayName: "Dr Sarah Chen",
      subscriptionTier: .careTeam,
      betaTrack: .care,
      accessKind: .administrator,
      facilityId: UUID(uuidString: "99999999-2222-4222-8222-222222222222")!,
      accessNotes: "Care Team pilot administrator access for multi-user and reporting flows."
    ),
    TestingAccessProfile(
      title: "Care Team Tester",
      email: "teamtester@gvcare.com",
      role: "tester",
      displayName: "John Smith",
      subscriptionTier: .careTeam,
      betaTrack: .care,
      accessKind: .tester,
      facilityId: UUID(uuidString: "99999999-3333-4333-8333-333333333333")!,
      accessNotes: "Institutional pilot tester mapped to the Care Team plan."
    ),
    TestingAccessProfile(
      title: "Care Pro Tester",
      email: "protester@gvcare.com",
      role: "tester",
      displayName: "Emma Davis",
      subscriptionTier: .carePro,
      betaTrack: .care,
      accessKind: .tester,
      facilityId: UUID(uuidString: "99999999-4444-4444-8444-444444444444")!,
      accessNotes: "Professional-carer beta tester mapped to the Care Pro plan."
    ),
    TestingAccessProfile(
      title: "Starter Tester",
      email: "startertester@gvcare.com",
      role: "tester",
      displayName: "Family Carer Preview",
      subscriptionTier: .starter,
      betaTrack: .care,
      accessKind: .tester,
      facilityId: UUID(uuidString: "99999999-5555-4555-8555-555555555555")!,
      accessNotes: "Starter-tier tester for the free family-carer beta path."
    ),
  ]

  static var baseURL: URL {
    switch preferredBackendProvider {
    case .aws:
      return awsBaseURL ?? configuredBaseURL ?? cloudflareBaseURL ?? productionAPIBaseURL
    case .cloudflare:
      return cloudflareBaseURL ?? configuredBaseURL ?? awsBaseURL ?? productionAPIBaseURL
    case .primary:
      return configuredBaseURL ?? cloudflareBaseURL ?? awsBaseURL ?? productionAPIBaseURL
    }
  }

  static var supabaseBaseURL: URL {
    resolvedURL(
      environment["SUPABASE_BASE_URL"]
        ?? value(forInfoKeys: ["SupabaseBaseURL", "SUPABASE_BASE_URL", "BackendBaseURL", "SupabaseAPIBaseURL"])
    ) ?? configuredBaseURL ?? productionAPIBaseURL
  }

  static var supabaseAnonKey: String {
    trimmedString(
      environment["SUPABASE_ANON_KEY"]
        ?? value(forInfoKeys: ["SupabaseAnonKey", "SUPABASE_ANON_KEY"])
    ) ?? ""
  }

  static var preferredBackendProvider: BackendProvider {
    BackendProvider(
      rawValue: trimmedString(
        environment["BACKEND_PROVIDER"]
          ?? value(forInfoKeys: ["BackendProvider", "BACKEND_PROVIDER"])
      )?.lowercased() ?? BackendProvider.primary.rawValue
    ) ?? .primary
  }

  static var isSupabaseConfigured: Bool {
    let key = supabaseAnonKey
    return !key.isEmpty && !key.localizedCaseInsensitiveContains("placeholder")
  }

  static var hasCloudflareBackup: Bool {
    cloudflareBaseURL != nil
  }

  static var hasAWSBackup: Bool {
    awsBaseURL != nil
  }

  static var resolvedCloudflareBaseURL: URL? {
    cloudflareBaseURL
  }

  static var demoAccessProfiles: [DemoAccessProfile] {
    defaultDemoProfiles
  }

  static var testingAccessProfiles: [TestingAccessProfile] {
    defaultTestingAccessProfiles
  }

  static var previewAccessEnabled: Bool {
    if let override = configuredPreviewAccessOverride {
      return override
    }
    #if DEBUG
    return true
    #else
    if environment["XCTestConfigurationFilePath"] != nil {
      return true
    }
    guard let receiptURL = Bundle.main.appStoreReceiptURL else {
      return true
    }
    return receiptURL.lastPathComponent == "sandboxReceipt"
    #endif
  }

  static var visibleDemoAccessProfiles: [DemoAccessProfile] {
    previewAccessEnabled ? defaultDemoProfiles : []
  }

  static var visibleTestingAccessProfiles: [TestingAccessProfile] {
    previewAccessEnabled ? defaultTestingAccessProfiles : []
  }

  static var defaultResidentDemoFacilityID: UUID? {
    defaultTestingAccessProfiles.first(where: { $0.accessKind == .tester })?.facilityId
      ?? defaultTestingAccessProfiles.first?.facilityId
  }

  static func testingAccessProfile(email: String) -> TestingAccessProfile? {
    let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return defaultTestingAccessProfiles.first { $0.email.lowercased() == normalizedEmail }
  }

  private static var configuredBaseURL: URL? {
    resolvedURL(
      environment["BACKEND_BASE_URL"]
        ?? environment["API_BASE_URL"]
        ?? value(forInfoKeys: ["BackendBaseURL", "APIBaseURL", "SupabaseBaseURL"])
    )
  }

  private static var awsBaseURL: URL? {
    resolvedURL(
      environment["AWS_API_BASE_URL"]
        ?? value(forInfoKeys: ["AWSAPIBaseURL", "AwsApiBaseURL"])
    )
  }

  private static var cloudflareBaseURL: URL? {
    resolvedURL(
      environment["CLOUDFLARE_API_BASE_URL"]
        ?? value(forInfoKeys: ["CloudflareAPIBaseURL", "CLOUDFLARE_API_BASE_URL"])
    )
  }

  private static var configuredPreviewAccessOverride: Bool? {
    boolValue(
      environment["PREVIEW_ACCESS_ENABLED"]
        ?? value(forInfoKeys: ["PreviewAccessEnabled", "PREVIEW_ACCESS_ENABLED"])
    )
  }

  private static func value(forInfoKeys keys: [String]) -> String? {
    for key in keys {
      if let value = bundledInfo[key] as? String, let trimmed = trimmedString(value) {
        return trimmed
      }
    }
    return nil
  }

  private static func resolvedURL(_ value: String?) -> URL? {
    guard let trimmed = trimmedString(value) else { return nil }
    return URL(string: trimmed)
  }

  private static func trimmedString(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private static func boolValue(_ value: String?) -> Bool? {
    guard let normalized = trimmedString(value)?.lowercased() else { return nil }
    switch normalized {
    case "1", "true", "yes", "on":
      return true
    case "0", "false", "no", "off":
      return false
    default:
      return nil
    }
  }
}
