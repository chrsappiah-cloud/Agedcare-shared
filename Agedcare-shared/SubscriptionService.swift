import Foundation
import StoreKit
import Combine

enum SubscriptionTier: String, CaseIterable, Identifiable {
    case starter = "starter"
    case carePro = "care_pro"
    case careTeam = "care_team"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .starter: return "Starter"
        case .carePro: return "Care Pro"
        case .careTeam: return "Care Team"
        }
    }

    var subtitle: String {
        switch self {
        case .starter: return "For family carers"
        case .carePro: return "For individual & professional carers"
        case .careTeam: return "For organizations & care teams"
        }
    }

    var icon: String {
        switch self {
        case .starter: return "heart.circle.fill"
        case .carePro: return "stethoscope"
        case .careTeam: return "building.2.fill"
        }
    }

    var features: [String] {
        switch self {
        case .starter:
            return [
                "Daily routines & reminders",
                "Mood & wellbeing logs",
                "1 care profile",
                "Basic calming activities",
            ]
        case .carePro:
            return [
                "Everything in Starter",
                "Unlimited care profiles",
                "Weekly caregiver summaries",
                "Exportable PDF reports",
                "Shared care notes",
                "Premium activity packs",
                "Smart reminder templates",
            ]
        case .careTeam:
            return [
                "Everything in Care Pro",
                "Multi-user staff access",
                "Staff activity reporting",
                "Shared care plans",
                "Onboarding support",
                "Admin dashboard",
                "Priority support",
            ]
        }
    }

    var priceDisplay: String {
        switch self {
        case .starter: return "Free"
        case .carePro: return "$9.99/mo"
        case .careTeam: return "Custom pricing"
        }
    }

    var productId: String? {
        switch self {
        case .starter: return nil
        case .carePro: return "wcs.Agedcare_shared.care_pro_monthly"
        case .careTeam: return "wcs.Agedcare_shared.care_team_annual"
        }
    }

    static func from(productId: String) -> SubscriptionTier? {
        switch productId {
        case SubscriptionTier.carePro.productId:
            return .carePro
        case SubscriptionTier.careTeam.productId:
            return .careTeam
        default:
            return nil
        }
    }

    static func from(serverValue: String) -> SubscriptionTier? {
        SubscriptionTier(rawValue: serverValue.lowercased())
    }
}

private struct ReceiptValidationRequest: Encodable {
    let receiptData: String
    let preferredProductID: String?
}

private struct ReceiptValidationResponse: Decodable {
    let valid: Bool
    let isActive: Bool
    let status: Int
    let environment: String?
    let currentTier: String?
    let productID: String?
    let expiresAt: Date?
    let message: String?
}

@MainActor
final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    @Published var currentTier: SubscriptionTier = .starter
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var planTapCounts: [SubscriptionTier: Int] = [
        .starter: 0, .carePro: 0, .careTeam: 0,
    ]

    private var updateListenerTask: Task<Void, Error>?
    private let requestFactory: BackendRequestFactory
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init(
        requestFactory: BackendRequestFactory = BackendRequestFactory(),
        session: URLSession = .shared
    ) {
        self.requestFactory = requestFactory
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder = JSONEncoder()
        updateListenerTask = listenForTransactions()
    }

    deinit {
        updateListenerTask?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        let ids = SubscriptionTier.allCases.compactMap(\.productId)
        do {
            products = try await Product.products(for: Set(ids))
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func purchase(_ tier: SubscriptionTier) async -> Bool {
        guard let productId = tier.productId,
              let product = products.first(where: { $0.id == productId }) else {
            return false
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                purchasedProductIDs.insert(transaction.productID)
                currentTier = tier
                await syncReceiptValidation(preferredProductID: transaction.productID, fallbackTier: tier)
                await transaction.finish()
                return true
            case .userCancelled:
                return false
            case .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }

    func restorePurchases() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                purchasedProductIDs.insert(transaction.productID)
                if transaction.productID.contains("care_team") {
                    currentTier = .careTeam
                } else if transaction.productID.contains("care_pro") {
                    currentTier = .carePro
                }
            }
        }

        await syncReceiptValidation(preferredProductID: purchasedProductIDs.first, fallbackTier: currentTier)
    }

    func trackPlanTap(_ tier: SubscriptionTier) {
        planTapCounts[tier, default: 0] += 1
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw SubscriptionError.verificationFailed
        case .verified(let value): return value
        }
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await MainActor.run {
                        self.purchasedProductIDs.insert(transaction.productID)
                        if let tier = SubscriptionTier.from(productId: transaction.productID) {
                            self.currentTier = tier
                        }
                    }
                    await self.syncReceiptValidation(
                        preferredProductID: transaction.productID,
                        fallbackTier: SubscriptionTier.from(productId: transaction.productID) ?? .starter
                    )
                    await transaction.finish()
                }
            }
        }
    }

    private func syncReceiptValidation(preferredProductID: String?, fallbackTier: SubscriptionTier) async {
        guard let receiptData = await loadReceiptData() else { return }

        do {
            let authorized = SupabaseAuthStore.shared.accessToken != nil
            var request = try requestFactory.makeRequest(
                path: "billing/validate-receipt",
                method: "POST",
                requiresAPIKey: false,
                authorized: authorized
            )
            let payload = ReceiptValidationRequest(receiptData: receiptData, preferredProductID: preferredProductID)
            try request.encodeJSONBody(payload, encoder: encoder)

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return }
            guard (200...299).contains(httpResponse.statusCode) else { return }

            let validation = try decoder.decode(ReceiptValidationResponse.self, from: data)
            guard validation.valid, validation.isActive else { return }

            if let currentTier = validation.currentTier.flatMap(SubscriptionTier.from(serverValue:)) {
                self.currentTier = currentTier
            } else if let productID = validation.productID,
                      let validatedTier = SubscriptionTier.from(productId: productID) {
                self.currentTier = validatedTier
            } else {
                self.currentTier = fallbackTier
            }
            errorMessage = nil
        } catch {
            // Keep the device-side verified entitlement and let backend validation catch up later.
        }
    }

    private func loadReceiptData() async -> String? {
        if let existing = readReceiptData() {
            return existing.base64EncodedString()
        }

        do {
            try await AppStore.sync()
        } catch {
            return nil
        }

        return readReceiptData()?.base64EncodedString()
    }

    private func readReceiptData() -> Data? {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else { return nil }
        return try? Data(contentsOf: receiptURL)
    }
}

enum SubscriptionError: LocalizedError {
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .verificationFailed: return "Transaction verification failed"
        }
    }
}
