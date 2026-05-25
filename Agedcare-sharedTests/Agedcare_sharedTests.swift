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
        #expect(staff.subscriptionTier == .starter)
        #expect(staff.accessSource == .backend)
    }

    @Test func staffModelWithNilOptionals() {
        let staff = StaffUserModel(id: UUID(), facilityId: UUID(), role: "admin", displayName: nil, email: nil)
        #expect(staff.displayName == nil)
        #expect(staff.email == nil)
        #expect(staff.betaTrack == nil)
        #expect(staff.accessNotes == nil)
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

    @Test func paidTiersHaveProductIds() {
        #expect(SubscriptionTier.carePro.productId == "wcs.Agedcare_shared.care_pro_monthly")
        #expect(SubscriptionTier.careTeam.productId == "wcs.Agedcare_shared.care_team_annual")
        #expect(SubscriptionTier.starter.productId == nil)
    }

    @Test func productIdMapsToTier() {
        #expect(SubscriptionTier.from(productId: "wcs.Agedcare_shared.care_pro_monthly") == .carePro)
        #expect(SubscriptionTier.from(productId: "wcs.Agedcare_shared.care_team_annual") == .careTeam)
        #expect(SubscriptionTier.from(productId: "unknown.plan") == nil)
    }

    @Test func serverValueMapsToTier() {
        #expect(SubscriptionTier.from(serverValue: "care_pro") == .carePro)
        #expect(SubscriptionTier.from(serverValue: "CARE_TEAM") == .careTeam)
        #expect(SubscriptionTier.from(serverValue: "starter") == .starter)
        #expect(SubscriptionTier.from(serverValue: "enterprise") == nil)
    }

    @Test func rawValueRoundTrip() {
        for tier in SubscriptionTier.allCases {
            #expect(SubscriptionTier(rawValue: tier.rawValue) == tier)
        }
    }

    @Test func careProFeaturesIncludeWeeklySummaries() {
        let features = SubscriptionTier.carePro.features.joined(separator: " ").lowercased()
        #expect(features.contains("weekly") || features.contains("summary") || features.contains("summaries"))
    }

    @Test func careTeamFeaturesIncludeMultiUser() {
        let features = SubscriptionTier.careTeam.features.joined(separator: " ").lowercased()
        #expect(features.contains("multi-user") || features.contains("staff"))
    }

    @Test func testingAccessProfilesCoverAllSubscriptionTiers() {
        let tiers = Set(AppHost.testingAccessProfiles.map(\.subscriptionTier))
        #expect(tiers.contains(.starter))
        #expect(tiers.contains(.carePro))
        #expect(tiers.contains(.careTeam))
    }

    @Test func testingAccessProfilesIncludeAccessNotesForInvitations() {
        #expect(AppHost.testingAccessProfiles.allSatisfy { !$0.accessNotes.isEmpty })
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

@Suite("WatchConnectivity Payload Tests")
struct WatchConnectivityPayloadTests {
    @Test func residentWatchPayloadStoresCriticalMonitoringState() {
        let payload = WatchConnectivityService.WatchResidentSyncPayload(
            facilityId: UUID().uuidString,
            residentId: UUID().uuidString,
            statusText: "Fall Detected",
            isMonitoringActive: true,
            isRecordingIncident: true,
            fallRisk: "high",
            heartRate: "118 bpm",
            bloodOxygen: "96%",
            locationName: "Resident Wing A",
            movementSummary: "Moving at 1.2 km/h",
            recordedAt: ISO8601DateFormatter().string(from: Date())
        )

        #expect(payload.isMonitoringActive)
        #expect(payload.isRecordingIncident)
        #expect(payload.statusText == "Fall Detected")
        #expect(payload.heartRate == "118 bpm")
    }

    @Test func watchAlertSummaryEncodesCoreAlertFields() throws {
        let summary = WatchConnectivityService.WatchAlertSummary(
            id: 42,
            residentId: UUID().uuidString,
            type: "fall",
            status: "open",
            priority: 3,
            createdAt: "2026-05-12T10:00:00Z"
        )

        let data = try JSONEncoder().encode(summary)
        let decoded = try JSONDecoder().decode(WatchConnectivityService.WatchAlertSummary.self, from: data)

        #expect(decoded.id == 42)
        #expect(decoded.type == "fall")
        #expect(decoded.priority == 3)
    }
}

// MARK: - AppHost Tests

@Suite("AppHost Tests")
struct AppHostTests {
    @Test func baseURLIsValid() {
        let url = AppHost.baseURL
        #expect(url.scheme == "http" || url.scheme == "https")
    }

    @Test func testingAccessProfilesCoverCreatorAdminAndTesters() {
        let profiles = AppHost.testingAccessProfiles
        #expect(profiles.contains { $0.accessKind == .creator })
        #expect(profiles.contains { $0.accessKind == .administrator })
        #expect(profiles.filter { $0.accessKind == .tester }.count >= 3)
        #expect(profiles.map(\.subscriptionTier).contains(.starter))
        #expect(profiles.map(\.subscriptionTier).contains(.carePro))
        #expect(profiles.map(\.subscriptionTier).contains(.careTeam))
    }

    @Test func residentDemoFacilityAvailable() {
        #expect(AppHost.defaultResidentDemoFacilityID != nil)
    }

    @Test func previewAccessRemainsVisibleInTestContext() {
        #expect(AppHost.previewAccessEnabled)
        #expect(AppHost.visibleTestingAccessProfiles.count == AppHost.testingAccessProfiles.count)
        #expect(AppHost.visibleDemoAccessProfiles.count == AppHost.demoAccessProfiles.count)
    }
}

@Suite("Resident Demo Store Tests")
struct ResidentDemoStoreTests {
    @Test func testingFacilitiesHaveResidents() {
        let store = DemoResidentStore.shared
        for profile in AppHost.testingAccessProfiles {
            let residents = store.residents(facilityId: profile.facilityId)
            #expect(residents?.isEmpty == false)
        }
    }

    @Test func demoResidentsProvideTimelineAndCounts() {
        let store = DemoResidentStore.shared
        let facilityID = AppHost.defaultResidentDemoFacilityID!
        let resident = try! #require(store.residents(facilityId: facilityID)?.first)
        #expect(store.timeline(residentId: resident.id, limit: 10)?.isEmpty == false)
        #expect(store.fallCount(residentId: resident.id, days: 30) != nil)
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

    @Test(.enabled(if: liveCloudKitProbeEnabled))
    func defaultContainerResolves() {
        let container = CKContainer.default()
        #expect(!container.containerIdentifier.isEmptyOrNil,
                "CKContainer.default() must resolve a container identifier from the app entitlements")
    }

    @Test(.enabled(if: liveCloudKitProbeEnabled))
    func privateAndPublicDatabasesAccessible() {
        let container = CKContainer.default()
        let priv = container.privateCloudDatabase
        let pub  = container.publicCloudDatabase
        #expect(priv.databaseScope == .private)
        #expect(pub.databaseScope  == .public)
    }

    @Test(.enabled(if: liveCloudKitProbeEnabled))
    func accountStatusIsQueryable() async throws {
        let container = CKContainer.default()
        let status = try await container.accountStatus()
        let valid: [CKAccountStatus] = [.available, .noAccount, .restricted, .couldNotDetermine, .temporarilyUnavailable]
        #expect(valid.contains(status),
                "accountStatus() must return a known CKAccountStatus value (got rawValue \(status.rawValue))")
    }

    @Test(.enabled(if: liveCloudKitProbeEnabled))
    func cloudKitServiceSingletonExposesDatabases() {
        let svc = CloudKitService.shared
        #expect(svc.privateDB.databaseScope == .private)
        #expect(svc.publicDB.databaseScope  == .public)
    }
}

private let liveCloudKitProbeEnabled = ProcessInfo.processInfo.environment["RUN_LIVE_CLOUDKIT_TESTS"] == "1"

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
        // estimated = (30 + 22 + 22) / 3 = 24.7
        #expect(snap.formattedRoomTemp() == "24.7 °C")
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

    @Test func incidentLocationSnapshotPreservesMovementMetadata() {
        var snap = WeatherSnapshot()
        snap.locationName = "Resident Wing A"
        snap.coordinate = .init(latitude: -37.8136, longitude: 144.9631)
        snap.currentSpeedMetersPerSecond = 1.2
        snap.totalDistanceMeters = 18
        snap.actualRoomTemperature = 23.4
        snap.roomTemperatureSource = "Home sensor"

        let incident = IncidentLocationSnapshot(weatherSnapshot: snap)

        #expect(incident.locationName == "Resident Wing A")
        #expect(incident.latitude == -37.8136)
        #expect(incident.longitude == 144.9631)
        #expect(incident.roomTemperatureCelsius == 23.4)
        #expect(incident.roomTemperatureSource == "Home sensor")
        #expect(incident.movementSummary.contains("Moving"))
    }

    @Test func incidentLocationSnapshotMovementSummaryHandlesNoMovementEdge() {
        let incident = IncidentLocationSnapshot(weatherSnapshot: WeatherSnapshot())

        #expect(incident.movementSummary == "Movement not yet established")
        #expect(incident.coordinateDescription == "Location unavailable")
    }

    @Test func weatherSnapshotBackendMetricsIncludeLocationWeatherAndMovement() {
        var snap = WeatherSnapshot()
        snap.outdoorTemperature = 18.5
        snap.actualRoomTemperature = 22.3
        snap.humidity = 0.64
        snap.currentSpeedMetersPerSecond = 1.4
        snap.headingDegrees = 180
        snap.totalDistanceMeters = 42
        snap.coordinate = .init(latitude: -37.8136, longitude: 144.9631)

        let metrics = Dictionary(uniqueKeysWithValues: snap.backendMetrics().map { ($0.metric, $0.value) })

        #expect(metrics["outdoor_temperature"] == 18.5)
        #expect(metrics["room_temperature"] == 22.3)
        #expect(metrics["humidity_percent"] == 64)
        #expect(metrics["movement_speed_mps"] == 1.4)
        #expect(metrics["heading_degrees"] == 180)
        #expect(metrics["distance_meters"] == 42)
        #expect(metrics["latitude"] == -37.8136)
        #expect(metrics["longitude"] == 144.9631)
    }

    @Test func incidentRecordingDefaultsToLocalStatusWhenLegacyDataHasNoSyncState() {
        let recording = IncidentRecording(
            id: UUID(),
            type: "fall",
            timestamp: Date(),
            fileURL: URL(fileURLWithPath: "/tmp/fall.mov"),
            residentId: nil,
            duration: 30,
            hasPreIncidentFootage: true,
            facilityId: nil,
            snapshotURL: nil,
            locationSnapshot: nil,
            syncStatus: nil,
            syncError: nil,
            backendAnalysisID: nil,
            backendSummary: nil,
            backendMediaURL: nil,
            lastSyncedAt: nil
        )

        #expect(recording.resolvedSyncStatus == IncidentSyncStatus.localOnly)
    }

    @Test func weatherSnapshotLiveStatusShowsFreshnessAndEstimatedRoomTemp() {
        var snapshot = WeatherSnapshot()
        let now = Date()
        snapshot.locationLastUpdated = now.addingTimeInterval(-10)
        snapshot.weatherLastUpdated = now.addingTimeInterval(-75)

        let summary = snapshot.liveStatusSummary(now: now)

        #expect(summary.contains("Location live"))
        #expect(summary.contains("Weather live"))
        #expect(summary.contains("Room temp estimated"))
    }

    @Test func weatherSnapshotLiveStatusUsesRoomSensorTimestampWhenAvailable() {
        var snapshot = WeatherSnapshot()
        let now = Date()
        snapshot.actualRoomTemperature = 22.4
        snapshot.roomTemperatureSource = "Resident room sensor"
        snapshot.roomTemperatureLastUpdated = now.addingTimeInterval(-20)

        let summary = snapshot.liveStatusSummary(now: now)

        #expect(summary.contains("Room sensor live"))
        #expect(!summary.contains("estimated"))
    }

    @Test func weatherSnapshotRoomTemperatureSystemDescriptionShowsLiveHomeKitState() {
        var snapshot = WeatherSnapshot()
        snapshot.actualRoomTemperature = 22.4
        snapshot.roomTemperatureSource = "Resident room sensor"

        #expect(snapshot.roomTemperatureSystemDescription() == "Resident room sensor • live HomeKit data")
    }

    @Test func weatherSnapshotRoomTemperatureSystemDescriptionFallsBackToSensorStatusMessage() {
        var snapshot = WeatherSnapshot()
        snapshot.roomTemperatureStatusMessage = "Add a HomeKit temperature sensor or thermostat in the Home app to stream live room temperature."

        #expect(snapshot.roomTemperatureSystemDescription() == snapshot.roomTemperatureStatusMessage)
    }

    @Test func weatherSnapshotPrefersExplicitWeatherSourceDescription() {
        var snapshot = WeatherSnapshot()
        snapshot.weatherSourceName = "WeatherKit live"

        #expect(snapshot.weatherSourceDescription() == "WeatherKit live")
    }

    @Test func weatherSnapshotPrefersExplicitLocationSourceDescription() {
        var snapshot = WeatherSnapshot()
        snapshot.locationSourceName = "OpenStreetMap reverse geocode backup"

        #expect(snapshot.locationSourceDescription() == "OpenStreetMap reverse geocode backup")
    }

    @Test func weatherSnapshotFallsBackToDefaultLocationSourceDescription() {
        let snapshot = WeatherSnapshot()

        #expect(snapshot.locationSourceDescription() == "MapKit reverse geocode")
    }

    @Test func openMeteoConditionMapsThunderstormCodes() {
        let condition = LocationWeatherService.openMeteoCondition(for: 95)

        #expect(condition.description == "Thunderstorm")
        #expect(condition.symbolName == "cloud.bolt.rain.fill")
    }

    @Test func openMeteoConditionMapsClearSkyCodes() {
        let condition = LocationWeatherService.openMeteoCondition(for: 0)

        #expect(condition.description == "Clear")
        #expect(condition.symbolName == "sun.max.fill")
    }

    @Test func openMeteoConditionMapsUnknownCodesToLocalConditions() {
        let condition = LocationWeatherService.openMeteoCondition(for: 999)

        #expect(condition.description == "Local conditions")
        #expect(condition.symbolName == "cloud.sun.fill")
    }

    @Test func incidentRecordingStorageRouteSummaryIncludesAllAvailableRoutes() {
        let recording = IncidentRecording(
            id: UUID(),
            type: "fall",
            timestamp: Date(),
            fileURL: URL(fileURLWithPath: "/tmp/incident.mov"),
            residentId: UUID(),
            duration: 30,
            hasPreIncidentFootage: true,
            facilityId: UUID(),
            snapshotURL: nil,
            locationSnapshot: nil,
            syncStatus: .pendingUpload,
            cloudKitRecordName: "cloudkit-123",
            supabaseIncidentID: UUID(),
            lastSyncedAt: Date()
        )

        var enriched = recording
        enriched.backendMediaURL = URL(string: "https://example.com/video.mov")

        #expect(enriched.storageRouteSummary == "Care database synced • iCloud backup ready • Secure video link ready")
    }

    @Test func incidentVideoEnhancementPromptIncludesIncidentContext() {
        var weather = WeatherSnapshot()
        weather.locationName = "Resident Wing A"
        weather.coordinate = .init(latitude: -37.8136, longitude: 144.9631)
        weather.totalDistanceMeters = 12
        weather.actualRoomTemperature = 22.8
        weather.roomTemperatureSource = "Home sensor"
        let location = IncidentLocationSnapshot(weatherSnapshot: weather)

        let prompt = AIMonitoringService.incidentVideoEnhancementPrompt(
            incidentType: "fall_detected",
            locationSnapshot: location,
            includesSnapshot: true
        )

        #expect(prompt.contains("fall detected"))
        #expect(prompt.contains("Resident Wing A"))
        #expect(prompt.contains("Snapshot frame attached: yes"))
        #expect(prompt.contains("Room temperature: 22.8 C"))
    }

    @Test func mergedAnalysisAddsExternalInsightsWithoutDuplicates() {
        let primary = MediaAnalysisResult(
            id: "analysis-1",
            facility_id: "facility-1",
            resident_id: "resident-1",
            resident_name: nil,
            media_url: "https://example.com/video.mov",
            media_type: "video",
            analysis_status: "completed",
            summary: "Primary summary",
            confidence: 0.55,
            insights: ["Fall risk observed"],
            detected_keywords: ["fall"],
            sentiment: nil,
            safety_flags: [MediaAnalysisResult.SafetyFlag(type: "hazard", detail: "Loose rug")],
            transcribed_text: nil,
            created_at: "2026-05-13T00:00:00Z",
            completed_at: "2026-05-13T00:01:00Z"
        )

        let merged = AIMonitoringService.mergeAnalysis(
            primary: primary,
            summary: "Enhanced summary",
            confidence: 0.82,
            insights: ["Loose rug near resident", "Fall risk observed"],
            detectedKeywords: ["rug", "fall"],
            safetyFlags: [MediaAnalysisResult.SafetyFlag(type: "hazard", detail: "Loose rug")],
            providerName: "OpenAI-compatible open-source model"
        )

        #expect(merged.summary == "Enhanced summary")
        #expect(merged.confidence == 0.82)
        #expect(merged.insights.contains("Enhanced via OpenAI-compatible open-source model"))
        #expect(merged.insights.filter { $0 == "Fall risk observed" }.count == 1)
        #expect(merged.detected_keywords.filter { $0 == "fall" }.count == 1)
        #expect(merged.safety_flags.count == 1)
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


// MARK: - BetaAnalytics Tests

@Suite("BetaAnalytics Tests")
struct BetaAnalyticsTests {
    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "wcs.tests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suiteName)!
        d.removePersistentDomain(forName: suiteName)
        return d
    }

    @MainActor @Test func singletonExists() {
        #expect(BetaAnalytics.shared === BetaAnalytics.shared)
    }

    @MainActor @Test func logEventAppendsToEvents() {
        let a = BetaAnalytics(defaults: isolatedDefaults())
        a.logEvent("ping", payload: ["k": "v"])
        #expect(a.events.count == 1)
        #expect(a.events.last?.type == "ping")
        #expect(a.events.last?.payload["k"] == "v")
    }

    @MainActor @Test func logPlanInterestIncrementsCounter() {
        let a = BetaAnalytics(defaults: isolatedDefaults())
        a.logPlanInterest("care_pro")
        a.logPlanInterest("care_pro")
        a.logPlanInterest("care_team")
        #expect(a.planInterestCounts["care_pro"] == 2)
        #expect(a.planInterestCounts["care_team"] == 1)
    }

    @MainActor @Test func logFeedbackIncrementsCount() {
        let a = BetaAnalytics(defaults: isolatedDefaults())
        a.logFeedback(feeling: "Great", confusion: "", wish: "more profiles", features: ["routines"])
        #expect(a.feedbackCount == 1)
        #expect(a.events.last?.type == "beta_feedback")
        #expect(a.events.last?.payload["feeling"] == "Great")
        #expect(a.events.last?.payload["confusion"] == "none")
    }

    @MainActor @Test func activationRetentionOnboardingFeatureEventsFire() {
        let a = BetaAnalytics(defaults: isolatedDefaults())
        a.logActivation("first_resident_added")
        a.logRetention()
        a.logOnboardingStep("welcome", completed: true)
        a.logFeatureUse("mood_log", duration: 12)
        let types = a.events.map(\.type)
        #expect(types.contains("activation"))
        #expect(types.contains("session_start"))
        #expect(types.contains("onboarding"))
        #expect(types.contains("feature_use"))
    }

    @MainActor @Test func persistenceRoundTrip() {
        let d = isolatedDefaults()
        let a1 = BetaAnalytics(defaults: d)
        a1.logEvent("first")
        a1.logPlanInterest("care_pro")
        a1.logFeedback(feeling: "Okay", confusion: "x", wish: "", features: [])

        let a2 = BetaAnalytics(defaults: d)
        #expect(a2.events.contains(where: { $0.type == "first" }))
        #expect(a2.planInterestCounts["care_pro"] == 1)
        #expect(a2.feedbackCount == 1)
    }

    @MainActor @Test func maxEventsCapApplies() {
        let a = BetaAnalytics(defaults: isolatedDefaults())
        for i in 0..<(BetaAnalytics.maxEvents + 25) {
            a.logEvent("e\(i)")
        }
        #expect(a.events.count == BetaAnalytics.maxEvents)
        #expect(a.events.first?.type != "e0")
    }

    @MainActor @Test func resetForTestingClearsState() {
        let a = BetaAnalytics(defaults: isolatedDefaults())
        a.logEvent("noise")
        a.logPlanInterest("care_team")
        a.logFeedback(feeling: "Confused", confusion: "ui", wish: "", features: [])
        a.resetForTesting()
        #expect(a.events.isEmpty)
        #expect(a.feedbackCount == 0)
        #expect(a.planInterestCounts.isEmpty)
    }

    @Test func remoteSinkDefaultsOffAndEndpointPointsAtVercel() {
        #expect(WCSMarketingConfig.analyticsRemoteEnabled == false)
        #expect(WCSMarketingConfig.analyticsEndpoint?.absoluteString == "https://wcs-full.vercel.app/api/analytics")
    }
}
