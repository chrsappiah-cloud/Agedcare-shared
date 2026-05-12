import Foundation
import Combine

@MainActor
final class BackendHealthService: ObservableObject {
    static let shared = BackendHealthService()

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

    private let session = URLSession.shared

    var providerDescription: String {
        AppHost.preferredBackendProvider.rawValue.uppercased()
    }

    var endpointDescription: String {
        AppHost.baseURL.absoluteString
    }

    var statusSummary: String {
        switch status {
        case .unknown:
            return "Not checked"
        case .checking:
            return "Checking…"
        case .reachable(let code):
            return "Reachable (\(code))"
        case .misconfigured(let message), .unreachable(let message):
            return message
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
            status = .misconfigured("Supabase key missing")
            lastChecked = Date()
            return
        }

        status = .checking
        var request = URLRequest(url: AppHost.baseURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        do {
            let (_, response) = try await session.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            status = .reachable(code)
        } catch {
            status = .unreachable(error.localizedDescription)
        }
        lastChecked = Date()
    }
}
