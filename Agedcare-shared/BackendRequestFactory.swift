import Foundation

enum BackendConfigurationError: LocalizedError {
  case missingAPIKey
  case missingAccessToken

  var errorDescription: String? {
    switch self {
    case .missingAPIKey:
      return "Backend configuration is incomplete: Supabase anon key is missing."
    case .missingAccessToken:
      return "Authentication required. Please sign in again."
    }
  }
}

struct BackendRequestFactory {
  private let baseURL: URL
  private let apiKey: String
  private let accessTokenProvider: () -> String?

  init(
    baseURL: URL = AppHost.baseURL,
    apiKey: String = AppHost.supabaseAnonKey,
    accessTokenProvider: @escaping () -> String? = { SupabaseAuthStore.shared.accessToken }
  ) {
    self.baseURL = baseURL
    self.apiKey = apiKey
    self.accessTokenProvider = accessTokenProvider
  }

  func makeRequest(
    path: String,
    method: String = "GET",
    requiresAPIKey: Bool = false,
    authorized: Bool = false
  ) throws -> URLRequest {
    var request = URLRequest(url: url(for: path))
    request.httpMethod = method
    request.setJSONHeaders()

    if requiresAPIKey {
      guard !apiKey.isEmpty else { throw BackendConfigurationError.missingAPIKey }
      request.setValue(apiKey, forHTTPHeaderField: "apikey")
    }

    if authorized {
      guard let token = accessTokenProvider() else { throw BackendConfigurationError.missingAccessToken }
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    return request
  }

  func makeAuthRequest(path: String) throws -> URLRequest {
    try makeRequest(path: path, method: "POST", requiresAPIKey: true)
  }

  func makeRPCRequest(_ name: String, authorized: Bool = true) throws -> URLRequest {
    try makeRequest(path: "rest/v1/rpc/\(name)", method: "POST", requiresAPIKey: true, authorized: authorized)
  }

  private func url(for path: String) -> URL {
    let trimmedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
    return baseURL.appendingPathComponent(trimmedPath)
  }
}

extension URLRequest {
  mutating func setJSONHeaders() {
    setValue("application/json", forHTTPHeaderField: "Content-Type")
    setValue("application/json", forHTTPHeaderField: "Accept")
  }

  mutating func encodeJSONBody<T: Encodable>(_ body: T, encoder: JSONEncoder = JSONEncoder()) throws {
    httpBody = try encoder.encode(body)
  }
}
