import Foundation

enum BackendProvider: String {
  case primary
  case aws
  case cloudflare
}

enum AppHost {
  private static let bundledInfo = Bundle.main.infoDictionary ?? [:]
  private static let environment = ProcessInfo.processInfo.environment

  private static let productionAPIBaseURL = URL(string: "https://agedcare-api.chrsappiah.cloud")!

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
}
