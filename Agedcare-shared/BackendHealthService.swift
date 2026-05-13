import Foundation
import Combine

@MainActor
final class BackendHealthService: ObservableObject {
    struct ComponentCheck {
        let isReady: Bool
        let message: String

        static func ready(_ message: String) -> ComponentCheck {
            ComponentCheck(isReady: true, message: message)
        }

        static func unavailable(_ message: String) -> ComponentCheck {
            ComponentCheck(isReady: false, message: message)
        }
    }

    private struct AuthSettings: Decodable {
        struct ExternalProviders: Decodable {
            let email: Bool
        }

        let external: ExternalProviders
        let disableSignup: Bool

        enum CodingKeys: String, CodingKey {
            case external
            case disableSignup = "disable_signup"
        }
    }

    private struct CloudflareHealthResponse: Decodable {
        struct RouteHealth: Decodable {
            let supabase: Bool
            let primaryApi: Bool
            let aiApi: Bool

            enum CodingKeys: String, CodingKey {
                case supabase
                case primaryApi = "primaryApi"
                case aiApi = "aiApi"
            }
        }

        let ok: Bool
        let routes: RouteHealth
    }

    static let shared = BackendHealthService()
    static let requiredRPCs = [
        "get_staff_info",
        "create_fall_alert",
        "create_sos_alert",
        "acknowledge_alert",
        "close_alert",
        "get_facility_stats",
        "get_residents_for_facility",
        "get_fall_summary_for_resident",
        "get_resident_timeline",
        "get_open_alerts_for_facility",
        "create_handoff_request",
        "get_pending_handoffs",
        "resolve_handoff_request",
        "record_vital_event",
        "upsert_incident_media",
    ]

    enum Status {
        case unknown
        case checking
        case reachable(Int)
        case misconfigured(String)
        case unreachable(String)
    }

    @Published private(set) var status: Status = .unknown
    @Published private(set) var lastChecked: Date?
    @Published private(set) var iCloudBackupStatus = "Unknown"
    @Published private(set) var cloudKitBackupStatus = "Unknown"
    @Published private(set) var cloudflareBackupStatus = "Not configured"
    @Published private(set) var middlewareStatus = "Not checked"
    @Published private(set) var authStatus = "Not checked"
    @Published private(set) var databaseStatus = "Not checked"
    @Published private(set) var demoAccessStatus = "Not checked"
    @Published private(set) var liveDemoProfiles: [DemoAccessProfile] = []

    private let session = URLSession.shared

    var providerDescription: String {
        AppHost.preferredBackendProvider.rawValue.uppercased()
    }

    var endpointDescription: String {
        AppHost.baseURL.absoluteString
    }

    var configuredDemoProfiles: [DemoAccessProfile] {
        AppHost.visibleDemoAccessProfiles
    }

    var isDemoAccessReady: Bool {
        !liveDemoProfiles.isEmpty
    }

    var statusSummary: String {
        switch status {
        case .unknown:
            return "Preparing care access"
        case .checking:
            return "Checking care access…"
        case .reachable:
            return "Care access ready"
        case .misconfigured, .unreachable:
            return "Care access unavailable"
        }
    }

    var isHealthy: Bool {
        if case .reachable = status {
            return true
        }
        return false
    }

    func refresh() async {
        iCloudBackupStatus = ICloudBackupStore.shared.isICloudAvailable ? "Available" : "Unavailable"
        cloudflareBackupStatus = AppHost.resolvedCloudflareBaseURL?.absoluteString ?? "Not configured"
        #if canImport(CloudKit)
        do {
            try CloudKitAlertSync.shared?.setup()
            cloudKitBackupStatus = "Ready"
        } catch {
            cloudKitBackupStatus = error.localizedDescription
        }
        #else
        cloudKitBackupStatus = "Unavailable"
        #endif

        guard AppHost.isSupabaseConfigured else {
            status = .misconfigured("Care access unavailable")
            authStatus = "Sign-in unavailable"
            databaseStatus = "Care records unavailable"
            demoAccessStatus = "Preview access unavailable"
            middlewareStatus = "Preview access unavailable"
            liveDemoProfiles = []
            lastChecked = Date()
            return
        }

        status = .checking

        let middlewareCheck = await checkMiddleware()
        middlewareStatus = middlewareCheck.message

        let authCheck = await checkAuth()
        authStatus = authCheck.message

        let databaseCheck = await checkDatabaseRPCs()
        databaseStatus = databaseCheck.message

        liveDemoProfiles = await validateDemoProfiles(authReady: authCheck.isReady, databaseReady: databaseCheck.isReady)
        demoAccessStatus = demoAccessSummary(
            authReady: authCheck.isReady,
            databaseReady: databaseCheck.isReady,
            middlewareReady: middlewareCheck.isReady,
            liveProfiles: liveDemoProfiles
        )

        if middlewareCheck.isReady || authCheck.isReady || databaseCheck.isReady {
            status = .reachable(200)
        } else {
            status = .unreachable(databaseCheck.message)
        }

        lastChecked = Date()
    }

    private func checkMiddleware() async -> ComponentCheck {
        guard let cloudflareBaseURL = AppHost.resolvedCloudflareBaseURL else {
            return .unavailable("Preview access preparing")
        }

        var request = URLRequest(url: cloudflareBaseURL.appendingPathComponent("healthz"))
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                return .unavailable("Preview access unavailable")
            }

            let health = try JSONDecoder().decode(CloudflareHealthResponse.self, from: data)
            guard health.ok else {
                return .unavailable("Preview access unavailable")
            }

            let routesReady = health.routes.supabase || health.routes.primaryApi || health.routes.aiApi
            return routesReady ? .ready("Preview access ready") : .unavailable("Preview access unavailable")
        } catch {
            return .unavailable("Preview access unavailable")
        }
    }

    private func checkAuth() async -> ComponentCheck {
        var request = URLRequest(url: AppHost.supabaseBaseURL.appendingPathComponent("auth/v1/settings"))
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue(AppHost.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                return .unavailable("Sign-in unavailable")
            }

            let settings = try JSONDecoder().decode(AuthSettings.self, from: data)
            guard settings.external.email else {
                return .unavailable("Sign-in unavailable")
            }

            return .ready(settings.disableSignup ? "Sign-in ready" : "Sign-in ready")
        } catch {
            return .unavailable("Sign-in unavailable")
        }
    }

    private func checkDatabaseRPCs() async -> ComponentCheck {
        let requestFactory = BackendRequestFactory(
            baseURL: AppHost.supabaseBaseURL,
            apiKey: AppHost.supabaseAnonKey,
            accessTokenProvider: { nil }
        )

        var missing = [String]()

        for rpc in Self.requiredRPCs {
            do {
                var request = try requestFactory.makeRPCRequest(rpc, authorized: false)
                try request.encodeJSONBody([String: String]())
                request.timeoutInterval = 10

                let (data, response) = try await session.data(for: request)
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                if code == 404, String(data: data, encoding: .utf8)?.contains("PGRST202") == true {
                    missing.append(rpc)
                }
            } catch {
                return .unavailable("Care records unavailable")
            }
        }

        guard missing.isEmpty else {
            return .unavailable("Care records preparing")
        }

        return .ready("Care records ready")
    }

    private func validateDemoProfiles(authReady: Bool, databaseReady: Bool) async -> [DemoAccessProfile] {
        guard AppHost.previewAccessEnabled else { return [] }
        guard authReady, databaseReady else { return [] }

        var liveProfiles = [DemoAccessProfile]()
        for profile in AppHost.visibleDemoAccessProfiles where await isDemoProfileLive(profile) {
            liveProfiles.append(profile)
        }
        return liveProfiles
    }

    private func isDemoProfileLive(_ profile: DemoAccessProfile) async -> Bool {
        do {
            let loginResponse = try await login(profile)
            guard let userID = UUID(uuidString: loginResponse.user.id) else {
                return false
            }

            let requestFactory = BackendRequestFactory(
                baseURL: AppHost.supabaseBaseURL,
                apiKey: AppHost.supabaseAnonKey,
                accessTokenProvider: { loginResponse.accessToken }
            )
            var request = try requestFactory.makeRPCRequest("get_staff_info")
            try request.encodeJSONBody(["p_user_id": loginResponse.user.id])
            request.timeoutInterval = 10

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                return false
            }

            let staffInfo = try JSONDecoder().decode(StaffInfoResponse.self, from: data)
            return UUID(uuidString: staffInfo.id) == userID || !staffInfo.facilityId.isEmpty
        } catch {
            return false
        }
    }

    private func login(_ profile: DemoAccessProfile) async throws -> LoginResponse {
        let requestFactory = BackendRequestFactory(
            baseURL: AppHost.supabaseBaseURL,
            apiKey: AppHost.supabaseAnonKey,
            accessTokenProvider: { nil }
        )

        var request = try requestFactory.makeAuthRequest(path: "auth/v1/token")
        try request.encodeJSONBody([
            "email": profile.email,
            "password": profile.password,
            "grant_type": "password",
        ])
        request.timeoutInterval = 10

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw LoginError.invalidCredentials
        }
        return try JSONDecoder().decode(LoginResponse.self, from: data)
    }

    private func demoAccessSummary(
        authReady: Bool,
        databaseReady: Bool,
        middlewareReady: Bool,
        liveProfiles: [DemoAccessProfile]
    ) -> String {
        guard AppHost.previewAccessEnabled else { return "Preview access hidden in this release" }
        guard authReady else { return "Preparing preview access" }
        guard databaseReady else { return "Preparing preview access" }
        guard !liveProfiles.isEmpty else { return "Preview access unavailable" }
        if AppHost.resolvedCloudflareBaseURL != nil, !middlewareReady {
            return "Preparing preview access"
        }
        return "Preview access ready"
    }
}
