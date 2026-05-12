import Foundation

public enum SupabaseError: Error {
  case httpError(Int, Data)
  case decodingError(Error)
}

extension SupabaseError {
  fileprivate var rawResponseBody: String? {
    switch self {
    case .httpError(_, let data):
      return String(data: data, encoding: .utf8)
    case .decodingError:
      return nil
    }
  }
}

extension Error {
  func userFacingMessage(fallback: String) -> String {
    if let loginError = self as? LoginError {
      return loginError.errorDescription ?? fallback
    }

    if let configurationError = self as? BackendConfigurationError {
      return configurationError.errorDescription ?? fallback
    }

    if let supabaseError = self as? SupabaseError,
       let body = supabaseError.rawResponseBody,
       Self.looksLikeSchemaOrRPCIssue(body) {
      return "Care records are updating right now. Please try again shortly."
    }

    let description = localizedDescription
    if Self.looksLikeSchemaOrRPCIssue(description) {
      return "Care records are updating right now. Please try again shortly."
    }

    let nsError = self as NSError
    if nsError.domain == NSURLErrorDomain {
      return fallback
    }

    return fallback
  }

  private static func looksLikeSchemaOrRPCIssue(_ message: String) -> Bool {
    let lowered = message.lowercased()
    return lowered.contains("pgrst202")
      || lowered.contains("schema cache")
      || lowered.contains("function")
      || lowered.contains("rpc")
      || lowered.contains("could not find")
      || lowered.contains("does not exist")
  }
}
