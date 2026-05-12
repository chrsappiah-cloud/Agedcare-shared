import Foundation

public final class SupabaseClient {
  private let config: SupabaseConfig
  private let session: URLSession
  private let accessTokenProvider: () -> String?
  private let requestFactory: BackendRequestFactory

  public init(
    config: SupabaseConfig,
    session: URLSession = .shared,
    accessTokenProvider: @escaping () -> String?
  ) {
    self.config = config
    self.session = session
    self.accessTokenProvider = accessTokenProvider
    self.requestFactory = BackendRequestFactory(
      baseURL: config.baseURL,
      apiKey: config.apiKey,
      accessTokenProvider: accessTokenProvider
    )
  }

  public func rpc<T: Decodable>(_ name: String, payload: Encodable) async throws -> T {
    let data = try await performRPC(name, payload: payload)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    do {
      return try decoder.decode(T.self, from: data)
    } catch {
      throw SupabaseError.decodingError(error)
    }
  }

  public func rpcVoid(_ name: String, payload: Encodable) async throws {
    _ = try await performRPC(name, payload: payload)
  }

  private func performRPC(_ name: String, payload: Encodable) async throws -> Data {
    var request = try requestFactory.makeRPCRequest(name, authorized: accessTokenProvider() != nil)

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    try request.encodeJSONBody(AnyEncodable(payload), encoder: encoder)

    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
      throw SupabaseError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1, data)
    }
    return data
  }
}

public struct AnyEncodable: Encodable {
  private let encodeFunc: (Encoder) throws -> Void

  public init(_ encodable: Encodable) {
    self.encodeFunc = encodable.encode
  }

  public func encode(to encoder: Encoder) throws {
    try encodeFunc(encoder)
  }
}
