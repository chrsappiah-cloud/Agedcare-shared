import Testing
import SwiftUI
@testable import Agedcare_shared
import CloudKit


// MARK: - Model Tests

@Suite("StaffUserModel Tests")
struct StaffUserModelTests {
    @Test func staffModelInitializes() {
        let id = UUID()
        let fid = UUID()
        let staff = StaffUserModel(id: id, facilityId: fid, role: "nurse", displayName: "Jane", email: "jane@test.com")
        #expect(staff.id == id)
        #expect(staff.facilityId == fid)
        #expect(staff.role == "nurse")
        #expect(staff.displayName == "Jane")
        #expect(staff.email == "jane@test.com")
    }

    @Test func staffModelWithNilOptionals() {
        let staff = StaffUserModel(id: UUID(), facilityId: UUID(), role: "admin", displayName: nil, email: nil)
        #expect(staff.displayName == nil)
        #expect(staff.email == nil)
    }
}

@Suite("ResidentModel Tests")
struct ResidentModelTests {
    @Test func residentModelInitializes() {
        let id = UUID()
        let fid = UUID()
        let resident = ResidentModel(id: id, facilityId: fid, name: "Bob", riskLevel: "high", dateOfBirth: Date())
        #expect(resident.id == id)
        #expect(resident.name == "Bob")
        #expect(resident.riskLevel == "high")
    }

    @Test func residentModelIdentifiable() {
        let r1 = ResidentModel(id: UUID(), facilityId: UUID(), name: "A", riskLevel: nil, dateOfBirth: nil)
        let r2 = ResidentModel(id: UUID(), facilityId: UUID(), name: "B", riskLevel: nil, dateOfBirth: nil)
        #expect(r1.id != r2.id)
    }

    @Test func residentWithNilOptionals() {
        let resident = ResidentModel(id: UUID(), facilityId: UUID(), name: "Test", riskLevel: nil, dateOfBirth: nil)
        #expect(resident.riskLevel == nil)
        #expect(resident.dateOfBirth == nil)
    }
}

@Suite("TimelineItem Tests")
struct TimelineItemTests {
    @Test func timelineItemCreation() {
        let item = TimelineItem(id: UUID(), kind: .fall, timestamp: Date(), summary: "Fall detected")
        #expect(item.summary == "Fall detected")
        #expect(item.kind == .fall)
    }

    @Test func timelineKinds() {
        let fall = TimelineItem(id: UUID(), kind: .fall, timestamp: Date(), summary: "A")
        let vital = TimelineItem(id: UUID(), kind: .vital, timestamp: Date(), summary: "B")
        #expect(fall.kind == .fall)
        #expect(vital.kind == .vital)
    }
}

@Suite("SessionState Tests")
struct SessionStateTests {
    @Test func onboardingState() {
        let state = SessionState.onboarding
        if case .onboarding = state {
            #expect(true)
        } else {
            #expect(false, "Expected onboarding state")
        }
    }

    @Test func loadingState() {
        let state = SessionState.loading
        if case .loading = state {
            #expect(true)
        } else {
            #expect(false, "Expected loading state")
        }
    }

    @Test func residentState() {
        let fid = UUID()
        let rid = UUID()
        let state = SessionState.resident(facilityId: fid, residentId: rid)
        if case .resident(let f, let r) = state {
            #expect(f == fid)
            #expect(r == rid)
        } else {
            #expect(false, "Expected resident state")
        }
    }

    @Test func staffState() {
        let staff = StaffUserModel(id: UUID(), facilityId: UUID(), role: "carer", displayName: "Test", email: nil)
        let state = SessionState.staff(staff)
        if case .staff(let s) = state {
            #expect(s.role == "carer")
        } else {
            #expect(false, "Expected staff state")
        }
    }
}

// MARK: - LoginResponse Tests

@Suite("LoginResponse Tests")
struct LoginResponseTests {
    @Test func loginResponseDecodes() throws {
        let json = """
        {"access_token":"abc123","user":{"id":"u1","email":"test@test.com","role":"nurse"}}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(LoginResponse.self, from: json)
        #expect(response.accessToken == "abc123")
        #expect(response.user.email == "test@test.com")
        #expect(response.user.role == "nurse")
        #expect(response.user.id == "u1")
    }
}

// MARK: - Subscription Tests

@Suite("SubscriptionTier Tests")
struct SubscriptionTierTests {
    @Test func allTiersExist() {
        #expect(SubscriptionTier.allCases.count == 3)
    }

    @Test func starterTierIsFree() {
        let tier = SubscriptionTier.starter
        #expect(tier.name == "Starter")
        #expect(tier.priceDisplay == "Free")
        #expect(tier.productId == nil)
    }

    @Test func careProTierHasPrice() {
        let tier = SubscriptionTier.carePro
        #expect(tier.name == "Care Pro")
        #expect(tier.priceDisplay == "$9.99/mo")
        #expect(tier.productId != nil)
    }

    @Test func careTeamTierHasCustomPricing() {
        let tier = SubscriptionTier.careTeam
        #expect(tier.name == "Care Team")
        #expect(tier.priceDisplay == "Custom pricing")
        #expect(tier.productId != nil)
    }

    @Test func eachTierHasFeatures() {
        for tier in SubscriptionTier.allCases {
            #expect(!tier.features.isEmpty)
            #expect(!tier.icon.isEmpty)
            #expect(!tier.subtitle.isEmpty)
        }
    }
}

// MARK: - Marketing Config Tests

@Suite("WCSMarketingConfig Tests")
struct WCSMarketingConfigTests {
    @Test func websiteURLValid() {
        #expect(WCSMarketingConfig.websiteURL.absoluteString == "https://wcs-full.vercel.app")
    }

    @Test func supportEmailSet() {
        #expect(WCSMarketingConfig.supportEmail == "christopher.appiahthompson@myworldclass.org")
    }

    @Test func allSocialLinksPresent() {
        #expect(WCSMarketingConfig.socialLinks.count == 12)
        let names = WCSMarketingConfig.socialLinks.map(\.name)
        #expect(names.contains("LinkedIn"))
        #expect(names.contains("TikTok"))
        #expect(names.contains("YouTube"))
        #expect(names.contains("Facebook"))
        #expect(names.contains("NightCafe"))
        #expect(names.contains("Gumroad"))
        #expect(names.contains("PayPal"))
    }

    @Test func all12AppProductsPresent() {
        #expect(WCSMarketingConfig.appProducts.count == 12)
    }

    @Test func eachAppHasValidURLs() {
        for app in WCSMarketingConfig.appProducts {
            #expect(app.websitePage.absoluteString.contains("wcs-full.vercel.app/apps/"))
            #expect(app.paymentLink.absoluteString.contains("wcs-full.vercel.app/pay/"))
            #expect(app.testFlightLink.absoluteString.contains("wcs-full.vercel.app/testflight/"))
            #expect(app.feedbackLink.absoluteString.contains("wcs-full.vercel.app/feedback/"))
        }
    }

    @Test func eachAppHasNonEmptyFields() {
        for app in WCSMarketingConfig.appProducts {
            #expect(!app.name.isEmpty)
            #expect(!app.bundleId.isEmpty)
            #expect(!app.appId.isEmpty)
            #expect(!app.category.isEmpty)
            #expect(!app.tagline.isEmpty)
            #expect(!app.icon.isEmpty)
            #expect(!app.tier.isEmpty)
            #expect(!app.price.isEmpty)
            #expect(!app.platform.isEmpty)
        }
    }

    @Test func agedCareAppPresent() {
        let agedCare = WCSMarketingConfig.appProducts.first { $0.bundleId == "wcs.Agedcare-shared" }
        #expect(agedCare != nil)
        #expect(agedCare?.appId == "6767978725")
        #expect(agedCare?.tier == "Care Pro")
    }

    @Test func paymentLinksIncludeAllAppsAndDonate() {
        let links = WCSMarketingConfig.paymentLinks
        #expect(links.count == 13) // 12 apps + donate
    }

    @Test func emailTemplateContainsAllApps() {
        let body = WCSMarketingConfig.betaInviteBody()
        for app in WCSMarketingConfig.appProducts {
            #expect(body.contains(app.name))
        }
    }

    @Test func shareTextContainsAppName() {
        let app = WCSMarketingConfig.appProducts[0]
        let text = WCSMarketingConfig.appShareText(for: app)
        #expect(text.contains(app.name))
        #expect(text.contains("#TestFlight"))
    }
}

// MARK: - HealthKit Error Tests

@Suite("HealthKitError Tests")
struct HealthKitErrorTests {
    @Test func errorDescriptions() {
        #expect(HealthKitError.notAvailable.errorDescription == "HealthKit not available on this device")
        #expect(HealthKitError.notAuthorized.errorDescription == "HealthKit access not authorized")
        #expect(HealthKitError.queryFailed("test").errorDescription == "Health query failed: test")
        #expect(HealthKitError.observerSetupFailed("err").errorDescription == "Observer setup failed: err")
    }
}

// MARK: - CaptureError Tests

@Suite("CaptureError Tests")
struct CaptureErrorTests {
    @Test func errorDescriptions() {
        #expect(CaptureError.cameraUnavailable.errorDescription?.contains("Camera") == true)
        #expect(CaptureError.microphoneUnavailable.errorDescription?.contains("Microphone") == true)
        #expect(CaptureError.permissionDenied("Camera").errorDescription?.contains("Camera") == true)
        #expect(CaptureError.sessionConfigFailed("msg").errorDescription?.contains("msg") == true)
        #expect(CaptureError.recordingFailed("err").errorDescription?.contains("err") == true)
    }
}

// MARK: - ShellMode Tests

@Suite("ShellMode Tests")
struct ShellModeTests {
    @Test func residentMode() {
        let mode = ShellMode.resident(facilityId: UUID(), residentId: UUID())
        if case .resident = mode {
            #expect(true)
        } else {
            #expect(false)
        }
    }

    @Test func staffMode() {
        let staff = StaffUserModel(id: UUID(), facilityId: UUID(), role: "nurse", displayName: nil, email: nil)
        let mode = ShellMode.staff(staff)
        if case .staff(let s) = mode {
            #expect(s.role == "nurse")
        } else {
            #expect(false)
        }
    }
}

// MARK: - AppHost Tests

@Suite("AppHost Tests")
struct AppHostTests {
    @Test func baseURLIsValid() {
        let url = AppHost.baseURL
        #expect(url.scheme == "http" || url.scheme == "https")
    }
}

// MARK: - WCSAppProduct Tests

@Suite("WCSAppProduct Tests")
struct WCSAppProductTests {
    @Test func productURLsAreCorrect() {
        let product = WCSAppProduct(
            id: "test-app",
            name: "Test",
            bundleId: "com.test",
            appId: "123",
            category: "Test",
            tagline: "A test app",
            icon: "star",
            tier: "Free",
            price: "$0",
            platform: "iOS",
            betaTrack: .general
        )
        #expect(product.websitePage.absoluteString == "https://wcs-full.vercel.app/apps/test-app")
        #expect(product.paymentLink.absoluteString == "https://wcs-full.vercel.app/pay/test-app")
        #expect(product.testFlightLink.absoluteString == "https://wcs-full.vercel.app/testflight/test-app")
        #expect(product.feedbackLink.absoluteString == "https://wcs-full.vercel.app/feedback/test-app")
    }
}

// MARK: - BetaTrack Tests

@Suite("BetaTrack Tests")
struct BetaTrackTests {
    @Test func allTracksExist() {
        #expect(BetaTrack.allCases.count == 6)
    }

    @Test func eachTrackHasAudience() {
        for track in BetaTrack.allCases {
            #expect(!track.targetAudience.isEmpty)
            #expect(!track.northStar.isEmpty)
        }
    }

    @Test func careTrackHasApps() {
        let careApps = WCSMarketingConfig.apps(for: .care)
        #expect(careApps.count >= 2)
    }
}

// MARK: - GrowthPhase Tests

@Suite("GrowthPhase Tests")
struct GrowthPhaseTests {
    @Test func allPhasesExist() {
        #expect(GrowthPhase.allCases.count == 4)
    }

    @Test func eachPhaseHasGoals() {
        for phase in GrowthPhase.allCases {
            #expect(!phase.goals.isEmpty)
            #expect(!phase.months.isEmpty)
            #expect(!phase.testerTarget.isEmpty)
        }
    }
}

// MARK: - Revenue Validation Tests

@Suite("Revenue Validation Tests")
struct RevenueValidationTests {
    @Test func fiveValidationQuestions() {
        #expect(WCSMarketingConfig.revenueValidationQuestions.count == 5)
    }

    @Test func successMetricsPresent() {
        #expect(WCSMarketingConfig.successMetrics.count == 5)
    }

    @Test func contentRhythmPresent() {
        #expect(WCSMarketingConfig.weeklyContentRhythm.count == 4)
    }

    @Test func personalLinkURLValid() {
        #expect(WCSMarketingConfig.personalLinkURL.absoluteString == "https://christopherappiahthompson.link")
    }

    @Test func socialHandlesAreReal() {
        let handles = WCSMarketingConfig.socialLinks.map(\.handle)
        #expect(handles.contains("@chrsappiah"))
    }
}


// MARK: - CloudKit / iCloud Live Probes (on-device)

@Suite("CloudKit Live Probes")
struct CloudKitLiveProbeTests {

    @Test func defaultContainerResolves() {
        let container = CKContainer.default()
        #expect(!container.containerIdentifier.isEmptyOrNil,
                "CKContainer.default() must resolve a container identifier from the app entitlements")
    }

    @Test func privateAndPublicDatabasesAccessible() {
        let container = CKContainer.default()
        let priv = container.privateCloudDatabase
        let pub  = container.publicCloudDatabase
        #expect(priv.databaseScope == .private)
        #expect(pub.databaseScope  == .public)
    }

    @Test func accountStatusIsQueryable() async throws {
        let container = CKContainer.default()
        let status = try await container.accountStatus()
        let valid: [CKAccountStatus] = [.available, .noAccount, .restricted, .couldNotDetermine, .temporarilyUnavailable]
        #expect(valid.contains(status),
                "accountStatus() must return a known CKAccountStatus value (got rawValue \(status.rawValue))")
    }

    @Test func cloudKitServiceSingletonExposesDatabases() {
        let svc = CloudKitService.shared
        #expect(svc.privateDB.databaseScope == .private)
        #expect(svc.publicDB.databaseScope  == .public)
    }
}

private extension Optional where Wrapped == String {
    var isEmptyOrNil: Bool { (self ?? "").isEmpty }
}

// MARK: - Backend / Middleware Health Probes (on-device)

@Suite("Backend Health Probes")
struct BackendHealthProbeTests {

    /// Construct a SupabaseClient using the configured AppHost and verify it
    /// is non-nil and uses the expected base URL. This exercises the middleware
    /// wiring without requiring the backend to actually be online.
    @Test func supabaseClientConstructsFromAppHost() {
        let config = SupabaseConfig(baseURL: AppHost.baseURL, apiKey: AppHost.supabaseAnonKey)
        let client = SupabaseClient(config: config, accessTokenProvider: { nil })
        #expect(config.baseURL.absoluteString.hasPrefix("http"))
        _ = client // construction itself is the test
    }

    /// DependencyContainer must wire all three repositories without throwing.
    @Test func dependencyContainerWiresRepositories() {
        let container = DependencyContainer()
        _ = container.alertsRepository
        _ = container.residentsRepository
        _ = container.facilityRepository
        _ = container.supabase
    }

    // MARK: - StakeholderModel + StakeholderStore tests

    @Test func stakeholderClassificationIsClinical() {
        var s = Stakeholder.blank()
        s.classification = .clinical
        #expect(s.isClinical == true)
    }

    @Test func stakeholderClassificationIsNonClinical() {
        var s = Stakeholder.blank()
        s.classification = .nonClinical
        #expect(s.isClinical == false)
    }

    @Test func stakeholderFullName() {
        var s = Stakeholder.blank()
        s.firstName = "Jane"; s.lastName = "Smith"
        #expect(s.fullName == "Jane Smith")
    }

    @MainActor @Test func stakeholderStoreAddAndRetrieve() {
        let store = StakeholderStore()
        var s = Stakeholder.blank()
        s.firstName = "Alice"; s.lastName = "Brown"; s.role = "Nurse"
        s.classification = .clinical
        store.add(s)
        #expect(store.stakeholders.contains { $0.id == s.id })
    }

    @MainActor @Test func stakeholderStoreUpdate() {
        let store = StakeholderStore()
        var s = Stakeholder.blank()
        s.firstName = "Bob"; s.role = "Cleaner"; s.classification = .nonClinical
        store.add(s)
        s.role = "Maintenance"
        store.update(s)
        #expect(store.stakeholder(for: s.id)?.role == "Maintenance")
    }

    @MainActor @Test func stakeholderStoreDelete() {
        let store = StakeholderStore()
        var s = Stakeholder.blank()
        s.firstName = "Carol"; s.classification = .clinical
        store.add(s)
        store.delete(id: s.id)
        #expect(store.stakeholder(for: s.id) == nil)
    }

    @MainActor @Test func stakeholderStoreClinicalFilter() {
        let store = StakeholderStore()
        var clinical = Stakeholder.blank(); clinical.firstName = "C"; clinical.classification = .clinical; clinical.isActive = true
        var nonClinical = Stakeholder.blank(); nonClinical.firstName = "N"; nonClinical.classification = .nonClinical; nonClinical.isActive = true
        store.add(clinical); store.add(nonClinical)
        #expect(store.clinical().allSatisfy { $0.isClinical })
        #expect(store.nonClinical().allSatisfy { !$0.isClinical })
    }

    // MARK: - WeatherSnapshot formatting helpers

    @Test func weatherSnapshotFormattedOutdoorTempCelsius() {
        var snap = WeatherSnapshot()
        snap.outdoorTemperature = 25.0
        #expect(snap.formattedOutdoorTemp() == "25.0 °C")
    }

    @Test func weatherSnapshotFormattedRoomTemp() {
        var snap = WeatherSnapshot()
        snap.outdoorTemperature = 30.0
        // estimated = (30 + 22) / 2 = 26.0
        #expect(snap.formattedRoomTemp() == "26.0 °C")
    }

    @Test func weatherSnapshotFormattedHumidity() {
        var snap = WeatherSnapshot()
        snap.humidity = 0.65
        #expect(snap.formattedHumidity() == "65%")
    }

    @Test func weatherSnapshotNoDataReturnsPlaceholder() {
        let snap = WeatherSnapshot()
        #expect(snap.formattedOutdoorTemp() == "--")
        #expect(snap.formattedRoomTemp() == "--")
        #expect(snap.formattedHumidity() == "--")
    }

    @Test func weatherSnapshotFahrenheitConversion() {
        var snap = WeatherSnapshot()
        snap.outdoorTemperature = 0.0   // 0 °C = 32 °F
        let result = snap.formattedOutdoorTemp(unit: .fahrenheit)
        #expect(result == "32.0 °F")
    }

    /// The Vercel marketing site (also linked from the app footer) must respond.
    /// Tolerates offline test environments by recording rather than failing.
    @Test func vercelMarketingSiteReachable() async throws {
        let url = WCSMarketingConfig.websiteURL
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = "HEAD"
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                Issue.record("Vercel response was not HTTP")
                return
            }
            #expect((200...399).contains(http.statusCode),
                    "Vercel marketing site must respond; got \(http.statusCode)")
        } catch {
            Issue.record("Vercel reachability probe network error: \(error.localizedDescription)")
        }
    }
}
